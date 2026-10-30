extends Resource
class_name CardMotionSettings

# RESPONSIBILITY: Store editable card animation timing.
# DOES NOT: Animate nodes or change match state.
# Edit CardMotion > Settings in the board Inspector; saved values override these defaults.
## TUNE: Set false to skip card animations.
@export var enabled: bool = true
## TUNE: Seconds for a played card to reach the center; smaller = faster.
@export_range(0.01, 3.0, 0.01) var travel_seconds: float = 0.28
## TUNE: Seconds the played card stays in the center for reading.
@export_range(0.01, 3.0, 0.01) var hold_seconds: float = 0.6
## TUNE: Seconds for the played card to leave and fade.
@export_range(0.01, 3.0, 0.01) var exit_seconds: float = 0.44
## TUNE: Shorter reading/exit phases before damage VFX; other cards keep normal timings.
@export_range(0.01, 3.0, 0.01) var damage_hold_seconds: float = 0.35
@export_range(0.01, 3.0, 0.01) var damage_exit_seconds: float = 0.25
## TUNE: Seconds for the discard scanner to dissolve the card.
@export_range(0.01, 3.0, 0.01) var discard_seconds: float = 0.44
## TUNE: Seconds for a replacement card to appear.
@export_range(0.01, 3.0, 0.01) var refill_seconds: float = 0.18
## TUNE: Size of the presented card; 1.0 = original, 1.2 = 20% larger.
@export_range(0.5, 1.5, 0.05) var stage_scale: float = 1.1
