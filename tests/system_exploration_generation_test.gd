extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Profiles = preload("res://scripts/expedition/system_profile.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var seen: Dictionary = {}
	var stations: Dictionary = {}
	var totals: Dictionary = {}
	for seed_value in range(1, 401):
		var state = State.new()
		var replica = State.new()
		state.start(0, Rules, seed_value)
		replica.start(0, Rules, seed_value)
		check(state.encounters == replica.encounters and state.system_profile == replica.system_profile, "Seed reproduces gameplay generation")
		check(state.pressure == 0 and not state.ftl_access, "New system starts unpressured and locked")
		check(state.encounters.size() == 9, "Approximately fifty percent larger: nine encounters")
		seen[state.system_profile] = true
		totals[state.system_profile] = totals.get(state.system_profile, 0) + 1
		if not state.service.is_empty():
			stations[state.system_profile] = stations.get(state.system_profile, 0) + 1
		if state.system_profile == "quiet":
			check(not state.service.is_empty(), "Quiet Frontier guarantees independent outpost")
		var battles: int = 0
		var hazards: int = 0
		var ordinary: int = 0
		var routes: int = 0
		var direct: int = 0
		for index in state.encounters.size():
			var encounter: Dictionary = state.encounters[index]
			if encounter.kind == "battle":
				battles += 1
			elif encounter.poi.hazardous:
				hazards += 1
			else:
				ordinary += 1
			if encounter.get("objective_role", "") == "access":
				routes += 1
				check(not encounter.get("pressure_sensitive", false), "FTL objectives immune to pressure expiry")
				var prereq: int = encounter.get("objective_prerequisite", -1)
				if prereq < 0:
					direct += 1
				else:
					check(prereq < state.encounters.size() and prereq != index, "Valid prerequisite index after shuffle")
					var relay: Dictionary = state.encounters[prereq]
					check(relay.get("objective_role", "") == "prerequisite" and relay.get("objective_prerequisite", -1) < 0, "Exactly one-step non-circular chain")
					check(not relay.get("pressure_sensitive", false), "Prerequisites immune to pressure expiry")
		check(battles >= Rules.minimum_battles and battles <= Rules.maximum_battles and hazards >= Rules.minimum_hazardous and hazards <= Rules.maximum_hazardous and ordinary >= Rules.minimum_ordinary and ordinary <= Rules.maximum_ordinary, "Valid category composition")
		check(routes >= 1 and routes <= 2 and direct >= 1, "One or two access routes with unconditional safe fallback")
	check(seen.size() == 4, "All four profiles generated")
	# Generous deterministic sample bounds catch accidental old station cadence or duplicates.
	for profile_id in ["industrial", "hostile", "ancient"]:
		check(stations.get(profile_id, 0) < totals.get(profile_id, 0) * 0.25, "Non-frontier outposts remain rare")
	print("System generation: %d checks, %d failures; profiles=%s, outposts=%s" % [checks, failures, totals, stations])
	quit(1 if failures else 0)
