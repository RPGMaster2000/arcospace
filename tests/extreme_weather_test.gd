extends SceneTree
## PR #125 and the new scheduler use the same seeds and authoritative time.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Routes = preload("res://scripts/expedition/route_environments.gd")
const E = State.EnvironmentData
const Rifts = State.TemporalRift
const Variation = State.SystemVariation
const GRID := 36
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	if failures <= 24: push_error(message)


func launch(rules: Resource, stage: int, seed_value: int, env: String = "", mode: String = "defense") -> Resource:
	var state := State.new()
	state.start(seed_value % 6, rules, seed_value, {"mode":mode, "stage":stage, "rank":-1, "environment":env})
	return state


func storms(state: Resource) -> Array:
	return state.environmental_instances.filter(func(item): return item.type == E.SPACE_STORM)


func coverage(state: Resource, fronts: Array) -> Vector2:
	# The plane samples the exact saved oriented ellipses. Precompute inverse
	# transforms so dense measurement does not run the wire validator per pixel.
	var shapes: Array = []
	for item in fronts:
		var angle: float = item.region.get("angle", 0.0)
		shapes.append([Vector2(item.position[0], item.position[2]),
			Vector2(item.region.axes[0], item.region.axes[2]), angle])
	var total := Vector2.ZERO
	var bounds := State.SystemLayout.bounds(state.layout_expansion)
	for i in GRID:
		for j in GRID:
			var point := bounds.position + Vector2(i + 0.5, j + 0.5) * bounds.size / GRID
			var layers := 0
			for shape in shapes:
				if ((point - shape[0]).rotated(shape[2]) / shape[1]).length_squared() <= 1.0: layers += 1
			total.x += int(layers > 0)
			total.y += int(layers > 1)
	return total / float(GRID * GRID)


func age_opening(state: Resource) -> Vector3:
	var start: Vector3 = state.defense.start
	var peak := 0
	var overlap := 0
	var rift_seconds := 0
	for second in 22:
		if state.defense.failed(): break
		state._advance_strategy(1.0, start, start, true, false)
		var live := Rifts.active_all(state.environmental_instances)
		peak = maxi(peak, live.size())
		rift_seconds += live.size()
		if live.size() > 1: overlap += 1
	return Vector3(peak, overlap, rift_seconds)


func accumulate(rows: Dictionary, key: String, data: Dictionary) -> void:
	if not rows.has(key): rows[key] = {}
	var row: Dictionary = rows[key]
	for stat in data:
		row[stat] = row.get(stat, 0.0) + data[stat]


func measure(state: Resource) -> Dictionary:
	var fronts := storms(state)
	var area := coverage(state, fronts)
	var fleet: RefCounted = state.defense
	var hits := 0
	var lanes := 0
	var fastest := INF
	for unit in fleet.units:
		if unit.mothership or unit.reinforcement: continue
		lanes += 1
		fastest = minf(fastest, unit.position.distance_to(fleet.home) / fleet._speed(unit))
		var at: Vector3 = fleet.intercept_point(unit.encounter, fleet.start)
		if fronts.any(func(item): return Routes.intersects(item, fleet.start, at)): hits += 1
	var solar: Array = state.environmental_instances.filter(func(item): return item.type == E.SOLAR_INTERFERENCE)
	var rift := age_opening(state)
	return {"n":1, "storms":fronts.size(), "requested":state.system_variation.get("weather", {}).get("storms", 0),
		"coverage":area.x, "overlap":area.y, "affected":float(hits) / lanes, "arrival":fastest,
		"rift_peak":rift.x, "rift_concurrent":int(rift.y > 0), "rift_seconds":rift.z,
		"solar":int(not solar.is_empty()), "solar_radius":0.0 if solar.is_empty() else solar.front().region.radius}


func compare(current: Resource, old: Resource) -> void:
	var records := {}
	var previous := {}
	var fallback := 0
	for stage in [3, 4, 5]:
		for seed_value in range(1, 181):
			var later := launch(current, stage, seed_value)
			var before := launch(old, stage, seed_value)
			var profile: Dictionary = later.system_variation
			var ext: Dictionary = profile.get("weather", {})
			var label := "%s/%s" % [stage, seed_value]
			check(later.defense.snapshot() == before.defense.snapshot() and later.rng.state == before.rng.state,
				"Weather leaves deployment, schedules and unrelated RNG intact " + label)
			if profile.version == 1: fallback += 1
			if not ext.is_empty():
				check(storms(later).size() == ext.storms, "Every planned front is placed " + label)
				var encoded := Variation.canonical(Save.encode(later))
				var loaded: Resource = Save.new().decode(encoded, current)
				check(loaded != null and Save.encode(loaded).environmental_instances == encoded.environmental_instances,
					"Front geometry roundtrips " + label)
			else:
				check(later.environmental_instances == before.environmental_instances, "Other archetypes retain PR #125 activity " + label)
			accumulate(records, profile.archetype, measure(later))
			accumulate(previous, profile.archetype, measure(before))
			check(Rifts.active_all(later.environmental_instances).size() <= later.rifts.capacity(), "Rift cap in live simulation " + label)
	for key in ["unstable", "storm_dominated", "chaotic"]:
		var row: Dictionary = records[key]
		var minimum: float = {"unstable":0.15, "storm_dominated":0.40, "chaotic":0.30}[key]
		check(row.coverage / row.n >= minimum, "Physical coverage target achieved for " + key)
		check(row.storms / row.n >= {"unstable":2.0, "storm_dominated":5.0, "chaotic":3.0}[key], "Extreme storm population " + key)
		check(row.rift_concurrent > row.n / 5, "Multiple live rifts occur regularly in opening " + key)
	check(records.size() == Variation.ARCHETYPES.size(), "Measure all environment archetypes")
	print("EXTREME_WEATHER ", JSON.stringify({"previous":previous, "current":records, "fallbacks":fallback}))


