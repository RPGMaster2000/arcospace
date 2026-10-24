# Code health and technical debt assessment

Assessment date: 2026-10-22. Baseline: `d06975abfd2b4bb4446a1b20c6d071437d1b6861` on `main` (Godot 4.7.2).

## Recommendation

Schedule a focused refactoring cycle before adding another major combat or expedition mechanic. Keep the current engine, scene structure and working rule modules. The highest return is to establish one combat state owner, one action/turn pipeline shared by gameplay and simulations, and a data-only boundary between expeditions and battles.

The project has a useful modular foundation and substantial regression coverage. Its main weakness is that those modules are coordinated through controllers, mutable dictionaries and scene internals. Adding a feature often requires changes across rules, presentation, AI, descriptions and diagnostic simulations. Splitting files alone would leave that problem intact.

This is an assessment and implementation plan, not an architectural rewrite. No gameplay or tuning values were changed. Priorities below describe maintenance and correctness risk, not measured defect probabilities. No critical live gameplay defect was established by this audit.

## Scope and evidence

Reviewed runtime scripts, combat and expedition handoffs, card/ship resources and registries, scene bindings, asynchronous damage/turn flow, AI prediction, simulation runners, export presets, regression workflows and developer documentation. Inventory excludes vendor scripts when counting first-party runtime code:

| Inventory | Baseline count |
|---|---:|
| First-party scripts under `scripts/` | 76 |
| Lines in those scripts, including comments/blanks | 11,369 |
| Standalone `*_test.gd` runners | 64 |
| Card `.tres` definitions under `cards/` | 74 |
| `board.gd` | 993 lines |
| `expedition.gd` | 1,039 lines |
| `expedition_state.gd` | 1,135 lines |

The three controllers account for roughly 28% of first-party script lines. Size is an investigation aid; their ownership and dependencies are the reason to refactor. A literal `preload`/`load` graph found no script-to-script cycles under `scripts/`; that scan does not include scene/resource transitive loads, dynamic paths, parent-node calls or runtime object references. The important cycles here are runtime ownership dependencies.

## What is already healthy

- `match_rules.gd`, `repair_rules.gd`, `combat/systems_failure.gd` and `cards/card_effects.gd` isolate useful rule calculations. Preserve these tested seams.
- Card and ship definitions are Resources; most balance changes can remain data edits. Upgrades retain identity and copy effect dictionaries.
- AI evaluates copied states and has its own RNG. Countdown state is independent per ship. Expedition generation, stations and chasedowns use separate seeded streams.
- `BattleHUD` consumes a display snapshot and deliberately avoids retaining the gameplay controller. The grading feature uses a similar small, explicit interface.
- Reward and service operations already include replay/re-entry guards. Pending Hull damage clears its queue before callbacks to prevent duplicate application.
- CI pins the engine and checks download hashes, tests source/exported startup and performs rendered UI checks. There is an existing developer guide and detailed feature documentation.

These are reasons for incremental extraction rather than replacing the project wholesale.

## Prioritized findings

### H1 — Combat has multiple state representations and a large orchestration surface

**Priority: high. Architectural debt; no state-corruption defect demonstrated.**

Evidence: `scripts/board.gd:92–131` stores each ship's stats as separate exported properties. `_read_state`/`_write_state` at lines 277–296 copy between those properties and string-keyed dictionaries using dynamically constructed property names. `_ai_state` adds countdown state separately. Hands, the modifier, EMP drive and pending damage each own other parts of a match.

The same controller initializes profiles, enforces actions, advances turns, stages Hull damage, selects results, calculates rewards, routes navigation and builds display snapshots. A new attribute must survive every representation and handoff. `_write_state` accepts arbitrary dictionary keys without a defined state contract.

**Change:** introduce typed `ShipCombatState` and `CombatSession` objects with explicit snapshot/copy methods. Keep existing scene exports as initialization inputs and temporary compatibility accessors, not a second authoritative store. Centralize the resource/production key lists. Move command legality and state transitions behind a small interface.

**Acceptance:** unchanged seeded action traces, affordability, simultaneous Hull outcomes, countdown activation/recovery/timing, extra actions and EMP behavior; callers cannot mutate authoritative snapshots accidentally. Remove compatibility properties only after scenes and tests migrate.

