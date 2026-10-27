extends Resource
class_name ExpeditionRules

# RESPONSIBILITY: Store Inspector-editable encounter, service, reward and deck configuration.

## Optional repeatable services, independent of regular progression encounters.
@export var trading_outpost: PoiData
## TUNE: First station system and subsequent gaps. Bounds are clamped to 2–3 at runtime.
@export_range(2, 3, 1) var minimum_station_interval: int = 2
@export_range(2, 3, 1) var maximum_station_interval: int = 3
## TUNE: Shipyard base price lives in trading_outpost.tres → Approaches → Shipyard.
## First price increase (25 → 40); subsequent increases add acceleration: 15, 20, 25, ...
@export_range(0, 1000, 1) var production_price_increment: int = 15
@export_range(0, 1000, 1) var production_price_acceleration: int = 5
@export var pois: Array[PoiData] = []
@export_range(2, 20, 1) var encounters_per_system: int = 9
@export_range(1, 19, 1) var minimum_battles: int = 1
@export_range(1, 19, 1) var maximum_battles: int = 3
@export_range(0, 19, 1) var minimum_ordinary: int = 4
@export_range(0, 19, 1) var maximum_ordinary: int = 6
@export_range(0, 19, 1) var minimum_hazardous: int = 0
@export_range(0, 19, 1) var maximum_hazardous: int = 3
@export_range(0.01, 10, 0.01) var ordinary_weight: float = 1.0
@export_range(0.01, 10, 0.01) var hazardous_weight: float = 0.8
@export_range(0.01, 10, 0.01) var battle_weight: float = 1.0
@export var enemy_ships: Array[ShipData] = []
## Used only if a PoI has no affordable approach that guarantees survival.
@export var survey_penalty: Dictionary = {"energy": -3}
@export var destruction_salvage: int = 10
## TUNE: Elite rank only; multiply its existing destruction/Systems Failure reward.
@export_range(1, 10, 1) var elite_salvage_multiplier: int = 2
## TUNE: Added to each resource next battle after defeating an Elite; stacks with tactical rewards.
@export_range(0, 100, 1) var elite_resource_bonus: int = 3
## Safety net if every card has reached its upgrade limit.
@export var unavailable_upgrade_salvage: int = 4
## 0 randomizes a new expedition; a nonzero value reproduces systems, offers and PoI rolls.
@export var debug_seed: int = 0

@export var log_rolls: bool = true

@export_group("Card rewards")
## TUNE: Maximum distinct owned identities; six shipping starting pools contain 28 each.
@export_range(25, 100, 1) var max_deck_identities: int = 36
## TUNE: Tier selection per reward slot when both tiers have unowned candidates.
@export_range(0.0, 1.0, 0.01) var reward_tier_two_chance: float = 0.60
## TUNE: Acquired identity draw weight relative to starting identities (within its rarity).
@export_range(1.0, 10.0, 0.1) var acquired_card_draw_weight: float = 3.0

@export_group("Expedition progression")
## TUNE: Carryover, system difficulty and recurring mandatory Boss configuration.
@export var progression: Resource = preload("res://resources/expedition_progression.tres")

@export_group("Sublight Chasedown")
## TUNE: Chance per valid PoI-to-PoI movement; 0 disables interceptions, 1 always intercepts.
@export_range(0.0, 1.0, 0.01) var chasedown_chance: float = 0.05
## TUNE: Maximum interceptions per system; resets only on entering a new system.
@export_range(0, 5, 1) var chasedown_limit: int = 1
## TUNE: Additive risk per completed regular encounter, before profile weighting and cap.
@export_range(0.0, 1.0, 0.001) var pressure_chasedown_increment: float = 0.015
@export_range(0.0, 1.0, 0.01) var maximum_chasedown_chance: float = 0.35
## Shared active-gameplay cooldown; redirects never reset it.
@export_range(1.0, 120.0, 1.0) var chasedown_roll_cooldown: float = 10.0
## TUNE: Response titles, existing next-battle modifiers and immediate Hull adjustment.
## Evasive charge is additionally capped before the first-turn tick to avoid instant escape.
@export var chasedown_responses: Array[Dictionary] = [
	{"title": "Red Alert", "modifiers": {"shields": 4, "energy": -3}, "hull": 0},
	{"title": "Evasive Maneuvers", "modifiers": {"emp_pulse_charge": 3, "shields": -4}, "hull": 0},
	{"title": "Overcharge Weapons", "modifiers": {"energy": 5}, "hull": -3},
	{"title": "Hold Course", "modifiers": {}, "hull": 0}
]

@export_group("Combat card upgrades")
## TUNE: Distinct card identities that may each gain one level per successful battle reward.
## Escapes grant none; exhausted pools grant no additional Salvage.
@export_range(0, 10, 1) var chasedown_upgrades: int = 1
@export_range(0, 10, 1) var standard_upgrades: int = 2
@export_range(0, 10, 1) var elite_upgrades: int = 3
@export_range(0, 10, 1) var boss_upgrades: int = 3
