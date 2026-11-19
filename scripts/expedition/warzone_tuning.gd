extends Resource
## Campaign support packages are ordered from emergency to strong.

@export_range(0.01, 1.0, 0.01) var limited_integrity := 0.20
@export_range(0.01, 1.0, 0.01) var standard_integrity := 0.50
@export_range(0.01, 1.0, 0.01) var strong_integrity := 0.80
@export var allied_fleet_strength := PackedInt32Array([5, 7, 9, 11])
@export var starting_salvage := PackedInt32Array([3, 6, 10, 15])
## One-battle shield boon. This is separate from permanent production upgrades.
@export var arrival_shields := PackedInt32Array([2, 3, 5, 7])
