extends RefCounted
# Explicit single-run codec and checked local file replacement. No scene/node serialization.
const State = preload("res://scripts/expedition_state.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const VERSION: int = 1
const PATH: String = "user://expedition_save.json"
const COUNTERS = ["hull", "salvage", "battles_won", "ftl_charge", "required_ftl_charge",
	"system_number", "next_outpost_system", "station_production_purchases", "service_revision",
	"choice_amount", "last_poi_success", "upgrades_remaining", "navigation_origin",
	"pending_destination", "chasedown_index", "chasedowns_this_system", "travel_destination"]
const ENTRY_FIELDS = ["kind", "title", "system_number", "mandatory_boss", "modifier",
	"completed", "charge_awarded", "chasedown", "response", "resolution"]
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


static func _card_ids(items: Array) -> Array:
	var result: Array = []
	for item in items: result.append(item.identity_key())
	return result


static func _entry(value: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in ENTRY_FIELDS:
		if value.has(key): result[key] = value[key]
	if value.kind == "battle":
		result.enemy_id = value.get("enemy_data", Ships.ENEMIES[int(value.get("enemy", 0))]).resource_path
	else:
		result.poi_id = value.poi.resource_path
	return result


static func encode(state: Resource) -> Dictionary:
	var data: Dictionary = {"ship_id": state.ship().resource_path,
		"seed": str(state.seed_used), "system_name": state.system_name,
		"pending_choice": state.pending_choice, "last_outcome": state.last_outcome,
		"production_upgrades": state.production_upgrades.duplicate(),
		"bonuses": state.pending_bonuses.duplicate(), "penalties": state.pending_penalties.duplicate(),
		"acquired": _card_ids(state.acquired_cards), "removed": state.removed_starting_cards.keys(),
		"upgrades": {}, "upgraded_this_event": state.upgraded_this_event.keys(),
		"offers": _card_ids(state.card_offers),
		"pending_card": state.pending_card.identity_key() if state.pending_card != null else "",
		"encounters": [], "service": _entry(state.service) if not state.service.is_empty() else {}, "rng": {}}
	for key in COUNTERS: data[key] = state.get(key)
	for key in state.upgraded_cards: data.upgrades[key] = state.upgraded_cards[key].upgrade_level
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
		if key not in ENTRY_FIELDS + ["enemy_id", "poi_id"]: return {}
		if key in ["mandatory_boss", "charge_awarded", "chasedown"] and not value[key] is bool: return {}
		if key in ["system_number", "modifier", "response"] and not _integer(value[key], -1): return {}
	if value.has("resolution") and value.resolution not in ["escaped", "defeated"]: return {}
	var result: Dictionary = value.duplicate()
	for key in ["system_number", "modifier", "response"]:
		if result.has(key): result[key] = int(result[key])
	if value.kind == "battle":
		if not ships.has(value.get("enemy_id")): return {}
		if not _integer(value.get("modifier"), 0, 5): return {}
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
	var players: Dictionary = _catalog(Ships.PLAYERS)
	var enemies: Dictionary = _catalog(Ships.ENEMIES + configuration.enemy_ships + [configuration.progression.mandatory_boss_profile()])
	var pois: Dictionary = _catalog(configuration.pois + [configuration.trading_outpost])
	var cards: Dictionary = _catalog(Cards.CARDS)
	if not players.has(data.get("ship_id")): return null
	if not data.get("seed") is String or not data.seed.is_valid_int(): return null
	for key in ["system_name", "last_outcome", "pending_choice", "pending_card"]:
		if not data.get(key) is String or data[key].length() > 65536: return null
	if data.pending_choice not in ["", "card", "upgrade", "replace", "resource", "production"]: return null
	for key in COUNTERS:
		var minimum: int = -2 if key in ["navigation_origin", "travel_destination"] else (-1 if key in ["pending_destination", "chasedown_index", "last_poi_success"] else 0)
		if not _integer(data.get(key), minimum): return null
	if data.hull <= 0 or data.system_number < 1 or data.salvage < 0: return null
	if data.ftl_charge < 0 or data.required_ftl_charge < 1 or int(data.last_poi_success) not in [-1, 0, 1]: return null
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
	state.rules = configuration
	state.player_ship = Ships.PLAYERS.find(players[data.ship_id])
	state.seed_used = int(data.seed)
	for key in COUNTERS: state.set(key, int(data[key]))
	state.system_name = data.system_name
	state.last_outcome = data.last_outcome
	state.pending_choice = data.pending_choice
	state.production_upgrades = data.production_upgrades.duplicate()
	state.pending_bonuses = data.bonuses.duplicate()
	state.pending_penalties = data.penalties.duplicate()
	for values in [state.production_upgrades, state.pending_bonuses, state.pending_penalties]:
		for key in values: values[key] = int(values[key])
	state.encounters = entries
	state.service = service
	for id in data.acquired: state.acquired_cards.append(cards[id])
	for id in data.removed: state.removed_starting_cards[id] = true
	for id in data.upgrades: state.upgraded_cards[id] = cards[id].with_upgrade(int(data.upgrades[id]))
	for id in data.upgraded_this_event: state.upgraded_this_event[id] = true
	for id in data.offers: state.card_offers.append(cards[id])
	state.pending_card = cards.get(data.pending_card)
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


static func _json(text: String) -> Variant:
	var parser := JSON.new()
	return parser.data if parser.parse(text) == OK else null


func _read(candidate: String) -> Dictionary:
	if not FileAccess.file_exists(candidate): return {}
	var file = FileAccess.open(candidate, FileAccess.READ)
	if file == null or file.get_length() > 2000000: return {}
	var envelope: Variant = _json(file.get_as_text())
	if not envelope is Dictionary or envelope.get("schema") != VERSION: return {}
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
			if envelope is Dictionary and _integer(envelope.get("schema"), 0) and envelope.schema != VERSION:
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
