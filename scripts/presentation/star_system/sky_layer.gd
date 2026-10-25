extends Resource
## Inspector-replaceable decoration. Assign a transparent PNG to override the procedural source.
@export var texture: Texture2D
@export_enum("Nebula", "Galaxy") var kind: int = 0
@export var tint := Color(0.25, 0.35, 0.65, 1)
@export_range(0.0, 1.0, 0.01) var opacity: float = 0.14
@export var apparent_size := Vector2(32, 20)
## Azimuth/elevation in degrees, fixed relative to the celestial sphere.
@export var angular_position := Vector2(0, 20)
@export_range(-180.0, 180.0) var rotation_degrees: float = 0.0
@export_range(0.0, 0.1, 0.01) var parallax: float = 0.0
