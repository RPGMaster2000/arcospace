extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Warfare = preload("res://scripts/expedition/defense_warfare.gd")
const Details = preload("res://scripts/ui/system_details.gd")
const Result = preload("res://scripts/combat/battle_result.gd")

var checks := 0
var failures := 0


func check(condition: bool, title: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	if failures < 26: push_error(title)


func launch(stage: int, seed_value: int, formation: String = "", faction: String = "", enabled: bool = true, mode: String = "defense") -> Resource:
	var rules := Rules.duplicate()
	rules.defense_tuning = Rules.defense_tuning.duplicate()
	rules.defense_tuning.procedural_warfare = enabled
	rules.log_rolls = false
	var state := State.new()
	state.start(0, rules, seed_value, {"mode":mode, "stage":stage, "rank":-1, "formation":formation, "faction":faction})
	return state


func deployment_sweep() -> void:
	var distributions := {}
	for stage in [3, 4, 5]:
		var stats := {"formations":{}, "roles":{}, "factions":{}, "elites":0, "ships":0,
			"earliest":INF, "shortest_gap":INF, "fastest_response":INF, "slowest_response":0.0,
			"nearby_preparation":0}
		for seed_value in range(1, 181):
			var state := launch(stage, seed_value)
			var fleet: RefCounted = state.defense
			var data: Dictionary = fleet.military
			check(Warfare.valid_plan(data, stage), "Valid military scenario %s/%s" % [stage, seed_value])
			if data.is_empty(): continue
			increment(stats.formations, data.formation)
			increment(stats.factions, state.faction_id)
			check(fleet.active_attackers() == data.opening and fleet.units.size() == data.opening + data.reserves + 1,
				"Opening, reserve and mothership counts")
			check(is_equal_approx(fleet.pressure_rate(), fleet.tuning.pressure_per_second * fleet.tuning.pressure_rate_multiplier * data.pressure),
				"Escalation applies to the effective v2 pressure once")
			var bounds := State.SystemLayout.bounds(state.layout_expansion)
			var elites := 0
			var opening_elites := 0
			var arrivals: Array[float] = []
			var contacts: Array[float] = []
			var positions: Array[Vector3] = []
			var opening: Array = []
			for unit in fleet.units:
				var metadata: Dictionary = fleet.deployment(unit)
				var base: Resource = fleet.ship_profile(unit)
				check(Warfare.valid_deployment(metadata, base), "Valid detached enemy settings")
				if unit.mothership: continue
				stats.ships += 1
				increment(stats.roles, metadata.role)
				elites += int(base.enemy_rank == 1)
				opening_elites += int(base.enemy_rank == 1 and not unit.reinforcement)
				var point: Vector3 = unit.position
				check(bounds.has_point(Vector2(point.x, point.z)) and point.distance_to(fleet.start) >= 7.0,
					"Deployment obeys navigation and entry clearance")
				check(Geometry3D.get_closest_point_to_segment(Vector3.ZERO, point, fleet.home).length() >= 3.5,
					"Course clears stellar core")
				check(fleet.arrival_damage(unit) == (25 if metadata.role == "siege" else 20), "Only siege has extra arrival damage")
				check(is_equal_approx(fleet._speed(unit), fleet.tuning.enemy_speed * data.speed * Warfare.ROLES[metadata.role][1]),
					"System and role modifiers compose once")
				if unit.reinforcement:
					check(fleet.spawn_position(fleet.start, unit) != null, "Planned reserve has a feasible entrance")
				else:
					opening.append(unit)
					positions.append(point)
					var speed: float = fleet._speed(unit)
					var arrival: float = point.distance_to(fleet.home) / speed
					arrivals.append(arrival)
					var response: float = fleet.start.distance_to(fleet.intercept_point(unit.encounter, fleet.start)) * fleet.tuning.seconds_per_distance
					contacts.append(response)
					check(arrival > response + fleet.tuning.battle_seconds, "Player can intercept before the arrival deadline")
			arrivals.sort()
			stats.elites += elites
			stats.earliest = minf(stats.earliest, arrivals.front())
			stats.shortest_gap = minf(stats.shortest_gap, arrivals[1] - arrivals[0])
			stats.fastest_response = minf(stats.fastest_response, contacts.min())
			stats.slowest_response = maxf(stats.slowest_response, contacts.min())
			check(elites <= stage - 1 and opening_elites <= mini(2, stage - 2), "Bounded elite concentration")
			check(Warfare._intercept_opening(fleet, opening, positions), "Two swept contacts fit before initial damage")
			var preparation: Array = Warfare.preparation_sites(state, fleet.anchors.keys())
			if preparation.any(func(index): return fleet.anchors[index].distance_to(fleet.start) * fleet.tuning.seconds_per_distance < 3.0):
				stats.nearby_preparation += 1
			if seed_value <= 8:
				var twin := launch(stage, seed_value)
				check(JSON.stringify(Save.encode(state)) == JSON.stringify(Save.encode(twin)), "Same seed reproduces complete system")
		distributions[stage] = stats
		check(stats.formations.size() == (3 if stage == 3 else 5) and stats.factions.size() == 4, "Stage has full scenario and faction variety")
	print("STARFRONT_GENERATION " + JSON.stringify(distributions))


func increment(rows: Dictionary, key: String) -> void:
	rows[key] = rows.get(key, 0) + 1


func compatibility() -> void:
	for mode in ["defense", "warzone"]:
		for seed_value in [8, 41, 91]:
			var stage := 1 if mode == "defense" else 2
			var on := launch(stage, seed_value, "", "", true, mode)
			var off := launch(stage, seed_value, "", "", false, mode)
			check(JSON.stringify(Save.encode(on)) == JSON.stringify(Save.encode(off)), "System %d exact new-feature parity" % stage)
	for formation in Warfare.FORMATIONS:
		var state := launch(5, 214, formation, "axiom_collective")
		check(state.defense.military.get("formation") == formation and state.faction_id == "axiom_collective",
			"Developer override uses authoritative generation")
		check(Details.text(state).contains(Warfare.describe(formation)), "System details displays the generated scenario")
	var state := launch(4, 94)
	var prior: String = state.defense.military.formation
	state.defense.complete = true
	check(state.generate_system() and state.defense.military.formation != prior, "Consecutive Starfront systems vary")
	var old := launch(5, 17, "", "", false)
	var legacy := restore(old)
	check(legacy != null and legacy.defense.military.is_empty(), "Legacy active systems keep their original behavior")


func restore(state: Resource) -> Resource:
	return Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))), state.rules)


