extends Resource
## Presentation tuning only. No expedition state or random encounters live here.
@export var overview_position := Vector3(0, 28, 21)
@export var overview_target := Vector3.ZERO
@export_group("Overview zoom and system borders")
@export_range(0.5, 2.0, 0.01) var default_zoom: float = 1.20
@export_range(0.5, 2.0, 0.01) var minimum_zoom: float = 0.95
@export_range(0.5, 12.0, 0.01) var maximum_zoom: float = 6.0
@export_range(0.01, 0.2, 0.01) var wheel_zoom_step: float = 0.06
## X/Z world-space rectangle. Destinations retain their seeded relative arrangement.
@export var system_bounds := Rect2(-16, -10, 32, 20)
## Camera look-at center limits relative to Overview Target, in X/Z world units.
@export var pan_bounds := Rect2(-16, -10, 32, 20)
@export_range(4.0, 32.0) var pan_drag_threshold: float = 12.0
## Minimum gap between projected labels and the viewport edge, in logical pixels.
@export_range(0.0, 48.0) var screen_border: float = 8.0
@export_group("Destination and movement")
@export var destination_offset := Vector3(2.5, 3.2, 4.2)
@export_range(0.1, 3.0) var camera_duration: float = 0.8
@export_range(0.1, 5.0) var orbit_radius: float = 2.1
@export_range(0.01, 2.0) var orbit_speed: float = 0.28
@export_range(0.1, 3.0) var battle_zoom_duration: float = 0.9
## Camera-space side clearance at the flyby; positive values pass to the right.
@export_range(-6.0, 6.0, 0.1) var departure_side_offset: float = 1.4
@export_range(1.0, 100.0) var departure_speed: float = 42.0
@export_range(0.1, 3.0) var departure_duration: float = 1.0
@export_range(0.1, 2.0) var white_fade_duration: float = 0.35
@export_range(0.0, 5.0) var result_suspense_duration: float = 2.0
