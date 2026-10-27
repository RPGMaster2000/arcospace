extends SceneTree
const Save = preload("res://scripts/persistence/expedition_save.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store = Save.new()
	store.path = "user://metagame_save_test.json"
	store.clear_run()
	var state = State.new()
	state.start(0, Rules, 77321)
	state.pressure = 8
	state.navigation.position = [2.0, 0.0, -5.0]
	state.navigation.cooldown_remaining = 6.25
	var data: Dictionary = Save.encode(state)
	check(not data.has("ftl_charge") and not data.has("required_ftl_charge"), "Obsolete charge fields are not serialized")
	var restored: Resource = store.decode(data)
	check(restored != null, "Metagame payload decodes")
	if restored == null:
		quit(1)
		return
	check(JSON.stringify(Save.encode(restored)) == JSON.stringify(data), "Full current payload round trips exactly")
	check(restored.pressure == 8 and restored.system_profile == state.system_profile and not restored.ftl_access, "Pressure, profile and access survive")
	check(restored.navigation.snapshot() == state.navigation.snapshot(), "Position and remaining cooldown survive")
	check(restored.rng.state == state.rng.state and restored.chasedown_rng.state == state.chasedown_rng.state and restored.station_rng.state == state.station_rng.state, "All RNG streams survive without draws")
	var access_index: int = -1
	for index in state.encounters.size():
		if state.encounters[index].get("objective_role", "") == "access" and state.encounters[index].get("objective_prerequisite", -1) == -1:
			access_index = index
	check(access_index >= 0, "Generated route exists")
	state._complete_encounter(access_index)
	var earned_pressure: int = state.pressure
	restored = store.decode(Save.encode(state))
	check(restored != null and restored.ftl_access and restored.encounters[access_index].completed, "Objective completion and access persist")
	if restored != null:
		check(not restored._complete_encounter(access_index) and restored.pressure == earned_pressure, "Reload cannot replay completed encounter pressure")
	# Free travel and stopped free positions use the same navigation codec as PoI travel.
	state.travel_destination = -3
	state.navigation.leg_active = true
	state.navigation.rolled_this_leg = true
	state.navigation.target = [6.0, 0.0, 3.0]
	restored = store.decode(Save.encode(state))
	check(restored != null and restored.travel_destination == -3 and restored.navigation.target == state.navigation.target, "Pending free journey survives")
	state.travel_destination = -1
	state.navigation.stop()
	state.navigation_origin = -3
	restored = store.decode(Save.encode(state))
	check(restored != null and restored.navigation.position == state.navigation.position, "Stopped free position survives")
	# Generate historic payloads by removing only the newly introduced metadata.
	var legacy: Dictionary = data.duplicate(true)
	for field in ["metagame_version", "pressure", "system_profile", "ftl_access", "navigation"]:
		legacy.erase(field)
	legacy.ftl_charge = 1
	legacy.required_ftl_charge = 5
	for entry in legacy.encounters:
		for field in ["objective_role", "objective_prerequisite", "objective_known", "pressure_tolerance", "pressure_sensitive"]:
			entry.erase(field)
		entry.completed = true
		entry.charge_awarded = true
	var old_count: int = legacy.encounters.size()
	var old_rng: Dictionary = legacy.rng.duplicate(true)
	restored = store.decode(legacy)
	check(restored != null, "Legacy exhausted system migrates")
	if restored != null:
		check(restored.pressure == old_count and restored.system_profile == "industrial", "Legacy pressure and profile use documented deterministic fallback")
		check(restored.encounters.size() == old_count + 1 and not restored.ftl_access, "Unready legacy run receives one additional safe access route")
		check(restored.encounters.back().poi.approaches[0].salvage_cost == 0 and restored.encounters.back().poi.approaches[0].success_chance == 1.0, "Migration route is free and deterministic")
		check(restored.navigation.cooldown_remaining == 10.0, "Legacy cooldown begins conservatively")
		check(Save.encode(restored).rng == old_rng and restored.salvage == int(legacy.salvage), "Migration preserves exact RNG and currency")
		var last: int = restored.encounters.size() - 1
		check(restored.resolve_approach(last, 0) and restored.ftl_access and restored.can_jump(), "Exhausted historic roster cannot softlock progression")
		check(restored.salvage == int(legacy.salvage), "Migration route does not duplicate rewards")
	legacy.ftl_charge = 5
	restored = store.decode(legacy)
	check(restored != null and restored.ftl_access and restored.encounters.size() == old_count, "Historically ready run retains access without extra encounter")
	legacy.ftl_charge = 1
	check(store.save_data(legacy), "Legacy disk checkpoint remains writable")
	var loaded: Dictionary = store.load_run()
	check(not loaded.is_empty() and not store.warning.is_empty(), "Disk migration is disclosed to player")
	# Explicit schema and relationship validation rejects corrupt data before replacing a save.
	var bad: Dictionary = data.duplicate(true)
	bad.metagame_version = 99
	check(store.decode(bad) == null, "Unknown metagame version rejects safely")
	bad = data.duplicate(true); bad.pressure = -1
	check(store.decode(bad) == null, "Negative pressure rejects")
	bad = data.duplicate(true); bad.system_profile = "missing"
	check(store.decode(bad) == null, "Unknown profile rejects")
	bad = data.duplicate(true); bad.navigation.cooldown_remaining = 10.1
	check(store.decode(bad) == null, "Cooldown outside authoritative bounds rejects")
	bad = data.duplicate(true); bad.navigation.position = [0, "bad", 0]
	check(store.decode(bad) == null, "Malformed free position rejects")
	bad = data.duplicate(true); bad.travel_destination = -3
	check(store.decode(bad) == null, "Destination cannot exist outside an active journey")
	bad = data.duplicate(true); bad.navigation.leg_active = true
	check(store.decode(bad) == null, "Active journey must have a destination")
	bad = data.duplicate(true); bad.encounters[access_index].objective_prerequisite = bad.encounters.size()
	check(store.decode(bad) == null, "Missing prerequisite rejects")
	bad = data.duplicate(true); bad.encounters[access_index].objective_prerequisite = access_index
	check(store.decode(bad) == null, "Circular objective rejects")
	bad = data.duplicate(true); bad.encounters[access_index].pressure_sensitive = true
	check(store.decode(bad) == null, "Progression objectives cannot expire under pressure")
	bad = data.duplicate(true); bad.encounters[access_index].poi_id = "res://scripts/board.gd"
	check(store.decode(bad) == null, "Save cannot load arbitrary resource paths")
	store.clear_run()
	print("Metagame save: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
