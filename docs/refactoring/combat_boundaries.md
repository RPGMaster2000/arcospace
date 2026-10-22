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