func timing(current: Resource) -> void:
	var large := launch(current, 5, 214, "unstable")
	var split := launch(current, 5, 214, "unstable")
	var start: Vector3 = large.defense.start
	large._advance_strategy(18.75, start, start, true, false)
	for step in 150:
		split._advance_strategy(0.125, start, start, true, false)
	var active := Rifts.active_all(large.environmental_instances)
	check(active.size() > 1, "Fixture produces multiple rifts")
	check(large.rifts.snapshot() == split.rifts.snapshot()
		and large.environmental_instances == split.environmental_instances,
		"Weather is deterministic across strategic-time partitions")
	var encoded := Variation.canonical(Save.encode(large))
	var loaded: Resource = Save.new().decode(encoded, current)
	check(loaded != null and Rifts.active_all(loaded.environmental_instances) == active, "Each live lifetime, ID and shape persists")
	var schedule: Dictionary = large.rifts.snapshot()
	for i in 4: await process_frame
	check(schedule == large.rifts.snapshot() and active == Rifts.active_all(large.environmental_instances),
		"Real idle time does not advance or expire rifts")
	if active.is_empty(): return
	var duplicate := encoded.duplicate(true)
	duplicate.environmental_instances.append(active.front().duplicate(true))
	check(Save.new().decode(duplicate, current) == null, "Duplicate live IDs are rejected")
	duplicate = encoded.duplicate(true)
	duplicate.temporal_rift_schedule.evaluation = 0
	check(Save.new().decode(duplicate, current) == null, "Every live rift must match the saved event schedule")


func modifier_resolution(current: Resource) -> void:
	var state := launch(current, 5, 214, "chaotic")
	var at := Vector2(20, 8)
	var spot := [at.x, 0.0, at.y]
	var ion := E.Storms.front(state.seed_used, 5, 0, at, Vector2(15, 10), 0.0, "ion", 0.90, 0.0)
	var metal := E.Storms.front(state.seed_used, 5, 1, at, Vector2(12, 12), 0.0, "metal", 0.82, 0.0)
	var rift := E.instance("rift-5-1", E.TEMPORAL_RIFT, spot)
	rift.region = {"shape":"sphere", "radius":2.95}
	rift.generation = {"front":true,"evaluation":1,"encounter":0}
	rift.visual = {"seed":"4242"}
	rift.simulation = {"remaining":20.0}
	var second := rift.duplicate(true)
	second.id = "rift-5-2"
	var snapshot := E.evaluate(state, spot, [metal, ion, second, rift], 0)
	check(E.modifier_id(snapshot) == 2 and E.temporal_draw(snapshot) and snapshot.temporal_anomaly.id == rift.id,
		"One strongest timed hazard and one passive anomaly resolve overlapping instances")
	check(E.valid_snapshot(snapshot) and snapshot == E.evaluate(state, spot, [rift, second, ion, metal], 0),
		"Overlap is order-independent and freezes valid geometry")
	var original: Dictionary = snapshot.duplicate(true)
	rift.region.radius = 2.0
	check(snapshot == original, "Changing live geometry does not affect a battle checkpoint")
	var explicit := E.evaluate(state, spot, [ion, rift], 0, 3)
	check(E.modifier_id(explicit) == 3 and not E.temporal_draw(explicit), "Legacy explicit battle modifier keeps precedence")
	var board := preload("res://scenes/board_3d.tscn").instantiate()
	var setup := preload("res://scripts/combat/battle_setup.gd").new()
	setup.modifier = 2
	setup.environment = snapshot
	preload("res://scripts/combat/battle_adapter.gd").configure(board, setup)
	root.add_child(board)
	check(board.modifier.kind == 2 and board.hand.drop_multiplier == 2.0 and board.enemy_hand.drop_multiplier == 2.0,
		"Live board applies the storm and one draw boost to both hands")
	board.free()


func run() -> void:
	var current := Rules.duplicate()
	current.log_rolls = false
	var old := current.duplicate()
	old.system_variety = current.system_variety.duplicate()
	old.system_variety.extreme_weather = false
	for stage in [1, 2]:
		var mode := "defense" if stage == 1 else "warzone"
		check(Save.encode(launch(current, stage, 8, "", mode)) == Save.encode(launch(old, stage, 8, "", mode)),
			"Opening Defense and Warzone remain unchanged")
	var prior := launch(old, 5, 214, "chaotic")
	var original := Save.encode(prior)
	var loaded: Resource = Save.new().decode(Variation.canonical(original), current)
	check(loaded != null and JSON.stringify(Save.encode(loaded)) == JSON.stringify(original) and loaded.rifts.capacity() == 1, "An active PR #125 save keeps its old scheduler and storms")
	await timing(current)
	modifier_resolution(current)
	compare(current, old)
	print("Extreme weather: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
