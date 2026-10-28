extends Resource

# RESPONSIBILITY: Configure enemy scaling and mandatory Boss milestones.
# Expedition-only progression. Never mutates a shared ShipData or combat card Resource.
@export_range(1, 100, 1) var systems_per_difficulty: int = 3
@export_range(0, 20, 1) var hull_bonus_per_level: int = 2
@export_range(0, 20, 1) var shields_bonus_per_level: int = 1
@export_range(0, 20, 1) var resource_bonus_per_level: int = 1
## TUNE: Fractional additive production accumulates, then floors to whole production.
@export_range(0.0, 2.0, 0.05) var production_bonus_per_level: float = 0.25
@export_range(0.0, 0.25, 0.005) var elite_probability_increase: float = 0.025
@export_range(0.0, 1.0, 0.01) var maximum_elite_probability: float = 0.35
@export_range(1, 100, 1) var boss_interval: int = 6
## Defense adjustments by enemy rank: standard, elite, boss.
@export var defense_starting_shields: PackedInt32Array = [-2, 1, 1]
@export var defense_hull_growth_adjustment: PackedInt32Array = [-1, 1, 1]
@export var defense_shield_growth_adjustment: PackedInt32Array = [-1, 1, 1]
const DEFAULT_BOSS = preload("res://ships/enemy/sentinel_dreadnought.tres")
@export var boss_ship: Resource = DEFAULT_BOSS


func difficulty_level(system: int) -> int:
	return 1 + int(maxi(0, system - 1) / maxi(1, systems_per_difficulty))


func is_boss_system(system: int) -> bool:
	return system > 0 and system % maxi(1, boss_interval) == 0


func mandatory_boss_profile() -> Resource:
	return boss_ship if boss_ship != null and boss_ship.enemy_rank == 2 else DEFAULT_BOSS


func scaled_enemy(base: Resource, system: int, defense: bool = false) -> Resource:
	var steps: int = difficulty_level(system) - 1
	if steps == 0 and not defense: return base
	var result: Resource = base.duplicate(false)
	var rank: int = clampi(int(base.enemy_rank), 0, 2)
	var hull_growth: int = hull_bonus_per_level
	var shield_growth: int = shields_bonus_per_level
	var starting_shields: int = 0
	if defense:
		if defense_hull_growth_adjustment.size() > rank: hull_growth += defense_hull_growth_adjustment[rank]
		if defense_shield_growth_adjustment.size() > rank: shield_growth += defense_shield_growth_adjustment[rank]
		if defense_starting_shields.size() > rank: starting_shields = defense_starting_shields[rank]
	result.hull_capacity += steps * maxi(0, hull_growth)
	result.shields = maxi(0, result.shields + starting_shields + steps * maxi(0, shield_growth))
	for key in ["materials", "energy", "crew"]:
		result.set(key, int(base.get(key)) + steps * maxi(0, resource_bonus_per_level))
	var production: int = floori(steps * maxf(0, production_bonus_per_level))
	for key in ["synthesizer", "reactor", "quarters"]:
		result.set(key, int(base.get(key)) + production)
	return result


# Conditional probability for the currently available, weighted registry.
# A pool consisting solely of Elites has no alternative; otherwise the cap is strict.
func elite_probability(items: Array, system: int) -> float:
	var elite: float = 0
	var other: float = 0
	for profile in items:
		var weight: float = maxf(0.01, profile.encounter_weight)
		if profile.enemy_rank == 1:
			elite += weight
		else:
			other += weight
	if elite == 0:
		return 0
	if other == 0:
		return 1
	var base: float = elite / (elite + other)
	return clampf(
		base + (difficulty_level(system) - 1) * maxf(0, elite_probability_increase),
		0,
		maximum_elite_probability
	)
