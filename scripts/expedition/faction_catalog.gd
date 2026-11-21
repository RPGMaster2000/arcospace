extends RefCounted
## Selection streams are derived independently, never stored as mutable gameplay RNG.
const DEFAULTS: Array[Resource] = [
	preload("res://factions/scavengers.tres"),
	preload("res://factions/iron.tres"),
	preload("res://factions/axiom.tres"),
	preload("res://factions/choir.tres")
]


static func roster(profile: Resource, system: int = 0) -> Array:
	if profile == null:
		return []
	var result: Array = []
	for ship in profile.standard_roster:
		if (
			ship is ShipData
			and ship.enemy_rank == 0
			and not ship.resource_path.is_empty()
			and (system == 0 or ship.minimum_defense_system <= system)
		):
			result.append(ship)
	return result


static func eligible(rules: Resource) -> Array:
	var result: Array = []
	var ids: Array = []
	for profile in rules.factions:
		if (
			profile is FactionProfile
			and not profile.id.is_empty()
			and profile.id.length() <= 128
			and not ids.has(profile.id)
			and is_finite(profile.selection_weight)
			and profile.selection_weight > 0
			and not roster(profile).is_empty()
		):
			result.append(profile)
			ids.append(profile.id)
	return result if not result.is_empty() else DEFAULTS


static func find(rules: Resource, id: String) -> Resource:
	for profile in eligible(rules):
		if profile.id == id:
			return profile
	return null


static func select(state: Resource) -> Resource:
	var choices: Array = eligible(state.rules)
	if state.rules.fixed_opening_factions and state.developer_test.is_empty():
		var pinned := ""
		if state.system_number == 1 and state.is_defense(): pinned = "scavenger_clans"
		elif state.system_number == 2 and state.is_warzone(): pinned = "axiom_collective"
		for profile in choices:
			if profile.id == pinned: return profile
	var alternatives := choices.filter(func(profile): return profile.id != state.faction_id)
	if not alternatives.is_empty():
		choices = alternatives
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:faction:v1" % [state.seed_used, state.system_number])
	var total := 0.0
	for profile in choices:
		total += profile.selection_weight
	var roll := rng.randf() * total
	for profile in choices:
		roll -= profile.selection_weight
		if roll < 0:
			return profile
	return choices.back()


static func enemy(state: Resource, profile: Resource, slot: int) -> Resource:
	var pool := roster(profile, state.system_number)
	if pool.is_empty():
		pool = roster(profile)  # Custom gated-only rosters must remain playable.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(
		"%d:%d:%s:%d:faction-enemy:v1" % [state.seed_used, state.system_number, profile.id, slot]
	)
	var weights: Array[float] = []
	var total := 0.0
	for ship in pool:
		var raw: Variant = profile.enemy_weights.get(ship.resource_path, ship.encounter_weight)
		var weight := float(raw) if raw is float or raw is int else 0.01
		weight = weight if is_finite(weight) and weight > 0 else 0.01
		weights.append(weight)
		total += weight
	var roll := rng.randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll < 0:
			return pool[i]
	return pool.back()


static func ships(rules: Resource) -> Array:
	var result: Array = []
	for profile in eligible(rules):
		result.append_array(roster(profile))
		for ship in profile.elite_roster:
			if ship is ShipData and ship.enemy_rank == 1 and not ship.resource_path.is_empty():
				result.append(ship)
		if (
			profile.mothership is ShipData
			and profile.mothership.enemy_rank == 2
			and not profile.mothership.resource_path.is_empty()
		):
			result.append(profile.mothership)
	return result
