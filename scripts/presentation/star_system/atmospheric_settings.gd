extends Resource
## Cosmetic composition only. These weights never enter system/gameplay generation.
@export var enabled := true
@export_group("Exclusive accents (remaining weight is quiet)")
@export_range(0.0, 1.0, 0.01) var panorama_chance := 0.30
@export_range(0.0, 1.0, 0.01) var rocks_chance := 0.20
@export_range(0.0, 1.0, 0.01) var moon_chance := 0.15
@export_range(0.0, 1.0, 0.01) var anomaly_chance := 0.05
@export_group("Visual budget")
@export_range(0.0, 1.0, 0.01) var busy_system_multiplier := 0.30
@export_range(0.0, 0.5, 0.01) var image_opacity := 0.26
@export_range(0.0, 1.0, 0.01) var image_brightness := 0.62
@export_range(4, 24, 1) var rock_count := 16
@export_range(0.25, 1.0, 0.05) var android_fraction := 0.5
