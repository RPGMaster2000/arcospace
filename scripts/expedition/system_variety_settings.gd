extends Resource
## New-system tuning only. Saved profiles/coordinates are never regenerated.
@export var enabled := true
## Conventional / unusual / extreme / chaotic, available from system one.
@export var layout_weights := Vector4(50, 30, 15, 5)
@export var common_poi_range := Vector2i(5, 9)
@export var sparse_poi_range := Vector2i(3, 4)
@export var dense_poi_range := Vector2i(10, 12)
@export var poi_count_weights := Vector3(70, 15, 15)
@export_range(0.0, 1.0) var binary_chance := 0.12
@export_range(0.0, 1.0) var background_chance := 0.65
@export_range(0.0, 1.0) var quasar_chance := 0.06
@export_range(10.0, 40.0) var minimum_arrival_seconds := 20.0
@export var solar_radius_ranges: Array[Vector2] = [Vector2(5, 8), Vector2(9, 14), Vector2(15, 21)]
@export var storm_extent_ranges: Array[Vector2] = [Vector2(3, 6), Vector2(6, 10), Vector2(11, 17)]
