extends Resource
class_name ShieldShatterSettings
# RESPONSIBILITY: Inspector tuning for the shared shield-collapse sequence.
@export var shatter_enabled: bool = true
@export_range(24, 40, 1) var shatter_fragment_count: int = 32
@export_range(0.01, 0.3, 0.01) var shatter_flash_duration: float = 0.10
@export_range(0.0, 0.5, 0.01) var shatter_fracture_start: float = 0.10
@export_range(0.1, 0.6, 0.01) var shatter_fracture_end: float = 0.35
@export_range(0.0, 0.5, 0.01) var shatter_burst_start: float = 0.20
@export_range(0.1, 1.5, 0.01) var shatter_total_duration: float = 0.75
@export_range(0.1, 6.0, 0.1) var shatter_fragment_speed: float = 2.5
@export_range(0.0, 8.0, 0.1) var shatter_fragment_rotation_speed: float = 3.0
@export_range(0.0, 3.0, 0.1) var shatter_brightness: float = 1.0
## Approximate world-space recoil, converted to a restrained canvas offset.
@export_range(0.0, 0.2, 0.01) var shatter_shake_strength: float = 0.08
@export_range(0.01, 0.5, 0.01) var shatter_shake_duration: float = 0.12
@export_color_no_alpha var shatter_fragment_color: Color = Color(0.25, 0.85, 1.0)
@export_range(0.03, 0.3, 0.01) var shatter_fragment_scale: float = 0.14
@export_range(0.0, 1.0, 0.05) var shatter_randomness: float = 0.35
@export_range(0.2, 3.0, 0.1) var shatter_fade_power: float = 1.5
