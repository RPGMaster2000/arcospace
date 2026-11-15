extends Resource
class_name BattleCinematicSettings
## Camera-only tuning. Distances are relative to measured hull bounds (+X forward).
## 0.5 doubles presentation durations without touching Engine.time_scale.
@export_range(0.1, 2.0, 0.05) var playback_speed: float = 0.5
@export var introduction_seconds: Vector3 = Vector3(1.15, 1.05, 1.25)
@export var establishing_from: Vector3 = Vector3(4, 2, 4)
@export var establishing_to: Vector3 = Vector3(3, 1.4, 4)
@export var flyby_from: Vector3 = Vector3(3, -0.25, 2)
@export var flyby_to: Vector3 = Vector3(-0.4, 0.3, 3.4)
@export_range(20, 70, 1) var cinematic_fov: float = 42
@export_range(1.05, 1.8, .05) var framing_margin: float = 1.2
@export_range(1, 100, 1) var heavy_beam_threshold: int = 12
@export var attack_seconds: float = 1.25
@export var attacker_offset: Vector3 = Vector3(3, 1, 3)
@export var victim_offset: Vector3 = Vector3(-2, 1, 3)
@export var orbit_seconds: float = 2.25
@export var orbit_degrees: float = -55
@export var orbit_offset: Vector3 = Vector3(-3, 1.2, 3)
@export var boost_seconds: float = .85
@export var boost_distance: float = 18
@export var fade_seconds: float = .30


func duration(authored_seconds: float) -> float:
	return maxf(0.001, authored_seconds / maxf(0.1, playback_speed))
