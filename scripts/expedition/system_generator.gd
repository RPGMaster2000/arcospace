extends RefCounted

# Encounter construction only. ExpeditionState validates transitions and owns all generated state.
const Profiles = preload("res://scripts/expedition/system_profile.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const DEPOT = preload("res://encounters/fuel_depot.tres")
const RELAY = preload("res://encounters/sensor_relay.tres")
const ARRAY = preload("res://encounters/ancient_navigation_array.tres")

static func generate(state: Resource) -> void:
	if state.is_defense():
		_generate_defense(state)
		return
	var rules: Resource = state.rules
	var rng: RandomNumberGenerator = state.rng
	state.system_profile = Profiles.IDS[rng.randi_range(0, Profiles.IDS.size() - 1)]
	var profile: Resource = Profiles.for_id(state.system_profile)
	var ordinary: Array = []
	var hazardous: Array = []
	for poi in rules.pois:
		if poi.hazardous:
			hazardous.append(poi)
		else:
			ordinary.append(poi)
	var enemies: Array = rules.enemy_ships.duplicate()
	if enemies.is_empty():
		enemies.assign(Ships.ENEMIES)
	var count: int = maxi(2, rules.encounters_per_system)
	var compositions: Array[Dictionary] = []
	var total_weight: float = 0.0
	for battles in range(1, count + 1):
		for hazards in range(count - battles + 1):
			var normal: int = count - battles - hazards
			if battles < rules.minimum_battles or battles > rules.maximum_battles:
				continue
			if normal < rules.minimum_ordinary or normal > rules.maximum_ordinary:
				continue
			if hazards < rules.minimum_hazardous or hazards > rules.maximum_hazardous:
				continue
			if (normal > 0 and ordinary.is_empty()) or (hazards > 0 and hazardous.is_empty()):
				continue
			var weight: float = (
				pow(maxf(.01, rules.battle_weight * profile.battle_weight), battles)
				* pow(maxf(.01, rules.ordinary_weight * profile.ordinary_weight), normal)
				* pow(maxf(.01, rules.hazardous_weight * profile.hazardous_weight), hazards)
			)
			total_weight += weight
			compositions.append({"battle": battles, "ordinary": normal, "hazardous": hazards, "weight": weight})
	var composition: Dictionary
	if compositions.is_empty():
		push_warning("Encounter bounds cannot fill system; using safe fallback with objective access.")
		composition = {"battle": 1, "ordinary": count - 1, "hazardous": 0}
	else:
		var roll: float = rng.randf() * total_weight
		composition = compositions.back()
		for candidate in compositions:
			roll -= candidate.weight
			if roll <= 0:
				composition = candidate
				break
	state.system_number += 1
	state.pressure = 0
	state.ftl_access = false
	var names = ["Arco", "Kepler", "Vela", "Orion", "Lyra", "Perseus"]
	state.system_name = "%s %d" % [names[rng.randi_range(0, names.size() - 1)], state.system_number]
	state.navigation_origin = -1
	state.travel_destination = -1
	state.pending_destination = -1
	state.chasedown_index = -1
	state.chasedowns_this_system = 0
	state.encounters.clear()
	state.service = {}
	# Separate station RNG preserves loot/encounter draws and never adds duplicate services.
	if rules.trading_outpost != null and state.station_rng.randf() < profile.outpost_chance:
		state.service = {"kind": "service", "poi": rules.trading_outpost,
			"title": rules.trading_outpost.title, "completed": false}
		state.station_production_purchases = 0
	state.service_revision += 1
	var boss_system: bool = rules.progression.is_boss_system(state.system_number)
	var boss_added: bool = false
	if boss_system:
		var ordinary_enemies: Array = []
		for enemy in enemies:
			if enemy.enemy_rank != 2:
				ordinary_enemies.append(enemy)
		if not ordinary_enemies.is_empty():
			enemies = ordinary_enemies
	for category in ["ordinary", "hazardous", "battle"]:
		var library: Array = enemies if category == "battle" else (ordinary if category == "ordinary" else hazardous)
		var available: Array = library.duplicate()
		for slot in range(int(composition[category])):
			if available.is_empty():
				available = library.duplicate()
			var mandatory: bool = category == "battle" and boss_system and not boss_added
			var entry: Resource
			if mandatory:
				entry = rules.progression.mandatory_boss_profile()
				boss_added = true
			elif category == "ordinary" and available.is_empty():
				entry = DEPOT
			else:
				entry = available.pop_at(state._enemy_index(available) if category == "battle" else _poi_index(available, profile, rng))
			var encounter: Dictionary
			if category == "battle":
				encounter = {"kind": "battle", "enemy": maxi(0, Ships.ENEMIES.find(entry)),
					"enemy_data": entry, "system_number": state.system_number, "mandatory_boss": mandatory,
					"modifier": state._roll_battle_modifier(), "title": entry.ship_name, "completed": false}
			else:
				encounter = _poi(entry)
			encounter.pressure_tolerance = rng.randi_range(profile.tolerance_min, profile.tolerance_max)
			encounter.pressure_sensitive = category != "battle" and rng.randf() < profile.sensitive_chance
			state.encounters.append(encounter)
	# Objective routes replace ordinary slots, preserving category bounds and reward values elsewhere.
	# One unconditional, free route always exists, even for unusual custom registries.
	var objective_slots: Array[int] = []
	for index in state.encounters.size():
		if state.encounters[index].kind == "poi" and not state.encounters[index].poi.hazardous:
			objective_slots.append(index)
	if objective_slots.is_empty():
		state.encounters.append(_objective(DEPOT, "access", "direct"))
	else:
		state.encounters[objective_slots[0]] = _objective(DEPOT, "access", "direct")
		if objective_slots.size() >= 3 and rng.randf() < 0.5:
			state.encounters[objective_slots[1]] = _objective(RELAY, "prerequisite", "relay")
			state.encounters[objective_slots[2]] = _objective(ARRAY, "access", "array")
	for index in range(state.encounters.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Dictionary = state.encounters[index]
		state.encounters[index] = state.encounters[other]
		state.encounters[other] = swap
	var relay_index: int = -1
	for index in state.encounters.size():
		if state.encounters[index].get("_objective_id", "") == "relay":
			relay_index = index
	for encounter in state.encounters:
		if encounter.get("_objective_id", "") == "array":
			encounter.objective_prerequisite = relay_index
		encounter.erase("_objective_id")

static func _poi(entry: Resource) -> Dictionary:
	return {"kind": "poi", "poi": entry, "title": entry.title, "completed": false}

static func _objective(entry: Resource, role: String, key: String) -> Dictionary:
	var encounter: Dictionary = _poi(entry)
	encounter.merge({"objective_role": role, "objective_prerequisite": -1, "objective_known": false,
		"pressure_sensitive": false, "pressure_tolerance": -1, "_objective_id": key})
	return encounter

static func _poi_index(items: Array, profile: Resource, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for item in items:
		total += _poi_weight(item, profile)
	var roll: float = rng.randf() * total
	for index in items.size():
		roll -= _poi_weight(items[index], profile)
		if roll <= 0:
			return index
	return items.size() - 1

static func _poi_weight(item: Resource, profile: Resource) -> float:
	var key: String = item.resource_path.get_file().get_basename()
	return maxf(0.01, item.encounter_weight * float(profile.poi_weights.get(key, 1.0)))

# One concrete defense roster, preserving existing PoI/profile registries and scaling.
static func _generate_defense(state: Resource) -> void:
	state.system_number += 1
	state.system_name = "Starfront %d" % state.system_number
	state.system_profile = "industrial"
	state.pressure = 0
	state.ftl_access = false
	state.navigation_origin = -1
	state.travel_destination = -1
	state.pending_destination = -1
	state.chasedown_index = -1
	state.chasedowns_this_system = 0
	state.encounters.clear()
	state.service = {}
	var ordinary: Array = []
	var enemy_pool: Array = state.rules.enemy_ships if not state.rules.enemy_ships.is_empty() else Ships.ENEMIES
	for profile in enemy_pool:
		if profile.enemy_rank == 0: ordinary.append(profile)
	if ordinary.is_empty():
		for profile in Ships.ENEMIES:
			if profile.enemy_rank == 0: ordinary.append(profile)
	for i in range(3):
		var profile: Resource = state.rules.progression.mandatory_boss_profile() if i == 2 else ordinary[state._enemy_index(ordinary)]
		state.encounters.append({"kind": "battle", "enemy": maxi(0, Ships.ENEMIES.find(profile)), "enemy_data": profile,
			"system_number": state.system_number, "modifier": state._roll_battle_modifier(), "title": "Mothership" if i == 2 else profile.ship_name, "completed": false})
	var pois: Array = state.rules.pois.duplicate()
	var slots: Array = []
	for i in range(mini(6, pois.size())):
		var poi: Resource = pois.pop_at(state.rng.randi_range(0, pois.size()-1))
		slots.append(state.encounters.size())
		state.encounters.append(_poi(poi))
	if state.rules.trading_outpost != null:
		state.service = {"kind": "service", "poi": state.rules.trading_outpost, "title": state.rules.trading_outpost.title, "completed": false}
		slots.append(state.SERVICE_INDEX)
	state.station_production_purchases = 0
	state.service_revision += 1
	state.defense = preload("res://scripts/expedition/defense_state.gd").new()
	state.defense.deploy(state.rules.defense_tuning, state.rng.randf_range(0, TAU), [0, 1, 2], slots)
