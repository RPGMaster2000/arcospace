extends Resource
class_name CardMotionSettings

# RESPONSIBILITY: Store editable card animation timing.
# DOES NOT: Animate nodes or change match state.
@export var enabled: bool = true
@export_range(0.01, 3.0, 0.01) var travel_seconds: float = 0.22
@export_range(0.01, 3.0, 0.01) var hold_seconds: float = 0.5
@export_range(0.01, 3.0, 0.01) var exit_seconds: float = 0.24
@export_range(0.01, 3.0, 0.01) var discard_seconds: float = 0.44
@export_range(0.01, 3.0, 0.01) var refill_seconds: float = 0.18
@export_range(0.5, 1.5, 0.05) var stage_scale: float = 1.0
