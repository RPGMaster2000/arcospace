extends RefCounted
## Bounded scene-free placement. Writes only DefenseState's authoritative anchors
## and initial route origins. Failed candidates retain the validated legacy layout.
const Layout = preload("res://scripts/expedition/system_layout.gd")
const Variation = preload("res://scripts/expedition/system_variation.gd")
const RETRIES = 96
const MIN_GAP = 3.2
# Keep destinations outside the homeworld approach/interaction area.
const HOME_GAP = 8.0


static func apply(state: Resource) -> void:
	if state.system_variation.is_empty():
		return
	var fleet: RefCounted = state.defense
	var original: Dictionary = fleet.anchors.duplicate()
	var sizes := Layout.planetary_radii(state.encounters)
	var rng := Variation.rng_for(state.seed_used, state.system_number, "placements")
	var outer := _planets(state, rng, sizes)
	var occupied: Array[Vector3] = [fleet.home, fleet.start]
	for unit in fleet.units:
		if unit.status != "reserve":
			occupied.append(unit.position)
	for index in sizes:
		occupied.append(fleet.anchors[index])
	var keys: Array = original.keys()
	keys.sort()
	var success := true
	for index in keys:
		if sizes.has(index):
			continue
		var found := false
		for attempt in RETRIES:
			var at := _candidate(state, rng, attempt)
			if not _clear(at, occupied, sizes, fleet.anchors, state.orbit_clearance, fleet.home):
				continue
			fleet.anchors[index] = at
			occupied.append(at)
			found = true
			break
		if not found:
			success = false
			break
	if not success:
		fleet.anchors = original
		outer = _outer(fleet.anchors, sizes)
	_fleet(state, sizes, outer)


static func _outer(anchors: Dictionary, sizes: Dictionary) -> float:
	var outer := 4.15
	for index in sizes:
		outer = maxf(outer, anchors[index].length() + float(sizes[index]))
	return outer


static func _planets(state: Resource, rng: RandomNumberGenerator, sizes: Dictionary) -> float:
	var fleet: RefCounted = state.defense
	var inner := 4.15
	var maximum: float = minf(fleet.home.length() - 3.15, 24.0)
	for unit in fleet.units:
		if unit.status != "reserve":
			maximum = minf(maximum, unit.position.length() - 5.55)
	var required := 0.0
	for radius in sizes.values():
		required += 2 * float(radius) + state.orbit_clearance
	var slack := maxf(0, maximum - inner - required)
	var gaps: Array[float] = []
	var total := 0.0
	for i in range(sizes.size() + 1):
		var gap := rng.randf_range(0.1, 1.0)
		if state.system_variation.archetype == "crowded":
			gap *= 0.15 if i > 0 and i < sizes.size() else 2.0
		if state.system_variation.archetype == "chaotic":
			gap = pow(gap, 3)
		gaps.append(gap)
		total += gap
	var occupied: Array[Vector3] = [fleet.home, fleet.start]
	for unit in fleet.units:
		if unit.status != "reserve":
			occupied.append(unit.position)
	var order := sizes.keys()
	# Preserve orbital clearance at every phase, not just the initial visible frame.
	for i in order.size():
		var index: int = order[i]
		inner += gaps[i] / total * slack
		var radius: float = sizes[index]
		var angle := rng.randf_range(0, TAU)
		if state.system_variation.archetype in ["asymmetric", "crowded"]:
			angle = state.system_variation.axis + rng.randf_range(-0.8, 0.8)
		var at := Vector3(cos(angle), 0, sin(angle)) * (inner + radius)
		for attempt in RETRIES:
			if (
				at.distance_to(fleet.home) >= HOME_GAP
				and not occupied.any(func(other): return at.distance_to(other) < MIN_GAP)
			):
				break
			angle += TAU / RETRIES
			at = Vector3(cos(angle), 0, sin(angle)) * (inner + radius)
		fleet.anchors[index] = at
		occupied.append(at)
		inner += 2 * radius + state.orbit_clearance
	return _outer(fleet.anchors, sizes)


static func _candidate(state: Resource, rng: RandomNumberGenerator, attempt: int) -> Vector3:
	var profile: Dictionary = state.system_variation
	var limit := Layout.bounds(state.layout_expansion).end.x - 2
	var angle := rng.randf_range(0, TAU)
	var radius := rng.randf_range(6, limit)
	match profile.archetype:
		"scattered":
			radius = rng.randf_range(limit * 0.65, limit)
		"crowded":
			angle = profile.axis + rng.randf_range(-0.6, 0.6) + (PI if attempt % 2 else 0.0)
			radius = rng.randf_range(11, 22)
		"asymmetric":
			angle = profile.axis + rng.randf_range(-1.0, 1.0)
		"unstable", "storm_dominated":
			radius = rng.randf_range(9, limit)
		"chaotic":
			return Vector3(rng.randf_range(-limit, limit), 0, rng.randf_range(-limit, limit))
	return Vector3(cos(angle), 0, sin(angle)) * radius


