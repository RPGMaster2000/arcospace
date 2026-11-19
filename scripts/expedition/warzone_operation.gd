extends RefCounted
## Build ordinary encounter identities backed by the Warzone simulation.

const Warzone = preload("res://scripts/expedition/warzone_state.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
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
	state.system_name = "Vela %d" % state.system_number
	state.system_profile = "hostile"
	state.system_variation = {}
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
	for index in Warzone.HOSTILE_GROUPS:
		var enemy := Factions.enemy(state, faction, index)
		state.encounters.append({"kind": "battle", "title": enemy.ship_name,
			"enemy": maxi(0, Ships.ENEMIES.find(enemy)), "enemy_data": enemy, "modifier": 0,
			"system_number": state.system_number, "completed": false})
	for index in OBJECTIVE_MODELS.size():
		state.encounters.append({"kind": "poi", "title": Warzone.OBJECTIVES[index],
			"poi": OBJECTIVE_MODELS[index], "completed": false})
