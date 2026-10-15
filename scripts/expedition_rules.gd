extends Resource
class_name ExpeditionRules

## Optional service station in addition to the progression encounters; one service per system visit.
@export var trading_outpost: PoiData
@export var pois: Array[PoiData] = []
@export_range(2, 20, 1) var encounters_per_system: int = 6
@export_range(1, 19, 1) var minimum_battles: int = 1
@export_range(1, 19, 1) var maximum_battles: int = 2
@export_range(0, 19, 1) var minimum_ordinary: int = 3
@export_range(0, 19, 1) var maximum_ordinary: int = 4
@export_range(0, 19, 1) var minimum_hazardous: int = 0
@export_range(0, 19, 1) var maximum_hazardous: int = 2
@export_range(0.01, 10, 0.01) var ordinary_weight: float = 1.0
@export_range(0.01, 10, 0.01) var hazardous_weight: float = 0.8
@export_range(0.01, 10, 0.01) var battle_weight: float = 1.0
@export var enemy_ships: Array[ShipData] = []
## Used only if a PoI has no affordable approach that guarantees survival.
@export var survey_penalty: Dictionary = {"energy": -3}
@export var destruction_salvage: int = 10
@export var resource_victory_salvage: int = 6
## Safety net if every card has reached its upgrade limit.
@export var unavailable_upgrade_salvage: int = 4
## 0 randomizes a new expedition; a nonzero value reproduces systems, offers and PoI rolls.
@export var debug_seed: int = 0

@export var log_rolls: bool = true
