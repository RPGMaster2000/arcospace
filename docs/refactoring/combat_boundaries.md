# Combat boundary refactor

Starting revision: `6b9297bee867edca1437eb514ceba493c0aa3ae2` (Godot 4.7.2).
The assessment's test-runner and diagnostic-countdown findings are already fixed there.

## Stage 1: ship attributes

`combat/ship_combat_state.gd` owns the nine combat attributes of a ship. Board's
existing exported names are Inspector/scene accessors, with no backing attribute
copies. Retaining these names is necessary for authored scenes and presentation
bindings. `ship_snapshot()` returns a detached dictionary for the existing rule,
AI and HUD contracts; `apply_ship_snapshot()` accepts exactly the nine attributes,
ignoring diagnostic metadata. The old dynamic property reconstruction is removed.
Resource/production identifiers have one definition shared by rules, effects,
expedition and presentation.

This deliberately preserves the existing specialized dictionary-based rules.
It does not convert card effects or AI to a second representation, change authored
starting values, or move the pending Hull damage commit ahead of its impact cue.

| First-party runtime metric | Before | Stage 1 |
|---|---:|---:|
| Scripts | 76 | 77 |
| Lines including comments/blanks | 11,369 | 11,442 |
| Board lines | 993 | 1,019 |
| Resource/production identifier definitions | 5 pairs | 1 pair |
| Stores for each live ship's attributes | exported properties plus temporary rule dictionaries | typed state; detached rule snapshots |

The line increase pays for explicit fields and scene accessors. State ownership
and accepted keys are simpler; controller responsibilities are not yet reduced.

Stage 1 verification: original main's 64 headless scripts passed. The migrated
suite's 65 headless scripts passed, plus the subsequently added exact-trace test
(72 battles / 4,530 checkpoints). All 19 rendered workflow scripts passed with
software OpenGL. The nine Python runner tests passed. Existing ObjectDB shutdown
warnings remain recorded separately; no script/engine errors or assertion failures.

## Stage 2: shared execution

`combat/combat_execution.gd` shares action legality, play/discard resolution,
extra-action decisions, income, turn/round advancement, failure end-turn ordering
and terminal outcome precedence. Its small `Resolution` contract carries the
announcement, intermediate Hull damage report and extra-action flag. Existing
CardEffects, CombatModifier, MatchRules and SystemsFailure still own their rules.
The Board and both diagnostic runners use this sequence. Simulation seeds, draw
policies, EMP policy, counters and limits remain in diagnostic code. The newer
runner now reports its actual checked-out revision instead of a historical label.

The live adapter still owns modifier warnings, hand nodes, animation waits,
queued Hull commits and FTL feedback. Moving that lifecycle into a large session
would expand this refactor disproportionately. In particular, a determined action
is applied to snapshots first; shield-break overflow is still staged before those
snapshots are committed, and PendingHullDamage still releases Hull at the burst
cue. Headless execution has no visual wait. Neither adapter reimplements effects.

Result recording and next-modifier selection moved from `refresh_display()` to
terminal transitions. Repair selection is a derived, clamped value, so display
refresh no longer changes combat, rewards or the selection. Music remains a
presentation-only reveal latch. Fixtures that assign results directly now commit
them explicitly before testing presentation.

Runtime at this stage: 78 scripts, 11,499 lines; Board 1,006 lines. This is +57
runtime lines over Stage 1, while removing independent play/discard and outcome
implementations from both simulations. There is one action rule implementation,
not three. This reduces rule drift and HUD side effects, rather than just moving
Board code. Animation/round-event orchestration remains deliberately separate.

Exact baseline parity: 72 newer-runner battles / 4,530 checkpoints; also 36 older
progression runs across all players and all three deck modes. A targeted test
checks 72 live-vs-headless card resolutions across both actors and six modifiers,
illegal-action nonmutation, failure timing, Hull precedence and reward idempotence.

Stage 2 verification: all 67 headless scripts and all 19 rendered workflow scripts
passed, plus nine Python runner tests. Exact trace and older-runner comparisons
passed again after switching both diagnostics to shared turn advancement. Shutdown
warnings remain; no script errors, failed assertions or gameplay tuning changes.

## Stage 3: expedition boundary

`BattleSetup` carries profiles, initial typed ship states, card pools/weights,
EMP configuration, encounter modifier, currency and encounter/system identity.
`BattleResult` carries a stable result identity, outcome/cause, remaining Hull,
Salvage, battle count and earned bonuses. Expedition FTL gain is calculated from
the identified encounter, retaining the existing profile/progression rules.
Neither contract contains a scene node.

