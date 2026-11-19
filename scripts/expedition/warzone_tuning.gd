extends Resource
## Campaign support packages are ordered from emergency to strong.

@export_range(0.01, 1.0, 0.01) var limited_integrity := 0.20
@export_range(0.01, 1.0, 0.01) var standard_integrity := 0.50
@export_range(0.01, 1.0, 0.01) var strong_integrity := 0.80
@export var allied_fleet_strength := PackedInt32Array([5, 7, 9, 11])
@export var starting_salvage := PackedInt32Array([3, 6, 10, 15])
## One-battle shield boon. This is separate from permanent production upgrades.
@export var arrival_shields := PackedInt32Array([2, 3, 5, 7])

@export_group("Fleet operations")
@export_range(1, 60, 1) var capture_seconds := 6
@export_range(1, 120, 1) var consolidation_seconds := 15
@export_range(1, 30, 1) var exchange_seconds := 4
@export_range(0.25, 5.0, 0.05) var fleet_speed := 1.15
@export_range(0.5, 6.0, 0.1) var engagement_radius := 2.2
@export_range(0.5, 6.0, 0.1) var objective_radius := 2.6
@export_range(3, 30, 1) var hostile_strength := 8
@export_range(2, 30, 1) var heavy_damage_strength := 8
@export_range(0.0, 1.0, 0.05) var decisive_survival := 0.65
@export_range(0.0, 1.0, 0.05) var hard_fought_survival := 0.30
@export_range(0, 100, 1) var decisive_salvage := 15
@export_range(0, 100, 1) var hard_fought_salvage := 8
@export_range(0, 100, 1) var pyrrhic_salvage := 3
