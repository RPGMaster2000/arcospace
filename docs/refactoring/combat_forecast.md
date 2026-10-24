# Combat forecast ownership and modifier-aware AI

Starting revision: `9ec97c6f3d8aca31422839830eb4e5577f358c29`, Godot 4.7.2.

## Audit and phase boundary

EnemyAI checks affordability, then conservative immediate wins and surviving self-damage.
SystemsFailureTactics handles recovery/resource preservation and discard refunds. Ordinary
fallback prioritizes attacks against low Hull, repairs at the configured build threshold,
then production, then affordable choices. Tactical scoring simulates copied states;
random sabotage averages three hypothetical targets, random gains are omitted but valued
by a top-level expectation heuristic. Weights, urgency thresholds, discard policy and
strict-greater tie order are policy. Variation and fallback picks use only AI's RNG.

All simulations use CardEffects, but lack Ion scaling, Solar Flare and Nebula context.
Board supplies detached ship state plus failure counters, not modifier information.
Board3D inherits this decision path. CardTargets is category guidance, not a forecast.

| Modifier | Live behavior | Old AI | Forecast context / treatment |
| --- | --- | --- | --- |
| None | Base effects | Conservative simulation | No adjustment |
| Ion | Active Energy ×0.5/×2, recursive floor and exceptions; cost unchanged | Base effects | Current active flag and announced factor; shared scaling |
| Solar Flare | Disabled active Shields, top-level restoration/swap stripped; stored values restored | Stored Shields treated as usable | Current active flag; shared zero/restore scope |
| Nebula | Combat classification + current miss rate; miss pays, retains top-level direct self-damage | Assumes hit | Enumerated hit/miss alternatives, no sampled roll |
| Asteroids | Separate scheduled strike | Not forecast | Explicit no-op for current card; no future strike included |
| Temporal Rift | Tier-2 draw multiplier | Current hand only | Explicit no-op for immediate card resolution |

Phase A adds infrastructure and shared rule seams only; EnemyAI and Board stay unchanged.
Phase B is separately gated on deterministic parity and audited decision comparisons.
The existing conservative three-argument AI call remains the compatibility baseline.

## Forecast contract

`CombatForecast.predict(card, actor, target, context={})` returns affordability,
`outcomes` (actor/target/damage/miss), `complete`, `uncertain`, witnessed `possible_win`
and `possible_self_destruction`, and complete-only `guaranteed_win` /
`guaranteed_self_destruction`. Winning requires actor survival and MatchRules.wins;
no countdown is advanced. The nominal current Nebula miss probability is reported.
This is not an expectation or a probability-weighted distribution of random effects.

Inputs are read-only. Every outcome owns detached dictionaries; no Resource, Node, hand,
RNG or source collection is returned. Context is four scalars from
`CombatModifier.forecast_context()` (kind, active, ion_factor, miss_rate). It must describe
a valid current modifier, not invented future schedules. No modifier Node is created by
forecasting. Terminal-action legality beyond affordability stays with CombatExecution.

Modifier's shared `resolve_effects` owns adjusted effects and the Solar Flare stored-Shield
scope. Its live caller still owns the scheduled state, existing chance draw and notice.
`_scaled` becomes static with its exact original implementation. CardEffects receives an
optional forecast draw source, default null, at the same existing draw sites. Production
calls retain their supplied RNG, draw count/order, branches and formulas. This narrow seam
lets the forecast replay explicit choices; it is not a new effect registry or resolver.

For integer resource/production/range draws, enumerate their actual discrete domains.
For Collapse's `< chance`, float endpoints cover both reachable comparison outcomes,
including native randf's inclusive 1. No probability is assigned to these alternatives.
Conditions execute normally after preceding draws, so nested branches see the right
state without the forecast interpreting their rules. Nebula gets separate hit and miss
requests; its shared miss transform preserves explicit top-level self-damage and payment.