`ExpeditionState.prepare_battle()` consumes temporary bonuses and returns setup
data. The scene controller configures the Board before adding it; direct Board
construction obtains the same data during initialization. `BattleAdapter` applies
setup once and produces results. It also synchronizes the live hand when the
expedition ledger emits `deck_changed`. Removing a Board disconnects its listener
through Godot's bound-object signal lifecycle. Expedition state no longer stores
`active_player_hand`, reads/writes Board fields, or mutates hand internals.

`record_battle()` accepts only typed results. Stable result IDs prevent replays;
encounter/system checks reject stale results, and the existing `charge_awarded`
guard still prevents a different result object completing the same encounter twice.
The small result-ID ledger is cleared when entering a new system. Post-battle
repairs synchronize persistent values through the same result data contract.

The first regression run exposed an overly strict assumption that every encounter
had a numeric `enemy` key. Existing Resource-only enemy encounters are supported;
the setup builder was corrected and the 36 player/enemy integration fixtures
passed again. The new boundary test covers that form as well as node-free reward
processing, distinct-object reward replay, stale-system rejection, setup
idempotence, detached live state, upgrades/removals and listener cleanup.

## Final code-health comparison

| Metric | Before | After |
|---|---:|---:|
| First-party runtime scripts | 76 | 81 |
| Runtime lines, including comments/blanks | 11,369 | 11,615 |
| Board lines | 993 | 1,020 |
| Expedition controller lines | 1,039 | 1,032 |
| Expedition state lines | 1,135 | 1,136 |
| Both diagnostic runner lines | 275 | 266 |
| Resource/production identifier definitions | 5 pairs | 1 pair |
| Independent action/outcome rule implementations | 3 | 1 |
| Expedition APIs accepting live Board nodes | 7 | 0 |
| Expedition live-hand fields | 1 | 0 |
| Gameplay mutations in HUD refresh | 3 | 0 |
| Literal runtime script dependency cycles | 0 | 0 |

Total runtime size increased by **246 lines (2.2%)**. This is not a line-count
reduction or a full session rewrite. The improvement is narrower and concrete:
one state owner, shared action/turn/outcome rules, read-only combat rendering,
and a node-free expedition boundary replace competing contracts and repeated
rules. Typed fields, scene-compatible accessors and explicit transfer contracts
account for the added size. No general-purpose manager, factory, interface,
external dependency or permanent legacy API adapter was added.

### Files and responsibilities

New runtime files: `scripts/combat/ship_combat_state.gd`, `combat_execution.gd`,
`battle_setup.gd`, `battle_result.gd`, `battle_adapter.gd` (the latter four share
the same directory). Modified runtime files: `scripts/board.gd`,
`scripts/expedition.gd`, `scripts/expedition_state.gd`, `scripts/match_rules.gd`,
`scripts/cards/card_effects.gd`, `scripts/battle_effects.gd`.

New suites: `combat_state_test.gd`, `combat_trace_test.gd`,
`combat_execution_test.gd`, `expedition_boundary_test.gd`. Existing combat,
reward, expedition and UI fixtures were migrated to snapshots, explicit result
commits and typed results. Both simulation runners use shared execution. Commit
file lists provide the complete per-stage fixture/UID inventory.

### Remaining coupling and scope

Board still coordinates modifier warnings, FTL feedback, hand replacement,
animation waits, navigation and the pending-Hull lifecycle. Its expedition HUD
and reward queries still reference expedition state, but only pass data back to
it. The existing dictionary-based card-effect/AI interfaces remain behind detached
snapshots; card/profile Resources retain the project's copy-on-upgrade convention.
Station/trading/map logic remains in expedition state. These are intentional scope
limits, not newly implemented persistence or a claim of complete decoupling.

All card/ship Resources, scene files, shaders, renderer settings and vendor/addon
sources are unchanged. Software OpenGL rendered tests validate presentation;
physical Android/GPU performance and exhaustive stochastic combinations are not
claimed. Existing ObjectDB exit warnings remain visible rather than suppressed.

### Final verification

- Shared runner: all **68 headless regression scripts** exercised. Sixty-seven
  passed in the first Stage 3 sweep; the Resource-only enemy regression was fixed
  and the roster script then passed all 602 checks. No unresolved failing test.
- All **19 rendered workflow scripts** passed with software OpenGL. After the
  final fix, roster, boundary and real startup tests also passed rendered retests.
- **72 exact seeded traces / 4,530 checkpoints** passed at every stage, plus the
  36 older progression-run comparisons and 72 live/headless action comparisons.
- Source and exported-pack startup passed **72 checks** each. The final pack was
  launched from an empty directory outside the source checkout. The existing
  startup test's `packed=false` suffix uses an unreliable path-suffix diagnostic;
  the command used `--main-pack` and the external directory had no source project.
- All **nine Python test-runner tests** passed; clean imports, pack export,
  `git diff --check` and the literal script dependency-cycle scan passed.
- Existing ObjectDB shutdown warnings were retained in logs. These results are
  representative regression evidence, not exhaustive card-combination proof.