### H2 — Balance simulations reproduce the live turn pipeline

**Priority: high. Confirmed diagnostic defect plus ongoing drift risk.**

Evidence: `tests/card_progression_simulation.gd:32–119` and `tests/six_ship_gameplay_simulation.gd:32–171` implement their own action, income, countdown and outcome sequencing rather than driving Board's pipeline. The newer runner includes modifier and EMP handling, while the older one deliberately omits those systems. Its hard-coded `SOURCE_REVISION` describes a historical experiment; rerunning it after rule changes still emits that old revision.

**Confirmed defect:** `enemy_roster_simulation.gd:3` overrides the parent's `run()` and never initializes inherited `failure_turns`. In a Godot probe it was `0`; activating the coordinator produced `1`, and the first affected turn reduced it to `0`. That diagnostic therefore uses a one-turn countdown instead of three. This finding does not invalidate the newer six-ship report: that runner explicitly initializes the duration at lines 14–16. It does reduce confidence in older roster diagnostics.

**Change:** first fix the old runner's setup and add a focused guard. Then move headless action/turn execution into the production session and have simulations call it. Preserve AI policy differences as explicit simulation configuration. Record actual revision, seed, policy, limits, rule configuration and outcome categories automatically; retain EMP escapes separately from destruction wins and unresolved games.

**Acceptance:** identical initial state/seed/actions produce identical state transitions and results through the game adapter and simulator, including modifiers, recovery, extra actions and simultaneous outcomes. Keep a short representative trace suite rather than using thousands of simulated matches as a substitute for parity.

### H3 — Expedition state reaches into live battle nodes

**Priority: high. Architectural/lifecycle debt.**

Evidence: `scripts/expedition_state.gd:1026–1059` accepts a Board node and writes its stats, drive and hand internals. `active_player_hand` at line 48 retains a Node; `_refresh_owned_hand` at line 923 mutates its pool and cards. `record_battle`/`sync_battle` at lines 1093–1135 read Board fields and constants. Meanwhile `expedition.gd:948–984` creates and removes the Board and owns navigation.

An ostensibly domain-only Resource therefore depends on live scene objects and their initialization order. Existing `is_instance_valid` and re-entry guards help, but cannot make this contract explicit.

**Change:** return a typed `BattleSetup` containing initial stats, decks, bonuses and profile data. Accept a typed `BattleResult` with result ID, persistent Hull, rewards and completion facts. Put live-hand synchronization in a small adapter. After that boundary is stable, extract deck ownership/upgrades and station transactions from the large expedition state; preserve its existing revision and completion guards.

**Acceptance:** expedition rule tests can run without instantiating Board. Repeated results cannot grant rewards twice. Restart, exit, repairs, chasedowns, boss completion, upgrades and removed cards retain existing behavior.

### H4 — Rules and presentation still share timing and side effects

**Priority: high during combat refactoring. Existing protections must be retained.**

Evidence: `board.gd:_begin_turn`, `_act`, `_resolve_card` and `_finish_turn` mix rule transitions with timers, VFX waits and UI calls. `_check_winner` defers while pending damage exists. `combat/pending_hull_damage.gd` applies already-calculated damage at a presentation cue. `refresh_display` at line 762 calls `_record_result`, normalizes repair selection and can choose the next modifier.

Consequently a display refresh is not a read-only operation, and skipping/closing an animation is part of state correctness. The pending-damage coordinator is a useful existing safeguard, not dead code to delete.

**Change:** make phases explicit: ready, resolving action, waiting for cue, finishing turn, finished. Produce an ordered action result/event list; have a presentation adapter acknowledge cues while a headless adapter advances them deterministically. Commit match rewards once on a result transition, then make display refresh consume data only. Document whether authoritative Hull changes at resolution or cue time before changing that behavior.

**Acceptance:** normal animation, disabled VFX, skip, pause, restart and exit each apply damage/rewards at most once; no input or AI action occurs during resolution; a result never appears before required impact cues. Preserve the current visible sequencing.

### M1 — Card effects have a distributed, string-based contract

**Priority: medium, before substantially expanding card vocabulary.**