static func _clear(
	at: Vector3,
	occupied: Array[Vector3],
	sizes: Dictionary,
	anchors: Dictionary,
	margin: float,
	home: Vector3
) -> bool:
	if at.length() < 4.15 or at.distance_to(home) < HOME_GAP:
		return false
	for other in occupied:
		if at.distance_to(other) < MIN_GAP:
			return false
	for index in sizes:
		if absf(at.length() - anchors[index].length()) < float(sizes[index]) + 1.2 + margin:
			return false
	return true


static func _fleet(
	state: Resource, sizes: Dictionary, outer: float, safe_retry: bool = false
) -> void:
	var fleet: RefCounted = state.defense
	var rng := Variation.rng_for(
		state.seed_used, state.system_number, "fleet-safe" if safe_retry else "fleet-placements"
	)
	var profile: Dictionary = state.system_variation
	var formation: String = profile.formation
	var heading := atan2(fleet.home.z, fleet.home.x)
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var cluster := side * rng.randf_range(1.4, 2.3)
	var placed: Array[Vector3] = []
	for unit in fleet.units:
		if unit.mothership:
			placed.append(unit.position)
	var approaches: Array[Dictionary] = []
	var original_positions: Array = fleet.units.map(func(unit): return unit.position)
	var failed := false
	var ordinal := 0
	for unit in fleet.units:
		if unit.mothership or unit.status == "reserve":
			continue
		var found := false
		for attempt in RETRIES:
			var offset := side * rng.randf_range(0.95, 2.6)
			var radius := rng.randf_range(
				maxf(outer + 5.55, 22), Layout.bounds(state.layout_expansion).end.x - 1
			)
			match formation:
				"clustered":
					offset = cluster + rng.randf_range(-0.2, 0.2)
				"pincer", "spread":
					offset *= -1.0 if ordinal % 2 else 1.0
				"staggered":
					radius = clampf(
						23 + ordinal * 4.0 + rng.randf_range(-1, 1),
						outer + 5.55,
						Layout.bounds(state.layout_expansion).end.x - 1
					)
				"vanguard":
					radius = clampf(
						29.0 - 5.0 * (fleet.speed_multiplier(unit) - 1.0) + rng.randf_range(-1, 1),
						outer + 5.55,
						Layout.bounds(state.layout_expansion).end.x - 1
					)
				"unstructured":
					offset = rng.randf_range(-2.7, 2.7)
			if safe_retry:
				offset = [1.35, -1.35, 2.5][ordinal] + rng.randf_range(-0.08, 0.08)
				radius = Layout.bounds(state.layout_expansion).end.x - 1.0
			var at := Vector3(cos(heading + offset), 0, sin(heading + offset)) * radius
			var eta: float = (
				at.distance_to(fleet.home)
				/ (fleet.tuning.enemy_speed * fleet.speed_multiplier(unit))
			)
			if eta < profile.minimum_arrival or at.distance_to(fleet.start) < 6:
				continue
			if Geometry3D.get_closest_point_to_segment(Vector3.ZERO, at, fleet.home).length() < 3.5:
				continue
			if placed.any(
				func(other):
					return (
						at.distance_to(other)
						< maxf(MIN_GAP, fleet.tuning.interception_radius * 2.0 + 1.0)
					)
			):
				continue
			if fleet.anchors.values().any(func(other): return at.distance_to(other) < MIN_GAP):
				continue
			var speed: float = fleet.tuning.enemy_speed * fleet.speed_multiplier(unit)
			if approaches.any(
				func(other):
					return (
						_blocks(fleet, at, speed, other.position, other.speed)
						or _blocks(fleet, other.position, other.speed, at, speed)
					)
			):
				continue
			unit.position = at
			unit.route_origin = at
			found = true
			break
		failed = failed or not found
		approaches.append(
			{
				"position": unit.position,
				"speed": fleet.tuning.enemy_speed * fleet.speed_multiplier(unit)
			}
		)
		placed.append(unit.position)
		ordinal += 1
	if failed:
		# Restore the entire safe deployment, not a mixture of fallback/new routes.
		for index in fleet.units.size():
			fleet.units[index].position = original_positions[index]
			fleet.units[index].route_origin = original_positions[index]
		if not safe_retry:
			_fleet(state, sizes, outer, true)


# Prevent another initial ship's swept interception sphere from obstructing the
# player's initial interception course. Uses the existing actual-speed solver.
static func _blocks(
	fleet: RefCounted, target: Vector3, speed: float, obstacle: Vector3, obstacle_speed: float
) -> bool:
	var intercept: Vector3 = fleet._intercept(target, fleet.home, speed, fleet.start)
	var seconds: float = fleet.start.distance_to(intercept) * fleet.tuning.seconds_per_distance
	if seconds <= 0.001:
		return true
	var player_velocity: Vector3 = (intercept - fleet.start) / seconds
	var enemy_velocity: Vector3 = (fleet.home - obstacle).normalized() * obstacle_speed
	return is_finite(
		fleet.hit_time(
			fleet.start - obstacle,
			player_velocity - enemy_velocity,
			fleet.tuning.interception_radius + 0.5,
			seconds
		)
	)
