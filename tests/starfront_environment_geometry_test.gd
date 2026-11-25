extends SceneTree
## Compare the same seeds with legacy and later geometry using the real generator.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Variation = State.SystemVariation
const Layout = State.SystemLayout
const Routes = preload("res://scripts/expedition/route_environments.gd")
const Placement = preload("res://scripts/expedition/varied_system_layout.gd")
const Clearance = preload("res://scripts/expedition/environment_clearance.gd")
const FLEET = preload("res://scripts/expedition/defense_warfare.gd")

var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures <= 20: push_error(label)


func launch(rules: Resource, stage: int, seed_value: int, options: Dictionary = {}) -> Resource:
	var state := State.new()
	state.start(seed_value % 6, rules, seed_value, {"mode":"defense","stage":stage,"rank":-1}.merged(options, true))
	return state


func mean(values: Array) -> float:
	return float(values.reduce(func(sum, number): return sum + number, 0.0)) / maxi(1, values.size())


func measure(state: Resource, stats: Dictionary) -> void:
	var fleet: RefCounted = state.defense
	var profile: Dictionary = state.system_variation
	var width := Layout.bounds(state.layout_expansion).size.x
	var anchors: Array = fleet.anchors.values()
	var sizes := Layout.planetary_radii(state.encounters, profile.get("planet_scales", {}))
	var orbits: Array = sizes.keys().map(func(i): return fleet.anchors[i].length())
	orbits.sort()
	var separations: Array = []
	var nearest: Array = []
	var center := Vector3.ZERO
	for index in anchors.size():
		var at: Vector3 = anchors[index]
		center += at.normalized()
		var neighbors: Array = []
		for j in anchors.size():
			if index == j: continue
			var distance: float = at.distance_to(anchors[j])
			neighbors.append(distance)
			if j > index: separations.append(distance)
		nearest.append(neighbors.min())
	var preparation: Array = []
	for index in fleet.anchors:
		if index < 0 or state.encounters[index].poi.resource_path.get_file().get_basename() in Placement.PREPARATION:
			preparation.append(fleet.anchors[index].distance_to(fleet.start) * fleet.tuning.seconds_per_distance)
	var arrival: Array = []
	for unit in fleet.units:
		if not unit.reinforcement and not unit.mothership:
			arrival.append(unit.position.distance_to(fleet.home) / fleet._speed(unit))
	arrival.sort()
	var storms: Array = state.environmental_instances.filter(func(item): return item.type == "SPACE_STORM")
	var coverage := 0
	for x in range(-4, 5):
		for z in range(-4, 5):
			var at := [float(x) * width / 9, 0.0, float(z) * width / 9]
			if storms.any(func(item): return State.EnvironmentData.Storms.contains(item, at)): coverage += 1
	var row := {"n":1, "width":width, "area":width * width, "home":fleet.home.length(), "pois":anchors.size() - int(fleet.anchors.has(State.SERVICE_INDEX)),
		"pair":mean(separations), "nearest":mean(nearest), "direction":center.length() / anchors.size(),
		"planets":sizes.size(), "ring_gap":mean(range(1, orbits.size()).map(func(i): return orbits[i] - orbits[i - 1])),
		"travel":mean(anchors.map(func(at): return at.distance_to(fleet.start))),
		"prep":preparation.min() if not preparation.is_empty() else 0.0, "arrival":arrival[0], "gap":arrival[1] - arrival[0],
		"binary":int(not profile.companion.is_empty()), "star":Variation.star_radius(profile, 2.52),
		"storms":storms.size(), "storm_coverage":100.0 * coverage / 81.0, "retries":profile.get("placement_attempt", 0),
		"military_fallback":int(profile.get("military_fallback", false))}
	for key in row:
		stats[key] = stats.get(key, 0) + row[key]


func geometry(state: Resource, old: Resource) -> void:
	var data: Dictionary = state.system_variation
	var fleet: RefCounted = state.defense
	var identifier := "%d/%d" % [state.system_number, state.seed_used]
	check(state.faction_id == old.faction_id and state.rng.state == old.rng.state,
		"Geography preserves faction and gameplay stream " + identifier)
	if data.version != 2: return
	check(Variation.valid(data), "Valid current profile " + identifier)
	check(Layout.valid_expansion(state.layout_expansion, true), "Bounded dimensions " + identifier)
	check(is_equal_approx(fleet.home.length(), 22 * state.layout_expansion * data.home_scale)
		and fleet.start.is_equal_approx(fleet.home * 0.78), "Homeworld and player placement " + identifier)
	var prep := false
	for index in fleet.anchors:
		var at: Vector3 = fleet.anchors[index]
		check(Layout.navigable(at, state.layout_expansion, 1.999), "Anchor inside bounds " + identifier)
		if index >= 0 and state.encounters[index].poi.resource_path.get_file().get_basename() not in Placement.PREPARATION:
			continue
		if at.distance_to(fleet.start) * fleet.tuning.seconds_per_distance > 3: continue
		if state.environmental_instances.any(func(item): return Routes.intersects(item, fleet.start, at)): continue
		prep = true
	check(prep, "Clean nearby preparation route " + identifier)
	var opening: Array = fleet.units.filter(func(unit): return not unit.mothership and not unit.reinforcement)
	var starts: Array[Vector3] = []
	var arrivals: Array = []
	for unit in opening:
		var at: Vector3 = unit.position
		arrivals.append(at.distance_to(fleet.home) / fleet._speed(unit))
		starts.append(at)
		check(Geometry3D.get_closest_point_to_segment(Vector3.ZERO, at, fleet.home).length() >= fleet.stellar_clearance(),
			"Hostile route clears stellar envelope " + identifier)
	arrivals.sort()
	check(arrivals[0] >= data.minimum_arrival - 0.0001 and arrivals[1] - arrivals[0] >= 0.7999,
		"Opening deadlines use actual speed and geometry " + identifier)
	check(FLEET._intercept_opening(fleet, opening, starts), "Two swept interceptions " + identifier)
	for unit in fleet.units:
		if unit.reinforcement:
			check(fleet.spawn_position(fleet.start, unit) != null, "Reserve entry feasible " + identifier)
	for item in state.environmental_instances:
		check(not Clearance.intersects_sphere(item, fleet.start, 0.25), "Safe start " + identifier)
	var encoded := Save.encode(state)
	var restored: Resource = Save.new().decode(Variation.canonical(encoded), state.rules)
	check(restored != null and JSON.stringify(Save.encode(restored)) == JSON.stringify(encoded),
		"Exact current geometry save roundtrip " + identifier)