Evidence: `cards/card_effects.gd:15` explicitly notes that new keys also require descriptions, modifier scaling/previews, AI scoring and tests. Effects and nested conditionals are untyped dictionaries; `CardData` exports a free-form effects dictionary. Key lists are duplicated in effects, match rules and expedition state. Registry array positions also appear as card identities in diagnostic setup.

**Change:** add a catalog validator for supported keys, value shapes, valid resources/production names, conditional branches, costs and upgrade definitions. Validate all registered Resources in CI and provide an editor-friendly error identifying the asset. Use stable identity keys instead of numeric array indices in tooling. Share effect metadata where semantics are truly common; keep AI strategy separate from execution rather than building a generic plugin framework.

**Acceptance:** malformed content fails with a precise asset/key message; every supported effect has execution/description coverage and an explicit AI treatment. Existing costs, upgrades, decks and effects remain unchanged.

### M2 — AI forecasts use base effects without battlefield context

**Priority: medium. Model limitation; no illegal live action demonstrated.**

Evidence: `enemy_ai.gd:20–47` receives cards and two ship states, then uses `Effects.play(..., simulate=true)` for immediate wins and self-damage safety. Actual Board actions use `modifier.play`. Ion scaling, shield suppression and nebula uncertainty therefore are not represented by that same forecast interface.

**Change:** supply a read-only combat context and a side-effect-free forecast service shared with the resolver. Keep conservative handling of random outcomes and tactical variation. Do not equate a conservative forecast with guaranteed live results under every modifier.

**Acceptance:** modifier-aware forecast tests, no live RNG consumption, no mutation of hands/state, unchanged affordability, recovery priority and varied tie breaking. Treat AI policy changes as separately reviewed balance changes.

### M3 — Scene contracts remain implicit

**Priority: medium.**

Evidence: `ui/battle_hud.gd:_init` binds numerous literal NodePaths and reads controller fields; `battle_effects.gd` and `turn_presentation.gd` use parent internals. Saved scene offsets coexist with runtime layout and model transforms. Recent shield and recoil work demonstrates why authored transforms must remain authoritative.

**Change:** bind a small typed view/target interface once, retain snapshot-driven rendering, and use exported references or unique scene names for stable structural bindings. Document which layout values belong to scenes versus runtime fitting. Keep targeted viewport and geometry tests; don't rewrite all runtime-built UI into scenes merely for consistency.

**Acceptance:** scene contract validation fails early with a useful missing-node message. Verify six player ships, enemy models, shield enclosure, responsive HUD and modal interactions at existing viewport sizes.

### M4 — Regression infrastructure needs a trustworthy, reproducible baseline

**Priority: high prerequisite, medium ongoing maintenance.**

Evidence: `.github/workflows/tests.yml` contains the runner logic inline, triggers on pushes to main and selected historical branches, and has no `pull_request` trigger. It combines headless and rendered work under a 15-minute job timeout. Rendered scripts have no individual timeout in that loop. The latest baseline's `tests` check ended **cancelled** after about 15 minutes; exported-startup passed. The cancellation timing alone does not establish which test or infrastructure condition caused it. Web build/deploy passed; no Android check was present in that commit's returned check list.

`enemy_models_visual_test.gd` waits for `frame_post_draw`; CI correctly excludes it from headless execution. `star_map_test.gd:61,76,83` uses fixed `.08` second waits for travel completion. Assertion totals include repeated geometry/sample loops and are not a coverage percentage.

**Change:** put runner selection/timeouts/results in one reusable tool, with explicit unit/integration/render/audio/simulation categories. Run it locally and in CI. Add PR checks; split rendered work from headless work, bound every test and upload partial logs. Replace elapsed-time guesses with arrival/completion signals or bounded condition waits. Fail on engine script errors even if process exit is zero. Add a small Mobile-renderer smoke test because rendered CI currently selects GL Compatibility.

**Acceptance:** all categories finish within budgets from a clean checkout; failures identify the script and preserve logs; headless tests never wait for rendering; multiple runs are stable. Require these checks before merging the larger extractions.

### L1 — Content, vendor and tooling hygiene

**Priority: low, separate from rules refactoring.**