func restoration() -> void:
	var state := launch(5, 204, "spearhead", "iron_directorate")
	var fleet: RefCounted = state.defense
	var initial: Array = fleet.units.filter(func(unit): return not unit.mothership and not unit.reinforcement)
	for unit in initial:
		fleet.neutralize(unit.encounter)
		state.encounters[unit.encounter].completed = true
	var first_wave: float = fleet.reinforcement_remaining
	fleet.advance_time(first_wave - 0.4, fleet.start, fleet.start, true)
	var loaded := restore(state)
	check(loaded != null, "Save resumes before a scheduled reinforcement")
	if loaded == null: return
	fleet.advance_time(0.8, fleet.start, fleet.start, true)
	loaded.defense.advance_time(0.8, fleet.start, fleet.start, true)
	check(fleet.reinforcements_spawned == 1 and JSON.stringify(fleet.snapshot()) == JSON.stringify(loaded.defense.snapshot()),
		"Restored scheduler dispatches the same reserve once")
	var reinforcement: Dictionary = fleet.units.filter(func(unit): return unit.spawned).front()
	var idx: int = reinforcement.encounter
	var active: int = fleet.active_attackers()
	fleet.contact = idx
	loaded = restore(state)
	check(loaded != null and loaded.defense.contact == idx and loaded.defense.active_attackers() == active,
		"Specialized contact survives save")
	if loaded == null: return
	var setup: RefCounted = state.prepare_battle(idx)
	var resumed: RefCounted = loaded.prepare_battle(idx)
	check(setup.enemy_state.snapshot() == resumed.enemy_state.snapshot()
		and setup.enemy_cards == resumed.enemy_cards and setup.enemy_draw_rates == resumed.enemy_draw_rates,
		"Combat profile, pool and rarity resume without applying bonuses twice")
	check(setup.enemy_profile != state.encounters[idx].enemy_data
		and setup.enemy_state.hull_capacity == state.rules.progression.scaled_enemy(state.encounters[idx].enemy_data,5,true).hull_capacity,
		"Detached battle profile keeps normal Hull scaling")
	var report := Result.new()
	report.result_id = 9872
	report.encounter_index = idx
	report.system_number = 5
	report.winner = "player"
	report.player_hull = state.hull
	report.salvage = state.salvage
	report.battles_won = 1
	check(state.record_battle(report) and not state.record_battle(report), "Specialized combat uses the ordinary once-only result path")
	state.pending_choice = ""
	fleet.pressure = fleet.tuning.pressure_maximum - 1
	fleet.revealed = true
	fleet.advance_time(2.0, fleet.start, fleet.start, true)
	loaded = restore(state)
	check(fleet.mothership_advancing and loaded != null and loaded.defense.mothership_advancing,
		"Advancing mothership survives a save")
	fleet.missiles.countdown = 0.0
	fleet.advance_time(0.1, fleet.start, fleet.start, true)
	var missiles: Array = fleet.missiles.active.keys()
	var boss: int = fleet.mothership_index()
	var deployed: Array = fleet.units.filter(func(unit): return unit.status == "active" and not unit.mothership)
	fleet.neutralize(boss)
	check(fleet.units.all(func(unit): return unit.status != "reserve"),
		"Mothership defeat stands down undeployed reserves")
	check(not missiles.is_empty() and fleet.missiles.active.keys() == missiles
		and deployed.all(func(unit): return unit.status == "active") and not fleet.complete,
		"Mothership defeat preserves live missiles and deployed threats until they resolve")


func _initialize() -> void:
	compatibility()
	restoration()
	deployment_sweep()
	print("Starfront warfare: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