At most 64 authoritative resolver replays run per card. An adaptive prefix branches on
the next unresolved nontrivial draw; fixed-range draws still advance that prefix. Large
or combined spaces can return a subset, flagged incomplete with a limitation. In that
case possible_* true is a witnessed outcome; false does NOT establish impossibility.
No guarantee flags are ever set for incomplete results. No Monte Carlo samples, expected
values, sampled seeds, live RNG calls or hidden fallback claims are used.

Asteroids and Temporal Rift do not change the immediate card forecast. Stored Shields
remain stored in Solar Flare outputs, while damage is calculated with zero usable
Shields. CardTargets/TacticalPreview are unchanged and remain category-only presentation.

## Phase A gate

Newly verified on this source: baseline 94 headless scripts + import passed. Phase A
focused runner passed import and eight suites: forecast (1,554 combinations / 10,900
checks), 480 unchanged AI decisions AND RNG states, contract (1,011), card-effect parity
(2,220), combat traces (72), AI scene, modifier and Systems Failure suites. The first
new comparison attempt exposed JSON's float representation of integer slots; the loader
now casts that field without changing any recorded decision or established fixture.
EnemyAI and Board are byte-identical to the starting revision at this gate.

## Phase B: narrowly integrated gates

Board passes a fresh four-scalar context at the actual enemy timeout. No context field
is cached on AI or serialized. Ion forecasts apply only to Energy cards while active;
Flare while active; Nebula only to combat-classified cards at nonzero miss rate. Ordinary,
inactive Ion/Flare, Asteroid and Temporal Rift calls retain the old simulation gates.
The default three-argument call remains intentionally compatible, including the existing
72 diagnostic combat traces and 2,220 card parity records. Those traces exercise the
legacy decision policy; they are NOT a claim that modified live AI is unchanged.

Only immediate winning moves and fatal self-damage filtering use numerical forecasts.
A win requires all enumerated outcomes to win with surviving actor. Safety rejects any
possible fatal outcome. An incomplete forecast cannot claim an immediate win; safety
falls back to the old conservative policy unless a fatal witness is already present.
All current authored cards/upgrades fit the complete forecast budget in the tested contexts.
Recovery/follow-up simulations, tactical scores, random-gain expectation, sabotage scoring,
discard rules, weights, thresholds and strict tie-breaking stay byte-identical.
These remain explicit approximations and are not advertised as modifier-aware scores.

### Reviewed decision comparison

`tests/ai_forecast_baseline.json` was captured before Phase B. Cases use six six-card
hands, five situations (ordinary, immediate win, low-Hull risk, Systems Failure recovery,
unaffordable), two AI seeds and eight contexts: 480 comparisons. One hand includes
Upgrade I/II definitions. Input fingerprints, original decisions and RNG states remain
fixed. Comparisons also rerun the legacy call with an explicit identical combat seed;
both paths leave combat RNG unchanged. Old simulation does not read that RNG at all.

Results: **6 selected-card changes**, **6 same-selection RNG deltas**, **468 cases with
identical selection and RNG**. All 240 ordinary/inactive/independent-event cases match.
No discard flags change. [Complete machine-checked ledger](ai_forecast_decisions.json)
records every changed case's cards, both ship states, context, weights, AI/combat seeds,
old/new decisions, RNG states, winning sets and safety sets. The regression asserts the
entire reviewed ledger; it does not merely accept arbitrary modified-battle differences.

| Case IDs (hand/situation/AI seed/context) | Old → new | Exact reason |
| --- | --- | --- |
| 0/1/7/3, 0/1/43/3 | Laser Burst → Overloaded Warhead | Half Ion Laser gives 4 damage, not its base 9; against 6 Hull it is not an immediate win. Unscaled Warhead safely kills. |
| 0/1/7/6 | Laser Burst → Plasma Strike | Nebula removes assumed guaranteed kills; existing fallback selects Plasma. |
| 1/1/7/6 | Overloaded Warhead → Laser Burst | Same Nebula correction; existing fallback pick. |
| 2/1/43/6 | Coordinated Assault → Reactor Salvage | Same Nebula correction; existing production-priority fallback. |
| 4/1/7/6 | Laser Burst++ → Shield Exchange+ | Same Nebula correction; existing fallback. |
| 0/1/43/6, 1/1/43/6, 2/1/7/6, 4/1/43/6 | Selected card unchanged; AI RNG advances | Early certain-win return becomes ordinary fallback/scoring, using its existing RNG draws. |
| 2/2/7/5, 2/2/43/5 | Coordinated Assault unchanged; fewer variation draws | Flare removes Desperate Conversion from safe candidates: stored Shields cannot absorb its self-damage. Existing tactical variation runs on five rather than six candidates. |