- The developer guide is useful, but `ui/encounter_presentation.gd:53` still says enemies keep the base library despite profile-specific starting pools. Rename misleading `repair_spend` (Hull quantity) and explain legacy `ftl_drive.gd`/warp names now representing combat EMP versus expedition FTL. Use compatibility migration where scene properties require it.
- Imported compositor and lens packages exist alongside the actual Mobile-safe grading path. Inventory their users, licenses and supported renderers; document vendor ownership before removing anything. Their small size alone does not justify cleanup, and unused-by-current-scenes is not proof an editor tool is safe to delete.
- Web exports use `all_resources` with no exclusions; Android excludes build/docs but still uses `all_resources`. Audit resulting pack contents and define intentional development-tool/test exclusions only after packed-startup tests have a separate fixture pack. Do not remove tests required by the current exported-startup job accidentally.
- A clean import generated missing test `.uid` files and an image import sidecar. Track required metadata consistently; don't commit `.godot` caches. Add formatting/static checks for first-party files incrementally, keeping vendor code outside mass formatting.
- Only preferences currently use `ConfigFile`; expedition state is in memory. Durable saves are a future feature, not an existing save-system defect. Data-only state boundaries will make that feature safer later.

### M5 — Shutdown warnings obscure lifecycle regressions

**Priority: medium. Observed warnings; sustained gameplay memory growth not established.**

The assessment's headless run reported ObjectDB exit leaks in 53 of the 63 executed test scripts, despite passing assertions and no engine `ERROR:` messages. `music_test.gd` alone reported six instances; a verbose follow-up identified three MP3 stream/playback pairs. These may include audio-driver shutdown behavior, test teardown and reference cycles; counts alone cannot identify a production leak. Test processes currently exit between scripts, which can hide retained shared objects and lifecycle coupling.

**Change:** inspect verbose object reports, explicitly await queued frees in fixtures, and separate known engine/vendor warnings from first-party ownership failures. Add repeated battle-create/exit and modal-open/close lifecycle checks with a stable object-count baseline. Avoid changing cleanup logic based only on warning counts.

**Acceptance:** warnings have identified owners and reproducible dispositions; repeated in-process navigation returns to its established baseline. Don't suppress the warnings globally.

## Proposed refactoring sequence

Each row should be a reviewable change or small series, with behavior preservation checked before the next extraction. Effort is relative engineering scope, not a delivery promise.

| Order | Work package | Relative effort | Completion gate |
|---|---|---|---|
| 1 | Fix diagnostic countdown setup; reusable test runner; stabilize timing; establish green CI and PR checks | Small–medium | Clean reproducible headless/render/audio baseline, bounded jobs |
| 2 | Typed ship/session state with temporary Board adapters; content validation | Medium | State ownership explicit; malformed data rejected; existing behavior preserved |
| 3 | Extract shared command/turn resolver and explicit phases; migrate simulations | Large | Game/simulation trace parity; cue cancellation and victory tests pass |
| 4 | Move result commits out of refresh; introduce BattleSetup/BattleResult expedition adapter | Medium | Read-only refresh; idempotent results; no domain-to-live-Node dependency |
| 5 | Extract deck/station services; tighten UI bindings and forecast context | Medium | Expedition and AI contracts tested without full screen construction |
| 6 | Naming, stale docs, unused asset/tool review and export hygiene | Small | Smaller intentional runtime surface; clean imports/exports |

Work packages 1–4 should precede another major combat mechanic. Minor data/art changes can continue if they do not destabilize the baseline. Avoid simultaneous changes to balance, rendering architecture, scene hierarchies and state ownership. Preserve Systems Failure's two-system threshold/three own-turn recovery, card values, Power Allocation, EMP policies and expedition progression throughout.

## Validation performed for this assessment

Performed against a local tree matching the baseline tree `45ba3cdbe3c668f12fd115098a803b16f1528f14` before adding this report:

- Godot 4.7.2 headless editor import: exit 0; no script parse/compile errors. Import generated missing metadata noted above.
- All 61 `tests/*_test.gd` scripts except `enemy_models_visual_test.gd`, `music_test.gd` and `victory_music_test.gd`: exit 0, no detected assertion failures, script errors or engine `ERROR:` messages. Ran as isolated processes with four workers, Dummy audio and a 90-second per-script bound. Includes Systems Failure, AI, progression, all ship profiles, shield fit and grading regression scripts. Longest observed script was `poi_reward_overhaul_test.gd` at 70.8 seconds under that load; these are host timings, not performance benchmarks.
- The two music scripts then ran sequentially with Dummy audio: both passed; victory music reported 28 checks. Total: **63 of 64 regression scripts executed and passed**. Exit leak warnings were recorded separately above. Star-map timing passed this run; its fixed waits remain a test-design risk rather than a reproduced current failure.
- `enemy_models_visual_test.gd` was deliberately not run without a real rendering driver. No fresh rendered, exported-pack, browser or physical-device validation was performed for this documentation-only assessment.
- A temporary diagnostic probe instantiated the old roster runner and exercised its countdown: duration `0`, activation `1`, after first affected turn `0`. The probe was removed; production code and existing tests were not modified.
- Inspected baseline GitHub checks: [regression/startup workflow](https://github.com/RPGMaster2000/arcospace/actions/runs/39736222735) had cancelled `tests` and successful `exported-startup`; [Web workflow](https://github.com/RPGMaster2000/arcospace/actions/runs/39736222753) had successful build/deploy. These are remote historical results, not new local export tests.
- First-party dependency/size inventory and `git diff --check` completed. No broad refactor or balance changes were made.

Runtime tests are regression evidence, not proof that every card combination or platform is correct. Physical Android testing, GPU performance profiling, penetration testing, save persistence and exhaustive stochastic balance analysis are outside this assessment.


## Expedition deck ownership follow-up (2026-10-24)

The assessment above describes its historical baseline. The focused deck extraction now
addresses the card-ownership portion of H3/work package 5; it does not extract station
services or alter combat/session boundaries. [Ownership and verification](expedition_deck_ownership.md)
documents the one `ExpeditionDeck` owner, the retained State facade, unchanged version-1
save shape and seeded baseline fixtures. Existing mutable CardData definitions remain
shared read-only inputs; whole-ledger compatibility setters remain for fixtures. No
parallel inventory, State back-reference, Board dependency, autoload or transaction
framework was introduced. Remaining generation and service coordination stays in State.


## Expedition presentation lifecycle follow-up (2026-10-24)

[Step 2 ownership/verification](expedition_controller_lifecycle.md) records the focused
controller extraction. Existing Screen now owns internal view reset/selection/result styling
and suspense; existing map/camera/curtain own cinematic execution and cancellation. A local
phase/revision guards async callbacks without persisting presentation or duplicating State.
Battle callbacks bind their originating Board; typed setup/results and version-1 saves stay
unchanged. Controller shrinks 1332 → 1217 lines; all affected runtime files grow 2269 → 2515.
The added cancellation and compatibility code is a maintenance tradeoff, not a runtime
performance claim. Remaining map-entry composition/control aliases are documented. No new
runtime manager or broad UI hierarchy was introduced; Stage 1 Deck ownership is preserved.

## Card effect contract follow-up (2026-10-24)

Step 3 addresses M1 with a development-only validator, precise nested diagnostics and
all-library base/upgrade checks. See [inventory, coverage and parity](card_effect_contract.md).
ShipCombatState shares the identical attribute vocabulary; consumer execution and policy
remain separate. No runtime validation, new registry, dispatch engine or ownership copy
was introduced. M2 remains an explicit AI forecast limitation; this pass does not change
strategy or battlefield context. Historical counts and findings above describe their
recorded baseline, not this revision.

## Modifier-aware forecast follow-up (2026-10-24)

Step 4 addresses the numerical boundary in M2: a pure RefCounted forecast replays the
authoritative effects with explicit draw choices and shared modifier execution. It owns
no combat state and samples no RNG. [The report](refactoring/combat_forecast.md) records
Phase A parity and the independently gated Phase B integration: only immediate-win and
fatal-self-damage gates consume active modifier forecasts. Scoring, recovery and discard
heuristics deliberately remain approximate. Six selected-card and six RNG-only deltas
are enumerated against 480 captured cases; this is not a claim of globally unchanged AI.
No global manager, new effect vocabulary or second resolver was introduced.
