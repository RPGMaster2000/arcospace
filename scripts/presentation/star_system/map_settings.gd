extends Resource
## Presentation tuning only. No expedition state or random encounters live here.
@export var overview_position := Vector3(0, 78, 112)
@export var overview_target := Vector3.ZERO
@export_range(15.0, 60.0) var field_of_view: float = 22.0
@export_group("System lighting")
@export_range(0.0, 1.0, 0.01) var ambient_light_energy: float = 0.28
@export_range(1.0, 2.0, 0.1) var sun_core_scale: float = 2.0
@export_range(0.0, 8.0, 0.1) var sunlight_energy: float = 2.8
@export_range(32.0, 96.0, 1.0) var sunlight_range: float = 64.0
@export_group("Overview zoom and system borders")
@export_range(0.5, 2.0, 0.01) var default_zoom: float = 1.20
@export_range(0.5, 2.0, 0.01) var minimum_zoom: float = 0.95
@export_range(0.5, 12.0, 0.01) var maximum_zoom: float = 6.0
@export_range(0.01, 0.2, 0.01) var wheel_zoom_step: float = 0.06
## X/Z world-space rectangle. Destinations retain their seeded relative arrangement.
@export var system_bounds := Rect2(-24, -24, 48, 48)
## Camera look-at center limits relative to Overview Target, in X/Z world units.
@export var pan_bounds := Rect2(-24, -24, 48, 48)
@export_range(4.0, 32.0) var pan_drag_threshold: float = 12.0
## Screen-space offset above each object; labels may extend beyond the viewport.
@export var label_offset := Vector2(0, -12)
@export_group("Destination and movement")
@export var destination_offset := Vector3(3.75, 4.8, 6.3)
@export_range(0.1, 3.0) var camera_duration: float = 0.8
@export_range(0.1, 5.0) var orbit_radius: float = 2.1
@export_range(0.01, 2.0) var orbit_speed: float = 0.28
@export_range(0.1, 3.0) var battle_zoom_duration: float = 0.9
## Camera-space side clearance at the flyby; positive values pass to the right.
@export_range(-6.0, 6.0, 0.1) var departure_side_offset: float = 1.4
## Finish this stationary turn before the camera closes in and acceleration begins.
@export_range(0.1, 3.0, 0.05) var departure_turn_duration: float = 1.1
@export_range(1.0, 100.0) var departure_speed: float = 42.0
@export_range(0.1, 3.0) var departure_duration: float = 1.0
@export_range(0.1, 2.0) var white_fade_duration: float = 0.35
@export_range(0.0, 5.0) var result_suspense_duration: float = 2.0

@export_group("Planet generation")
@export_range(2, 4, 1) var maximum_planets: int = 4
@export_range(0.5, 3.0, 0.1) var minimum_orbit_spacing: float = 1.5
@export_range(0.0, 0.25, 0.01) var maximum_eccentricity: float = 0.25
@export_range(0.0, 15.0, 1.0) var maximum_inclination: float = 15.0
@export var planet_radius_range := Vector2(0.45, 0.75)
@export_group("Orbit appearance")
@export var orbit_color := Color(0.48, 0.73, 0.86, 0.18)
@export_range(32, 128, 8) var orbit_segments: int = 64
## Screen pixels, so orbit paths remain visible at grazing angles and distant zoom.
@export_range(1.0, 4.0, 0.25) var orbit_line_width: float = 2.0
@export_group("Background and quality")
@export var background_layers: Array[Resource] = [preload("res://resources/presentation/sky_nebula.tres"), preload("res://resources/presentation/sky_galaxy.tres")]
@export_range(0.0, 1.0, 0.05) var background_strength: float = 0.6
## Distant-star translation response; zero restores an infinitely distant sky.
@export_range(0.0, 0.5, 0.01) var starfield_parallax: float = 0.12
@export var imported_planets: bool = true
@export var atmospheres_enabled: bool = true
@export var clouds_enabled: bool = true
@export_group("Stardust")
@export var stardust_enabled: bool = true
@export_range(0, 160, 8) var stardust_density: int = 64
@export_range(0.0, 1.0, 0.05) var stardust_parallax: float = 0.8
@export_range(0.0, 1.0, 0.01) var stardust_opacity: float = 0.55

@export_group("Replaceable encounter scenes")
@export var destination_scenes: Dictionary[String, PackedScene] = {}
