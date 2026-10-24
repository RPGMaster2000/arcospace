# Battle ending presentation

Combat outcome calculation and reward recording still belong to Board/ExpeditionState.
These presentation changes never apply damage, roll outcomes or grant rewards again.

## Destruction

`board_3d.gd` latches one destruction sequence when a Hull ending has settled its card
and stat-change animations. `ship_3d.gd::animate_destruction()` plays nine rapid surface
explosion flashes across 1.72 seconds (one second longer than the original burst),
with a separately routed explosion sound on each flash, hides the shield and intact hull, and sends copies of
the actual model's mesh parts spinning outward and shrinking away. Debris uses a local
seeded visual generator, simple tweens and no physics. Temporary nodes belong to the
battle scene and are removed after playback or scene teardown. EMP and Systems Failure
endings retain their own causes and do not incorrectly destroy a surviving ship.

The detached HUD snapshot includes the destruction presentation lock, holding the result
screen until the explosion finishes. Ship strength refreshes keep destroyed shields hidden.
Tests may disable BattleEffects to skip terminal ship animation as well as ordinary impacts.

## Title and result reveal

`scenes/match_result.tscn` attaches `scripts/ui/result_sequence.gd`. The first reveal:

1. Fades VICTORY / DEFEAT (or the existing EMP success/draw title) in at screen center.
2. Slowly moves the title into the upper half.
3. Fades individual result lines in sequentially beneath it while the title moves.
4. Reveals the existing repair preview/controls and Continue/Main Menu controls.

The original labels remain the source of result text; no alternate reward description logic
is introduced. Long result text scrolls inside a bounded area. A transparent input cover
prevents clicking unrevealed controls. Repair controls still call the same checked spending
methods. The result remains visible during repair animations. Repeated HUD refreshes do
not restart the sequence. Scene-owned tweens are cancelled with the scene.

Inspector: open `scenes/match_result.tscn`, select **MatchResult** and adjust **Title Fade
Duration**, **Title Move Duration** and **Line Fade Duration**. The destruction burst uses
its short timing constants inside `animate_destruction()`.

## Music and upgrades

All player wins, including EMP, select `victory_normal` for standard enemies or
`victory_special` for elite/boss enemies when the result is revealed. Music playback,
mute behavior, priority and the existing tracks remain owned by Music.

Card upgrade events must spend every available awarded upgrade before returning to map
navigation. The gallery no longer offers Finish/skip; `ExpeditionState.finish_upgrades()`
also refuses premature completion. Exhausting eligible identities completes automatically.
Save & Quit preserves a pending event so it can be finished on Continue Expedition.
Older saves with no eligible candidates recover rather than leaving an empty gallery.

Regression fixtures that formerly skipped upgrade events now spend them through the same
`choose_upgrade()` API. `battle_ending_sequence_test.gd` covers destruction win/loss, EMP
victory music, terminal ordering, title placement, completed line reveal and mandatory
upgrade completion. With a display it captures each stage in `.godot/testlogs/ending-*`.
The existing music, arena, alpha-visual, upgrade, save/resume and map gesture regressions
cover the other integration boundaries. Software Mobile/Vulkan rendering is available;
physical Android performance and playback still require device testing.

Validation: all 89 shared regression scripts passed, with focused rechecks of updated
normal-arena expectations and the legacy map's asynchronous arrival test. The focused
ending sequence and 104-check map transition fixture also passed under software
Mobile/Vulkan; captures cover 1280×720 and 960×540. Physical Android testing was not run.

The `destruction_burst` catalog event reuses the generated destruction WAV at a quieter
level and slightly higher, varied pitch. The sequence owns its timing; its replay interval
is zero and its bounded nine-voice limit permits every burst even during frame catch-up.
The final `ship_destroyed` accent retains its separate catalog settings.