These differences are accepted forecast corrections, not changed weights or new strategy.
The AI can still select a risky-to-hit attack through ordinary policy; it simply no
longer treats it as a guaranteed immediate win. No fabricated probability-weighted
expected score or new planning depth is introduced.

## Ownership and preserved boundaries

| Responsibility | Before | After |
| --- | --- | --- |
| Ship values, turn/countdown, hand and battle results | ShipCombatState / Board / existing rule modules | Unchanged; forecast owns no persistent fields |
| Effect formulas/order and condition predicate | CardEffects | Same resolver; optional explicit forecast draws at existing sites |
| Modifier schedule, state, live chance draw/notices | CombatModifier Node | Unchanged |
| Modifier effect adjustment and stored-Shield scope | Inside CombatModifier.play | Shared static resolve_effects; live play and forecast both use it |
| Numerical possibilities under modifiers | No common boundary; conservative AI copies | CombatForecast, detached and deterministic |
| AI strategy and weights | EnemyAI / SystemsFailureTactics | Same owners; only two active-modifier gates consume forecast |
| Current modifier context supplied to AI | Absent | Four-scalar snapshot from Board at decision time |
| Tactical categories, inspection and visuals | CardTargets / TacticalPreview / existing UI | Byte-identical, independent |
| Deck/rewards, exploration lifecycle, save and typed battle handoff | Existing Step 1–3 owners | Byte-identical |

No new autoload, manager, Resource hierarchy, registry, UI, save field or effect key.
There is no CombatSession script at this revision; CombatExecution remains the command
boundary. No inverse dependency from effects/modifiers into AI or presentation is added.

## Files and code size

Created `scripts/combat/combat_forecast.gd`; tests `combat_forecast_test.gd`,
`ai_forecast_cases.gd`, `ai_forecast_compatibility_test.gd`,
`ai_modifier_forecast_test.gd`, `ai_forecast_scene_test.gd` (and all six UIDs);
`tests/ai_forecast_baseline.json`; this report and `ai_forecast_decisions.json`.
Modified runtime: `scripts/cards/card_effects.gd`, `scripts/combat_modifier.gd`,
`scripts/enemy_ai.gd`, `scripts/board.gd` (one context argument).
Modified documentation: developer guide, code-health assessment, card-effect contract
and combat-boundaries document. No files removed or existing test fixtures changed.

| Lines including comments/blanks | Before | After |
| --- | ---: | ---: |
| CardEffects | 205 | 210 |
| CombatModifier | 251 | 264 |
| EnemyAI | 204 | 226 |
| Board | 1,029 | 1,029 |
| New forecast | 0 | 74 |
| Combined touched runtime code | 1,689 | 1,803 |
| Five new test/support scripts | 0 | 315 |
| Combined affected code | 1,689 | 2,118 |

JSON, UIDs and prose are excluded. Runtime grows by 114 lines to establish the boundary;
there is no attempt to reduce size by hiding policy or copying a resolver.

## Performance and remaining limitations

