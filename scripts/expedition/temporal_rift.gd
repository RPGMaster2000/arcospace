extends RefCounted
## The defense simulation supplies only the time spans it actually consumes.
## This observer can project positions within a span without resampling fleet motion.
const TYPE = "TEMPORAL_RIFT"
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const Solar = preload("res://scripts/expedition/solar_regions.gd")
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const Storms = preload("res://scripts/expedition/storm_regions.gd")
const MAP_SETTINGS = preload("res://resources/presentation/star_system_settings.tres")
const Layout = preload("res://scripts/expedition/system_layout.gd")
const RADIUS = 2.35
const EPSILON = 0.00000001

var rng := RandomNumberGenerator.new()
var system_number: int
var remaining: float
var evaluation: int = 0


func reset(run_seed: int, system: int, initial_delay: float) -> void:
	system_number = system
	rng.seed = hash("%d:%d:temporal-rift:v1" % [run_seed, system])
	remaining = initial_delay
	evaluation = 0


func snapshot() -> Dictionary:
	return {"version": 1, "remaining": remaining, "evaluation": evaluation, "rng_state": str(rng.state)}


func restore(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != 1: return false
	if not _number(data.get("remaining"), 0.0, 120.0): return false
	if not _integer(data.get("evaluation"), 0, 2147483647): return false
	if not data.get("rng_state") is String or not data.rng_state.is_valid_int(): return false
	remaining = float(data.remaining)
	evaluation = int(data.evaluation)
	rng.state = int(data.rng_state)
	return true


func valid_active(item: Dictionary, defense: RefCounted) -> bool:
	if item.is_empty(): return true
	var event := int(item.generation.evaluation)
	var at: Array = item.position
	return event <= evaluation and item.id == _id(event) \
		and not defense.unit_for(int(item.generation.encounter)).is_empty() \
		and Layout.bounds(defense.layout_expansion, MAP_SETTINGS.system_bounds).grow(-float(item.region.radius)).has_point(Vector2(at[0], at[2]))


func advance_span(seconds: float, defense: RefCounted, instances: Array) -> void:
	if seconds <= 0.0: return
	var offset := 0.0
	var live := active(instances)
	while remaining <= seconds - offset + EPSILON:
		var span := minf(remaining, seconds - offset)
		live = _age(live, span, instances)
		offset += span
		remaining = maxf(0.1, defense.tuning.rift_evaluation_interval)
		evaluation += 1
		# Consume one roll per scheduled evaluation, even when occupied.
		var roll := rng.randf()
		if live.is_empty() and roll < defense.tuning.rift_spawn_chance:
			live = _spawn(defense, instances, offset)
			if not live.is_empty(): instances.append(live)
	var tail := seconds - offset
	_age(live, tail, instances)
	remaining -= tail


func _age(live: Dictionary, seconds: float, instances: Array) -> Dictionary:
	if live.is_empty(): return live
	live.simulation.remaining = float(live.simulation.remaining) - seconds
	if live.simulation.remaining > EPSILON: return live
	instances.erase(live)
	return {}


func _spawn(defense: RefCounted, instances: Array, offset: float) -> Dictionary:
	var candidates: Array[Dictionary] = []
	var clear_routes: Array[Dictionary] = []
	var lifetime: float = defense.tuning.rift_lifetime
	for unit in defense.units:
		var route: Dictionary = defense.moving_route(unit)
		if route.is_empty(): continue
		var target: Vector3 = route.target
		var position: Vector3 = route.position
		var origin: Vector3 = route.origin
		var speed: float = route.speed
		var left := snappedf(position.distance_to(target) - speed * offset, 0.01)
		# Sample fixed distances from the destination to avoid shifting the
		# candidate lattice when a caller subdivides a strategic time span.
		var near := maxf(5.0, left - speed * lifetime * 0.85)
		var far := left - RADIUS - 0.35
		var points: Array = []
		var clear_points: Array = []
		for step in range(ceili(near * 2.0), floori(far * 2.0) + 1):
			var at := (target + (origin - target).normalized() * (0.5 * step)).snapped(Vector3.ONE * 0.005)
			if not _clear_navigation(at, defense, instances): continue
			var location := [at.x, at.y, at.z]
			points.append(location)
			if not _covered(location, instances): clear_points.append(location)
		if not points.is_empty(): candidates.append({"encounter": unit.encounter, "points": points})
		if not clear_points.is_empty(): clear_routes.append({"encounter": unit.encounter, "points": clear_points})
	if not clear_routes.is_empty(): candidates = clear_routes
	if candidates.is_empty(): return {}
	var route: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var center: Array = route.points[rng.randi_range(0, route.points.size() - 1)]
	var record := {"id": _id(evaluation), "type": TYPE, "position": center,
		"region": {"shape": "sphere", "radius": RADIUS}, "intensity": 1.0,
		"configuration": {}, "visual": {"seed": str(rng.randi())},
		"simulation": {"remaining": lifetime},
		"generation": {"evaluation": evaluation, "encounter": route.encounter}}
	return JSON.parse_string(JSON.stringify(record))


func _id(event: int) -> String:
	return "rift-%d-%d" % [system_number, event]


static func _clear_navigation(at: Vector3, defense: RefCounted, instances: Array) -> bool:
	if not Layout.bounds(defense.layout_expansion, MAP_SETTINGS.system_bounds).grow(-RADIUS).has_point(Vector2(at.x, at.z)): return false
	if at.distance_to(defense.home) <= RADIUS + 2.8: return false
	for anchor in defense.anchors.values():
		if at.distance_to(anchor) <= RADIUS + 1.6: return false
	for site in defense.construction_sites.values():
		var pos := Vector3(site.position[0], site.position[1], site.position[2])
		if at.distance_to(pos) <= RADIUS + 1.0: return false
	for item in instances:
		if item.type != Solar.TYPE or not Solar.valid(item): continue
		var sun := Vector3(item.position[0], item.position[1], item.position[2])
		if at.distance_to(sun) <= float(item.region.radius) + RADIUS: return false
	if defense.layout_expansion <= 0.0: return at.length() > 12.9
	for body in defense.decorative_bodies:
		if at.distance_to(body.position) <= RADIUS + float(body.radius) * 1.5: return false
	return at.length() > RADIUS + 2.8


static func _covered(location: Array, instances: Array) -> bool:
	for item in instances:
		if item.type == Asteroids.TYPE and Asteroids.contains(item, location): return true
		if item.type == Storms.TYPE and Storms.contains(item, location): return true
	return false


static func active(instances: Array) -> Dictionary:
	for item in instances:
		if item.type == TYPE and not item.region.is_empty(): return item
	return {}


static func valid_geometry(item: Dictionary) -> bool:
	if not Navigation.valid_point(item.get("position"), false): return false
	var region: Variant = item.get("region")
	if not region is Dictionary or region.get("shape") != "sphere" or not _number(region.get("radius"), 1.0, 5.0): return false
	var at: Array = item.position
	return Layout.bounds(Layout.MAX_EXPANSION, MAP_SETTINGS.system_bounds).grow(-float(region.radius)).has_point(Vector2(at[0], at[2]))


static func valid_visual(value: Variant) -> bool:
	return value is Dictionary and value.get("seed") is String and value.seed.is_valid_int()


static func valid_instance(item: Dictionary) -> bool:
	return valid_geometry(item) and valid_visual(item.visual) \
		and _number(item.simulation.get("remaining"), EPSILON, 120.0) \
		and _integer(item.generation.get("evaluation"), 1, 2147483647) \
		and _integer(item.generation.get("encounter"), 0, 2147483647)


static func contains(item: Dictionary, location: Array) -> bool:
	if not valid_geometry(item) or not Navigation.valid_point(location, false): return false
	var delta := Vector3(location[0] - item.position[0], location[1] - item.position[1], location[2] - item.position[2])
	return delta.length_squared() <= pow(float(item.region.radius), 2)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high


static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and value == floor(value)
