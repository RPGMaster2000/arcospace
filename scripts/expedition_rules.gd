extends Resource
class_name ExpeditionRules

@export var pois: Array[PoiData] = []
@export_range(2, 20, 1) var encounters_per_system: int = 6
@export_range(1, 19, 1) var minimum_battles: int = 2
@export_range(1, 19, 1) var maximum_battles: int = 3
@export var destruction_salvage: int = 10
@export var resource_victory_salvage: int = 6
@export var escape_salvage: int = 0
## Safety net if every card has reached its upgrade limit.
@export var unavailable_upgrade_salvage: int = 4
## 0 randomizes a new expedition; a nonzero value reproduces systems, offers and PoI rolls.
@export var debug_seed: int = 0
