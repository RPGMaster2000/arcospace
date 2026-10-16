extends Resource
class_name ExpeditionRules

## Optional repeatable services, independent of the six progression encounters.
@export var trading_outpost: PoiData
## TUNE: First station system and subsequent gaps. Bounds are clamped to 2–3 at runtime.
@export_range(2, 3, 1) var minimum_station_interval: int = 2
@export_range(2, 3, 1) var maximum_station_interval: int = 3
## TUNE: Shipyard base price lives in trading_outpost.tres → Approaches → Shipyard.
## First price increase (25 → 40); subsequent increases add acceleration: 15, 20, 25, ...
@export_range(0, 1000, 1) var production_price_increment: int = 15
@export_range(0, 1000, 1) var production_price_acceleration: int = 5
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

@export_group("Card rewards")
## TUNE: Tier selection per reward slot when both tiers have unowned candidates.
@export_range(0.0, 1.0, 0.01) var reward_tier_two_chance: float = 0.60
## TUNE: Acquired identity draw weight relative to starting identities (within its rarity).
@export_range(1.0, 10.0, 0.1) var acquired_card_draw_weight: float = 3.0
