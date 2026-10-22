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
