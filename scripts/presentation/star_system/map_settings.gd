extends Resource
## Presentation tuning only. No expedition state or random encounters live here.
@export var overview_position := Vector3(0, 29, 24)
@export var overview_target := Vector3.ZERO
@export var destination_offset := Vector3(5, 6, 8)
@export_range(0.1, 3.0) var camera_duration: float = 0.8
@export_range(0.1, 5.0) var orbit_radius: float = 2.1
@export_range(0.01, 2.0) var orbit_speed: float = 0.28
@export_range(0.1, 3.0) var battle_zoom_duration: float = 0.9
@export_range(1.0, 100.0) var departure_speed: float = 42.0
@export_range(0.1, 3.0) var departure_duration: float = 1.0
@export_range(0.1, 2.0) var white_fade_duration: float = 0.35
@export_range(0.0, 5.0) var result_suspense_duration: float = 2.0