func _initialize() -> void:
	var current := Rules.duplicate()
	current.log_rolls = false
	var baseline := current.duplicate()
	baseline.system_variety = current.system_variety.duplicate()
	baseline.system_variety.progressive_geometry = false
	var current_stats := {}
	var baseline_stats := {}
	var by_class := {}
	var by_stage := {}
	var matched_formations := 0
	var fallbacks := 0
	for stage in [3, 4, 5]:
		var stage_stats := {}
		for seed_value in range(1, 361):
			var state := launch(current, stage, seed_value)
			var old := launch(baseline, stage, seed_value)
			var a: String = state.system_variation.archetype
			var b: String = old.system_variation.archetype
			if not current_stats.has(a): current_stats[a] = {}
			if not baseline_stats.has(b): baseline_stats[b] = {}
			if not stage_stats.has(a): stage_stats[a] = 0
			stage_stats[a] += 1
			matched_formations += int(state.defense.military.get("formation") == old.defense.military.get("formation"))
			measure(state, current_stats[a])
			measure(old, baseline_stats[b])
			geometry(state, old)
			if state.system_variation.version == 2:
				var size_class: String = Variation.SIZE_CLASSES[int(state.system_variation.size_class)]
				if not by_class.has(size_class): by_class[size_class] = {}
				measure(state, by_class[size_class])
			else:
				fallbacks += 1
		by_stage[stage] = stage_stats
	check(fallbacks <= 12, "Only exceptional geometry falls back")
	check(current_stats.size() == Variation.ARCHETYPES.size(), "All archetypes generated")
	check(current_stats.scattered.pair / current_stats.scattered.n > current_stats.crowded.pair / current_stats.crowded.n * 1.20,
		"Scattered infrastructure is farther apart")
	check(current_stats.asymmetric.direction / current_stats.asymmetric.n > current_stats.conventional.direction / current_stats.conventional.n * 1.30,
		"Asymmetric infrastructure is concentrated on one side")
	check(by_class.Expansive.travel / by_class.Expansive.n > by_class.Compact.travel / by_class.Compact.n * 1.12,
		"Expansive maps increase actual travel distance")
	check(current_stats.storm_dominated.storm_coverage / current_stats.storm_dominated.n > current_stats.conventional.storm_coverage / current_stats.conventional.n * 1.35,
		"Storm-dominated geography exposes more space to storms")
	var forced := launch(current, 5, 214, {"seed":"214", "environment":"asymmetric", "size_class":"Expansive", "home_region":"Outer Frontier", "binary":1})
	var again := launch(current, 5, 214, {"seed":"214", "environment":"asymmetric", "size_class":"Expansive", "home_region":"Outer Frontier", "binary":1})
	check(forced.system_variation.archetype == "asymmetric" and forced.system_variation.size_class == 2
		and forced.system_variation.home_region == 2 and not forced.system_variation.companion.is_empty(),
		"Developer settings use the production geometry")
	check(JSON.stringify(Save.encode(forced)) == JSON.stringify(Save.encode(again)), "Selected seed reproduces the same sector")
	var prior: String = forced.system_variation.archetype
	forced.defense.complete = true
	check(forced.generate_system() and forced.system_variation.archetype != prior, "Consecutive defense environments differ")
	for stage in [1, 2]:
		var flags := {"mode":"defense" if stage == 1 else "warzone"}
		check(JSON.stringify(Save.encode(launch(current, stage, 41, flags))) == JSON.stringify(Save.encode(launch(baseline, stage, 41, flags))),
			"Earlier operation is byte-equivalent")
	print("GEOMETRY_AUDIT ", JSON.stringify({"later":current_stats, "legacy":baseline_stats, "classes":by_class,
		"stages":by_stage, "fallbacks":fallbacks, "matched_formations":matched_formations}))
	print("Starfront environment: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
