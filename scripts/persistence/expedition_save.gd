extends RefCounted
# Explicit single-run codec and checked local file replacement. No scene/node serialization.
const State = preload("res://scripts/expedition_state.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const VERSION: int = 3
const PATH: String = "user://expedition_save.json"
const COUNTERS = ["hull", "salvage", "battles_won", "pressure",
	"system_number", "next_outpost_system", "station_production_purchases", "service_revision",
	"choice_amount", "last_poi_success", "upgrades_remaining", "navigation_origin",
	"pending_destination", "chasedown_index", "chasedowns_this_system", "travel_destination"]
const ENTRY_FIELDS = ["kind", "title", "system_number", "mandatory_boss", "modifier",
	"completed", "chasedown", "response", "resolution", "intercept_position",
	"objective_role", "objective_prerequisite", "objective_known", "pressure_tolerance", "pressure_sensitive"]
const OBJECTIVE_POIS = [preload("res://encounters/fuel_depot.tres"),
	preload("res://encounters/sensor_relay.tres"), preload("res://encounters/ancient_navigation_array.tres")]
const PROFILE_IDS = ["quiet", "industrial", "hostile", "ancient"]
var path: String = PATH
var error: String = ""
var warning: String = ""
var revision: int = 0


static func _catalog(items: Array) -> Dictionary:
	var result: Dictionary = {}
	for item in items:
		result[item.resource_path] = item
	return result


static func _integer(value: Variant, low: int, high: int = 1000000000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and value >= low and value <= high


static func _int_map(value: Variant, keys: Array, low: int) -> bool:
	if not value is Dictionary: return false
	for key in value:
		if key not in keys or not _integer(value[key], low): return false
	return true


static func _entry(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ENTRY_FIELDS:
		if value.has(key): result[key] = value[key].duplicate() if key == "intercept_position" else value[key]
	if value.kind == "battle":
		result.enemy_id = value.get("enemy_data", Ships.ENEMIES[int(value.get("enemy", 0))]).resource_path
	else:
		result.poi_id = value.poi.resource_path
	return result


static func encode(state: Resource) -> Dictionary:
	var deck: Dictionary = state.deck_snapshot()
	# v1 wire shape groups these fields under navigation; ownership is now separate in memory.
	var navigation_data: Dictionary = state.navigation.snapshot()
	navigation_data.merge(state.chasedown_roll_policy.snapshot())
	var data: Dictionary = {"metagame_version": 3, "game_mode": state.game_mode, "defense": state.defense.snapshot() if state.is_defense() else {}, "pressure": state.pressure,
		"system_profile": state.system_profile, "ftl_access": state.ftl_access,
		"navigation": navigation_data, "ship_id": state.ship().resource_path,
		"seed": str(state.seed_used), "system_name": state.system_name,
		"pending_choice": state.pending_choice, "last_outcome": state.last_outcome,
		"production_upgrades": state.production_upgrades.duplicate(),
		"bonuses": state.pending_bonuses.duplicate(), "penalties": state.pending_penalties.duplicate(),
		"acquired": deck.acquired, "removed": deck.removed,
		"upgrades": {}, "upgraded_this_event": deck.upgraded_this_event,
		"offers": deck.offers,
		"pending_card": deck.pending_card,
		"encounters": [], "service": _entry(state.service) if not state.service.is_empty() else {}, "rng": {}}
	for key in COUNTERS: data[key] = state.get(key)
	data.upgrades = deck.upgrades
	for entry in state.encounters: data.encounters.append(_entry(entry))
	for key in ["rng", "station_rng", "chasedown_rng"]:
		var generator: RandomNumberGenerator = state.get(key)
		data.rng[key] = {"seed": str(generator.seed), "state": str(generator.state)}
	return data


func _decode_entry(value: Variant, ships: Dictionary, pois: Dictionary) -> Dictionary:
	if not value is Dictionary: return {}
	if value.get("kind") not in ["battle", "poi", "service"]: return {}
	if not value.get("title") is String or value.title.length() > 512: return {}
	if not value.get("completed") is bool: return {}
	for key in value:
		if key not in ENTRY_FIELDS + ["enemy_id", "poi_id", "charge_awarded"]: return {}
		if key in ["mandatory_boss", "charge_awarded", "chasedown", "objective_known", "pressure_sensitive"] and not value[key] is bool: return {}
		if key in ["system_number", "modifier", "response", "objective_prerequisite", "pressure_tolerance"] and not _integer(value[key], -1): return {}
	if value.has("intercept_position"):
		var at: Variant = value.intercept_position
		if not value.get("chasedown", false) or not at is Array or at.size() not in [2,3]: return {}
		for coordinate in at:
			if not (coordinate is float or coordinate is int) or not is_finite(float(coordinate)) or absf(float(coordinate)) > 10000: return {}
	if value.has("resolution") and value.resolution not in ["escaped", "defeated"]: return {}
	if value.has("objective_role") and value.objective_role not in ["", "access", "prerequisite"]: return {}
	var result: Dictionary = value.duplicate(true)
	result.erase("charge_awarded")
	for key in ["system_number", "modifier", "response", "objective_prerequisite", "pressure_tolerance"]:
		if result.has(key): result[key] = int(result[key])
	if value.kind == "battle":
		if not ships.has(value.get("enemy_id")): return {}
		if not _integer(value.get("modifier"), 0, State.Modifiers.NAMES.size() - 1): return {}
		result.enemy_data = ships[value.enemy_id]
		result.enemy = maxi(0, Ships.ENEMIES.find(result.enemy_data))
		result.erase("enemy_id")
	else:
		if not pois.has(value.get("poi_id")): return {}
		result.poi = pois[value.poi_id]
		result.erase("poi_id")
	return result


# Returns null on any invalid reference/shape; never loads a path supplied by a save.
func decode(data: Variant, configuration: Resource = Rules) -> Resource:
	if not data is Dictionary: return null
	var legacy: bool = not data.has("metagame_version")
	if legacy:
		data = _migrate_legacy(data)
		if data.is_empty(): return null
	if not _integer(data.get("metagame_version"), 1, 3): return null
	if data.metagame_version >= 2 and (not data.get("game_mode") is String or not data.get("defense") is Dictionary): return null
	var mode: String = data.game_mode if data.metagame_version >= 2 else "exploration"
	if mode == "exploration" and data.metagame_version >= 2 and not data.defense.is_empty(): return null
	if mode not in ["exploration", "defense"]: return null
	if data.get("system_profile") not in PROFILE_IDS or not data.get("ftl_access") is bool: return null
	var players: Dictionary = _catalog(Ships.PLAYERS)
	var enemies: Dictionary = _catalog(Ships.ENEMIES + configuration.enemy_ships + [configuration.progression.mandatory_boss_profile()])
	var pois: Dictionary = _catalog(configuration.pois + [configuration.trading_outpost] + OBJECTIVE_POIS)
	var cards: Dictionary = _catalog(Cards.CARDS)
	if not players.has(data.get("ship_id")): return null
	if not data.get("seed") is String or not data.seed.is_valid_int(): return null
	for key in ["system_name", "last_outcome", "pending_choice", "pending_card"]:
		if not data.get(key) is String or data[key].length() > 65536: return null
	if data.pending_choice not in ["", "card", "upgrade", "replace", "resource", "production"]: return null
	for key in COUNTERS:
		var minimum: int = -3 if key in ["navigation_origin", "travel_destination", "pending_destination"] else (-1 if key in ["chasedown_index", "last_poi_success"] else 0)
		if not _integer(data.get(key), minimum): return null
	if data.hull <= 0 or data.system_number < 1 or data.salvage < 0: return null
	if int(data.last_poi_success) not in [-1, 0, 1]: return null
	if not _int_map(data.get("production_upgrades"), State.PRODUCTION, 0): return null
	var modifier_keys: Array = State.RESOURCES + ["shields", "emp_pulse_charge", "emp_pulse_offline"]
	if not _int_map(data.get("bonuses"), modifier_keys, 0) or not _int_map(data.get("penalties"), modifier_keys, -1000000000): return null
	for key in ["acquired", "removed", "upgraded_this_event", "offers"]:
		if not data.get(key) is Array or data[key].size() > Cards.CARDS.size(): return null
		var seen: Dictionary = {}
		for id in data[key]:
			if not cards.has(id) or seen.has(id): return null
			seen[id] = true
	if data.pending_card != "" and not cards.has(data.pending_card): return null
	if data.pending_choice == "replace" and data.pending_card == "": return null
	if data.pending_choice == "card" and data.offers.is_empty(): return null
	if not data.get("upgrades") is Dictionary: return null
	for id in data.upgrades:
		if not cards.has(id) or not _integer(data.upgrades[id], 1, mini(cards[id].max_upgrades, cards[id].upgrade_effects.size())): return null
	if not data.get("encounters") is Array or data.encounters.is_empty() or data.encounters.size() > 100: return null
	var entries: Array[Dictionary] = []
	for value in data.encounters:
		var entry: Dictionary = _decode_entry(value, enemies, pois)
		if entry.is_empty() or entry.kind == "service": return null
		entries.append(entry)
	if mode == "exploration" and not _valid_objectives(entries, data.ftl_access): return null
	if not data.get("service") is Dictionary: return null
	var service: Dictionary = {}
	if not data.service.is_empty():
		service = _decode_entry(data.service, enemies, pois)
		if service.is_empty() or service.kind != "service": return null
	for key in ["navigation_origin", "pending_destination", "chasedown_index", "travel_destination"]:
		if data[key] >= entries.size(): return null
	if data.chasedown_index >= 0 and not entries[int(data.chasedown_index)].get("chasedown", false): return null
	if not data.get("rng") is Dictionary: return null
	for key in ["rng", "station_rng", "chasedown_rng"]:
		var generator: Variant = data.rng.get(key)
		if not generator is Dictionary: return null
		for field in ["seed", "state"]:
			if not generator.get(field) is String or not generator[field].is_valid_int(): return null
	var state = State.new()
	if not data.get("navigation") is Dictionary or not state.navigation.restore(data.navigation): return null
	if not state.chasedown_roll_policy.restore(data.navigation): return null
	if not _valid_navigation(data, entries): return null
	# Version 2 defense saves predate reserve identities. Reuse the existing
	# attacker profile without consuming the saved gameplay RNG.
	var migrated_reserves: Array = []
	if mode == "defense" and data.metagame_version == 2 and not data.defense.get("complete", false):
		if entries.size() < 3 or entries[0].kind != "battle": return null
		for i in range(configuration.defense_tuning.maximum_reinforcements):
			migrated_reserves.append(entries.size())
			var reserve: Dictionary = entries[0].duplicate(true)
			reserve.completed = false
			reserve.erase("resolution")
			entries.append(reserve)
	state.game_mode = mode
	if mode == "defense":
		if data.metagame_version >= 3:
			for key in ["reinforcement_remaining", "reinforcements_spawned", "deferred_seconds"]:
				if not data.defense.has(key): return null
			if not data.defense.get("units") is Array: return null
			for unit in data.defense.units:
				if not unit is Dictionary or not unit.has("reinforcement") or not unit.has("spawned"): return null
		state.defense = State.Defense.new()
		if not state.defense.restore(data.get("defense"), configuration.defense_tuning, entries): return null
		if not migrated_reserves.is_empty(): state.defense.add_reserves(migrated_reserves)
		if state.defense.failed() or state.defense.anchors.has(State.SERVICE_INDEX) != not service.is_empty(): return null
		if state.defense.contact >= 0 and state.navigation.leg_active: return null
	state.bind_defense_movement()
	state.system_profile = data.system_profile
	state.ftl_access = data.ftl_access
	state.rules = configuration
	state.player_ship = Ships.PLAYERS.find(players[data.ship_id])
	state.seed_used = int(data.seed)
	for key in COUNTERS:
		if key != "upgrades_remaining": state.set(key, int(data[key]))
	state.system_name = data.system_name
	state.last_outcome = data.last_outcome
	state.production_upgrades = data.production_upgrades.duplicate()
	state.pending_bonuses = data.bonuses.duplicate()
	state.pending_penalties = data.penalties.duplicate()
	for values in [state.production_upgrades, state.pending_bonuses, state.pending_penalties]:
		for key in values: values[key] = int(values[key])
	# Older v1 checkpoints may still contain the superseded continuation command.
	if state.pending_destination >= 0 and state.chasedown_index >= 0:
		state.travel_destination = -1
	state.encounters = entries
	state.service = service
	state.restore_deck(data, cards)
	var owned: Dictionary = {}
	for card in state.player_pool(): owned[card.identity_key()] = true
	for id in data.upgrades:
		if not owned.has(id): return null
	for id in data.upgraded_this_event:
		if not owned.has(id): return null
	if state.player_pool().size() > state.deck_limit(): return null
	for key in ["rng", "station_rng", "chasedown_rng"]:
		var generator: RandomNumberGenerator = state.get(key)
		generator.seed = int(data.rng[key].seed)
		generator.state = int(data.rng[key].state)
	return state


# Payload migration is deterministic and rewardless: retain every existing encounter,
# deck ledger, outcome and RNG stream, adding an always-viable route only when needed.
static func _migrate_legacy(original: Dictionary) -> Dictionary:
	if not _integer(original.get("ftl_charge"), 0) or not _integer(original.get("required_ftl_charge"), 1): return {}
	if not original.get("encounters") is Array: return {}
	for key in ["navigation_origin", "travel_destination", "pending_destination", "chasedown_index"]:
		if not _integer(original.get(key), -2): return {}
	var data: Dictionary = original.duplicate(true)
	data.metagame_version = 1
	data.system_profile = "industrial"
	data.pressure = 0
	data.ftl_access = int(data.ftl_charge) >= int(data.required_ftl_charge)
	data.erase("ftl_charge")
	data.erase("required_ftl_charge")
	for entry in data.encounters:
		if not entry is Dictionary: return {}
		if entry.get("completed", false) and not entry.get("chasedown", false): data.pressure += 1
		entry.erase("charge_awarded")
	if not data.ftl_access:
		data.encounters.append({"kind": "poi", "poi_id": OBJECTIVE_POIS[0].resource_path,
			"title": OBJECTIVE_POIS[0].title, "completed": false, "objective_role": "access",
			"objective_prerequisite": -1, "objective_known": false, "pressure_sensitive": false,
			"pressure_tolerance": 12})
	var traveling: bool = int(data.get("travel_destination", -1)) != -1
	var position: Array = []
	var chase: int = int(data.get("chasedown_index", -1))
	if chase >= 0 and chase < data.encounters.size():
		var entry: Dictionary = data.encounters[chase]
		if entry.get("chasedown", false) and not entry.get("completed", false):
			traveling = false
			data.travel_destination = -1
			var saved: Variant = entry.get("intercept_position", [])
			if not saved is Array: return {}
			if saved.size() == 3: position = saved.duplicate()
			elif saved.size() == 2: position = [saved[0], 0.0, saved[1]]
	data.navigation = {"position": position, "target": [], "leg_active": traveling,
		"rolled_this_leg": traveling, "cooldown_remaining": 10.0}
	# Older numeric travel has no world target; presentation restores it from the marker.
	return data


static func _valid_objectives(entries: Array[Dictionary], access: bool) -> bool:
	var routes: int = 0
	for index in range(entries.size()):
		var entry: Dictionary = entries[index]
		var role: String = entry.get("objective_role", "")
		var prerequisite: int = int(entry.get("objective_prerequisite", -1))
		if role.is_empty():
			if prerequisite != -1: return false
			continue
		if entry.kind != "poi" or entry.get("pressure_sensitive", false): return false
		if not entry.get("poi") in OBJECTIVE_POIS: return false
		if role == "prerequisite":
			if prerequisite != -1: return false
		else:
			routes += 1
			if prerequisite >= 0:
				if prerequisite >= entries.size() or prerequisite == index: return false
				var required: Dictionary = entries[prerequisite]
				if required.get("objective_role", "") != "prerequisite": return false
				if int(required.get("objective_prerequisite", -1)) != -1: return false
				if entry.completed and not required.completed: return false
			if entry.completed and not access: return false
	# A migrated already-ready run may have no objective in its historic roster.
	return routes > 0 or access


static func _valid_navigation(data: Dictionary, entries: Array[Dictionary]) -> bool:
	var nav: Dictionary = data.navigation
	var destination: int = int(data.travel_destination)
	if int(data.pending_destination) == -2: return false
	if destination == -2 and data.service.is_empty(): return false
	if destination >= 0 and entries[destination].completed: return false
	if nav.leg_active:
		if destination == -1: return false
		if destination == -3 and (nav.target.size() != 3 or nav.position.size() != 3): return false
	elif destination != -1: return false
	if not nav.leg_active and (not nav.target.is_empty() or nav.rolled_this_leg): return false
	if int(data.chasedown_index) >= 0:
		var encounter: Dictionary = entries[int(data.chasedown_index)]
		if not encounter.completed and nav.leg_active: return false
	return true


static func _json(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null


func _read(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate): return {}
	var file = FileAccess.open(candidate, FileAccess.READ)
	if file == null or file.get_length() > 2000000: return {}
	var envelope: Variant = _json(file.get_as_text())
	if not envelope is Dictionary or not _integer(envelope.get("schema"), 1, VERSION): return {}
	if not envelope.get("payload") is String or not envelope.get("sha256") is String: return {}
	if envelope.payload.sha256_text() != envelope.sha256: return {}
	var payload: Variant = _json(envelope.payload)
	if not payload is Dictionary or not _integer(payload.get("revision"), 1) or not payload.get("ended") is bool: return {}
	if not payload.ended:
		if decode(payload.get("expedition")) == null: return {}
		if not payload.get("battle") is Dictionary: return {}
		if not payload.battle.is_empty():
			if not _integer(payload.battle.get("index"), 0, payload.expedition.encounters.size() - 1): return {}
			var entry: Dictionary = payload.expedition.encounters[int(payload.battle.index)]
			if entry.kind != "battle" or entry.completed: return {}
			if not payload.battle.get("seed") is String or not payload.battle.seed.is_valid_int(): return {}
	return payload


func load_run() -> Dictionary:
	error = ""
	warning = ""
	var best: Dictionary = {}
	var source: String = ""
	var found: bool = false
	for candidate in [path, path + ".previous", path + ".tmp"]:
		found = found or FileAccess.file_exists(candidate)
		if FileAccess.file_exists(candidate):
			var envelope: Variant = _json(FileAccess.get_file_as_string(candidate))
			if envelope is Dictionary and _integer(envelope.get("schema"), 0) and int(envelope.schema) not in [1, 2, VERSION]:
				error = "This expedition save uses an unsupported version. Its files have been preserved."
				return {}
		var payload: Dictionary = _read(candidate)
		# Published data wins over an unpublished replacement. A complete, newer
		# terminal marker always wins, so death cannot recover a pre-death run.
		if not payload.is_empty() and (best.is_empty() or (payload.ended and payload.revision > best.revision)):
			best = payload
			source = candidate
	if best.is_empty():
		if found: error = "The expedition save is corrupt, incomplete or uses an unsupported version. You can start a new expedition."
		return {}
	revision = int(best.revision)
	if source != path:
		if source != path + ".tmp" and DirAccess.copy_absolute(source, path + ".tmp") != OK:
			error = "Could not recover the expedition save. Your files have been preserved."
			return {}
		if DirAccess.rename_absolute(path + ".tmp", path) != OK:
			error = "Could not restore the recovered expedition save. Your files have been preserved."
			return {}
		warning = "Recovered the last complete expedition checkpoint."
	if best.ended:
		_remove_files()
		return {}
	if not best.expedition.has("metagame_version"):
		warning += (" " if not warning.is_empty() else "") + "Updated expedition: FTL Access replaces charging; a safe access route is available. Travel interception cooldown is preserved conservatively."
	if best.expedition.get("metagame_version", 1) == 1:
		warning += (" " if not warning.is_empty() else "") + "Legacy expedition retained in exploration mode."
	return {"state": decode(best.expedition), "battle": best.battle, "data": best.expedition}


func save_run(state: Resource, battle: Dictionary = {}) -> bool:
	if state.run_ended or state.hull <= 0: return clear_run()
	return save_data(encode(state), battle)


func save_data(data: Dictionary, battle: Dictionary = {}) -> bool:
	if decode(data) == null:
		error = "The expedition could not be validated. Progress has not been overwritten."
		return false
	return _write({"expedition": data, "battle": battle, "ended": false})


func _write(payload: Dictionary) -> bool:
	error = ""
	for candidate in [path, path + ".tmp", path + ".previous"]:
		var prior: Dictionary = _read(candidate)
		if not prior.is_empty(): revision = maxi(revision, int(prior.revision))
	payload.revision = revision + 1
	var body: String = JSON.stringify(payload)
	var text: String = JSON.stringify({"schema": VERSION, "payload": body, "sha256": body.sha256_text()}, "\t")
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "Unable to write expedition progress (error %d). Your current session is still active." % FileAccess.get_open_error()
		return false
	file.store_string(text)
	file.flush()
	var status: Error = file.get_error()
	file.close()
	if status != OK or _read(path + ".tmp").is_empty():
		error = "The expedition checkpoint could not be written completely. Your current session is still active."
		return false
	if not _read(path).is_empty():
		if DirAccess.copy_absolute(path, path + ".previous") != OK or _read(path + ".previous").is_empty():
			error = "Unable to protect the previous checkpoint. Your current session is still active."
			return false
	if DirAccess.rename_absolute(path + ".tmp", path) != OK:
		error = "Unable to replace the expedition checkpoint. Your current session is still active."
		return false
	revision += 1
	DirAccess.remove_absolute(path + ".previous")
	return true


func clear_run() -> bool:
	# A durable tombstone prevents recovery of a pre-death checkpoint during cleanup.
	if not _write({"ended": true}): return false
	_remove_files()
	return true


func _remove_files() -> void:
	# Keep the tombstone if any recovery file cannot be removed.
	for candidate in [path + ".tmp", path + ".previous"]:
		if FileAccess.file_exists(candidate) and DirAccess.remove_absolute(candidate) != OK: return
	if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