Headless Linux desktop, 2,400 six-card decisions per path, under concurrent test load:
compatibility path mean **326 μs**, p95 **836 μs**; current-context path mean **551 μs**,
p95 **1,432 μs**. Mean overhead is about **225 μs** per six-card decision. Maximums were
6.1 / 18.3 ms under host contention, not a frame-time guarantee. The separate pure
forecast sample took about 91 ms for 100 six-card hands (~0.91 ms/hand). All authored
base/upgrades needed at most **17 resolver replays** in the measured five contexts;
the enforced per-card ceiling is 64. No Monte Carlo work or Node creation occurs.
These measurements do not establish physical Android performance or a cross-device
budget. Extra allocations are bounded short-lived dictionaries/Resource copies.

Approximate cases and remaining coupling:

- Huge/combined outcome spaces can be incomplete. No guarantee comes from a subset.
- Enumerated outcomes are possibilities, not probability weights or expected utility.
  Collapse endpoint cases preserve native comparison semantics, not a 50/50 weighting.
- Nominal Nebula rate is current context only; the forecast does not predict its next drift.
- Scoring/recovery/discard heuristics remain legacy approximations; future integration
  there needs a separate policy review. No multi-turn model, countdown expiry prediction,
  future draw, future asteroid or multi-action plan is inferred.
- Existing 72 combat traces intentionally use the compatible three-argument policy.
  Modified live decisions are covered by the explicit comparison ledger and Board tests.
- The effect resolver has a narrow optional draw-source seam. A future new random API
  must add an explicit deterministic operation and forecast tests; it must not silently
  fall back to live RNG. Development card validation remains separate and unchanged.
- Existing scene-based regressions emit ObjectDB shutdown warnings; the new scene
  fixture also reports them (4 headless / 2 rendered in focused runs). Pure forecast,
  comparison and compatibility tests exit without them. This pass does not claim to
  have fixed Board fixture shutdown ownership or attribute the warnings to forecasts.

## Verification on this revision

These are newly run checks, not historical results borrowed from earlier reports:

- Unchanged starting baseline: **94 headless scripts + editor import passed**.
- Phase A independent gate: eight focused suites + import passed before AI/Board edits.
- Final focused numerical forecast: **1,554 authored card/upgrade/modifier combinations,
  10,901 checks**, no failures. Covers exact deterministic results, sampled authoritative
  random outcomes within enumerated sets, all listed effect families, upgrades, nested
  and random-dependent conditions, fixed-range draw ordering, Collapse alternatives,
  Nebula hit/miss, budget limits, affordability and returned-snapshot independence.
- Compatibility: **480 captured decisions and RNG states match** on the legacy call.
- Phase B comparison: **480 cases / 2,897 checks**; 6 selection changes and 6 RNG-only
  deltas match the reviewed ledger. All 240 ordinary/inactive/no-op cases are identical.
- Real Board context/safety test: **63 checks** covering activation/expiry, current Ion
  factor, Nebula drift, fresh battles/restarts and targeted Ion/Flare/Nebula safety.
- Existing **2,220 card-effect checkpoints**, **72 combat traces**, **1,044 expedition
  checkpoints**, **43 deck ownership checks** and **1,011 contract checks** pass unchanged.
- Mobile/Vulkan llvmpipe: scene handoff/safety 63 checks; tactical preview 43 checks at
  1280×720 and 960×540. The first tactical invocation exited without a completion marker
  and was not counted as a pass; the unchanged isolated recheck completed successfully.
- Ten Python runner tests pass. Existing source-snapshot checks verify 93 protected
  files byte-identical; AI score/pick functions, modifier schedule/classification and
  condition predicate statements remain exact. Tracked eager preload/resource graph:
  368 → 374 files, zero cycles. Documentation links and whitespace checks pass.
- Scene fixture warning counts remain reported separately; no warnings/errors are
  concealed by a zero exit status. Pure forecast/comparison tests have no shutdown leaks.
- No physical Android/Windows device, APK/export, device input or device performance
  validation was performed. No platform-specific dependency or renderer setting changed.

Final shared runner: **98 headless regression scripts + editor import passed**, zero
failed suites. This includes all previous 94 scripts and the four new standalone suites.
Existing expected card/combat/expedition fixtures were not regenerated. Commit IDs are
supplied with the final publication report; Phase A and Phase B are independent commits.
