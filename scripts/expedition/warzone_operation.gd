extends RefCounted
## Build ordinary encounter identities backed by the Warzone simulation.

const DeveloperLaunch = preload("res://scripts/expedition/developer_launch.gd")
const Warzone = preload("res://scripts/expedition/warzone_state.gd")
const Sector = preload("res://scripts/expedition/warzone_sector.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Discoveries = preload("res://scripts/expedition/warzone_discoveries.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const OBJECTIVE_MODELS := [
	preload("res://encounters/sensor_relay.tres"),
	preload("res://encounters/trading_outpost.tres"),
	preload("res://encounters/ancient_navigation_array.tres"),
]


static func protected_outpost(rules: Resource) -> Dictionary:
	var outpost: Resource = rules.trading_outpost if rules.trading_outpost != null else OBJECTIVE_MODELS[1]
	return {"kind": "service", "poi": outpost, "title": outpost.title, "completed": false}


static func generate(state: Resource, support: Dictionary) -> void:
	state.system_number += 1
	state.system_name = ("Vela Sector %d" if state.rules.warzone_lattice_enabled else "Vela %d") % state.system_number
	state.system_profile = "hostile"
	state.system_variation = {}
	if state.rules.warzone_lattice_enabled:
		state.warzone = Sector.new()
		state.warzone.setup_sector(state.rules.warzone_tuning, support.fleet_strength,
			state.layout_expansion, state.seed_used, state.system_number)
	else:
		state.warzone = Warzone.new()
		state.warzone.setup(state.rules.warzone_tuning, support.fleet_strength, maxf(1.0, state.layout_expansion))
	state.warzone._notice("%s Homeworld support · +%d Salvage · +%d Shields next battle." % [
		support.tier.capitalize(), support.salvage, support.shields])
	state.defense = null
	state.defense_poi_version = 0
	state.decoys = 0
	state.ftl_access = false
	state.pressure = 0
	state.navigation_origin = -1
	state.travel_destination = -1
	state.pending_destination = -1
	state.chasedown_index = -1
	state.chasedowns_this_system = 0
	state.encounters.clear()
	state.service = protected_outpost(state.rules)
	state.station_production_purchases = 0
	state.service_revision += 1
	var faction := Factions.select(state)
	state.faction_id = faction.id
	# Normal campaign Warzone begins at System 2. An earlier test uses the standard roster.
	var early_test: bool = state.system_number == 1 and not state.developer_test.is_empty()
	var escalated: bool = state.warzone.is_lattice() and not early_test
	for index in Warzone.HOSTILE_GROUPS:
		_add_contact(state, faction, escalated, index, false)
	for index in state.warzone.objectives.size():
		state.encounters.append({"kind": "poi", "title": state.warzone.objective_name(index),
			"poi": OBJECTIVE_MODELS[state.warzone.role_index(index) % OBJECTIVE_MODELS.size()] if state.warzone.is_lattice() else OBJECTIVE_MODELS[index], "completed": false})

	if state.warzone.is_lattice() and state.warzone.has_reserves():
		_add_contact(state, faction, escalated, Warzone.HOSTILE_GROUPS, true)


static func _add_contact(state: Resource, faction: Resource, escalated: bool, slot: int, dormant: bool) -> void:
	var enemy := _sector_enemy(state, faction, slot) if escalated else Factions.enemy(state, faction, slot)
	enemy = DeveloperLaunch.enemy(state, enemy, slot, faction)
	state.encounters.append({"kind": "battle", "title": enemy.ship_name,
		"enemy": maxi(0, Ships.ENEMIES.find(enemy)), "enemy_data": enemy, "modifier": 0,
		"system_number": state.system_number, "completed": dormant})
	if escalated and state.developer_enemy_rank() < 0:
		state.encounters.back().warzone_rank = maxi(1, enemy.enemy_rank)


static func _sector_enemy(state: Resource, faction: Resource, index: int) -> Resource:
	if index == 2 and faction.mothership is ShipData and faction.mothership.enemy_rank == 2:
		return faction.mothership
	var elites: Array = faction.elite_roster.filter(func(ship): return ship is ShipData and ship.enemy_rank == 1)
	if not elites.is_empty(): return elites[index % elites.size()]
	var roster := Factions.roster(faction, state.system_number)
	roster.sort_custom(func(a, b): return a.hull_capacity > b.hull_capacity)
	return roster[index % mini(2, roster.size())] if not roster.is_empty() else Factions.enemy(state, faction, index)


# These are existing modifiers. Solar Flare is excluded in this starless sector.
# Physical hazards still apply to contacts without an assigned modifier.
static func assign_modifiers(state: Resource) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:warzone-battle-modifiers:v1" % [state.seed_used, state.system_number])
	var available := [1, 2, 4, 5, 6, 7]
	for index in state.encounters.size():
		var encounter: Dictionary = state.encounters[index]
		if encounter.kind != "battle" or rng.randf() >= state.rules.warzone_tuning.battle_modifier_chance:
			continue
		var fleet: Dictionary = state.warzone_fleet(index)
		# A contact deployed around industrial logistics leans toward debris
		# or material storms, but draws from the same single-modifier pool.
		var industrial: bool = state.warzone.facility(fleet.at) in ["sabotage", "deploy"]
		var preferred := available.filter(func(id): return id in [1, 6])
		var pool := preferred if industrial and not preferred.is_empty() and rng.randf() < 0.45 else available
		var choice: int = pool[rng.randi_range(0, pool.size() - 1)]
		available.erase(choice)
		encounter.modifier = choice
