extends RefCounted
## Bounded scene-free placement. Writes only DefenseState's authoritative anchors
## and initial route origins. Failed candidates retain the validated legacy layout.
const Layout = preload("res://scripts/expedition/system_layout.gd")
const Variation = preload("res://scripts/expedition/system_variation.gd")
const RETRIES = 96
const MIN_GAP = 3.2
# Keep destinations outside the homeworld approach/interaction area.
const HOME_GAP = 8.0


static func apply(state: Resource) -> bool:
	if state.system_variation.is_empty(): return true
	if state.system_variation.get("version") == 2: return _apply_geometry(state)
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
	var preparation: Array = fleet.Warfare.preparation_sites(state, keys)
	if not preparation.is_empty():
		keys = preparation + keys.filter(func(index): return index not in preparation)
	var success := true
	for index in keys:
		if sizes.has(index):
			continue
		var found := false
		for attempt in RETRIES:
			var at := _candidate(state, rng, attempt)
			if index in preparation and attempt < 40:
				var distance := rng.randf_range(8.3, 13.0)
				var flank := (1.0 if preparation.find(index) == 0 else -1.0)
				var heading: Vector3 = fleet.home.normalized().rotated(Vector3.UP, flank * rng.randf_range(1.08, 2.55))
				at = fleet.home + heading * distance
				if not Layout.bounds(state.layout_expansion).grow(-2.0).has_point(Vector2(at.x, at.z)): continue
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
	if fleet.military.is_empty(): _fleet(state, sizes, outer)
	return true


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
						fleet.approach_blocked(at, speed, other.position, other.speed)
						or fleet.approach_blocked(other.position, other.speed, at, speed)
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

const PREPARATION := ["derelict_starship", "pirate_debris_field", "distress_signal",
	"radiation_nebula", "raider_cache", "spatial_anomaly"]
const INFRASTRUCTURE := {
	"scattered":["mining_operation", "derelict_starship", "distress_signal"],
	"crowded":["mining_operation", "pirate_debris_field", "research_station"],
	"asymmetric":["mining_operation", "pirate_debris_field", "derelict_starship"],
	"unstable":["research_station", "spatial_anomaly", "radiation_nebula"],
	"storm_dominated":["radiation_nebula", "gas_giant", "spatial_anomaly"],
	"chaotic":["spatial_anomaly", "quarantined_colony", "distress_signal"],
}


static func select_pois(state: Resource, selected: Array) -> Array:
	var result: Array = []
	var preferred: Array = INFRASTRUCTURE.get(state.system_variation.archetype, [])
	var size: int = state.system_variation.poi_count
	var rng := Variation.rng_for(state.seed_used, state.system_number, "infrastructure")
	var choices: Array = state.rules.pois.filter(func(poi):
		return poi.resource_path.get_file().get_basename() != "unstable_wormhole")
	var special := choices.filter(func(poi): return poi.resource_path.get_file().get_basename() in preferred)
	for slot in mini(2, special.size()):
		result.append(special.pop_at(rng.randi_range(0, special.size() - 1)))
	for poi in selected + choices:
		if result.size() >= size: break
		if poi not in result: result.append(poi)
	var repeatable := choices.filter(func(poi):
		return not Layout.PLANETARY.has(poi.resource_path.get_file().get_basename()))
	while result.size() < size and not repeatable.is_empty():
		result.append(repeatable[rng.randi_range(0, repeatable.size() - 1)])
	if not result.is_empty() and not result.any(func(poi): return poi.resource_path.get_file().get_basename() in PREPARATION):
		for poi in choices:
			if poi.resource_path.get_file().get_basename() in PREPARATION:
				result[-1] = poi
				break
	return result


static func _apply_geometry(state: Resource) -> bool:
	var fleet: RefCounted = state.defense
	var profile: Dictionary = state.system_variation
	var rng := Variation.rng_for(state.seed_used, state.system_number, "geometry-%d" % int(profile.placement_attempt))
	var sizes := Layout.planetary_radii(state.encounters, profile.planet_scales)
	var bounds := Layout.bounds(state.layout_expansion)
	var clear_core: float = fleet.stellar_clearance()
	var occupied: Array[Vector3] = [fleet.home, fleet.start]
	var keys: Array = fleet.anchors.keys()
	keys.sort()
	var preparation: Array = fleet.Warfare.preparation_sites(state, keys).filter(func(index):
		return index < 0 or state.encounters[index].poi.resource_path.get_file().get_basename() in PREPARATION)
	if preparation.is_empty():
		preparation = keys.filter(func(index):
			return index < 0 or state.encounters[index].poi.resource_path.get_file().get_basename() in PREPARATION).slice(0, 1)
	keys = preparation + keys.filter(func(index): return index not in preparation)
	if not _place_orbits(state, rng, sizes, bounds, occupied): return false
	for index in keys:
		if sizes.has(index): continue
		var found := false
		for attempt in RETRIES:
			var at := _infrastructure_position(state, rng, index, attempt)
			if index in preparation:
				var distance := rng.randf_range(8.2, 13.0)
				var sign_value := 1.0 if preparation.find(index) == 0 else -1.0
				var direction: Vector3 = fleet.home.normalized().rotated(Vector3.UP, sign_value * rng.randf_range(0.8, 2.9))
				at = fleet.home + direction * distance
				if fleet.start.distance_to(at) * fleet.tuning.seconds_per_distance > 3.0: continue
			if not Layout.navigable(at, state.layout_expansion, 2.0) or at.length() < clear_core + 1.1: continue
			if occupied.any(func(other): return at.distance_to(other) < 3.65): continue
			if at.distance_to(fleet.home) < HOME_GAP or not Layout.clear_orbit(at, sizes, fleet.anchors, 1.2 + state.orbit_clearance): continue
			fleet.anchors[index] = at
			occupied.append(at)
			found = true
			break
		if not found: return false
	if fleet.military.is_empty(): _fleet(state, sizes, _outer(fleet.anchors, sizes))
	return true


static func _place_orbits(state: Resource, rng: RandomNumberGenerator, sizes: Dictionary,
		bounds: Rect2, occupied: Array[Vector3]) -> bool:
	var fleet: RefCounted = state.defense
	var profile: Dictionary = state.system_variation
	var home_distance: float = fleet.home.length()
	var inner: float = fleet.stellar_clearance() + 0.6
	var outer := bounds.end.x - (5.8 if profile.placement_attempt == 0 else 3.9)
	var gap: float = 3.05 + state.orbit_clearance
	var bands := [Vector2(inner, minf(outer, home_distance - gap)), Vector2(home_distance + gap, outer)]
	var indices := sizes.keys()
	indices.sort()
	if indices.is_empty(): return true
	var best: Array = []
	var best_score := -INF
	for mask in 1 << indices.size():
		var split := [[], []]
		var used := [0.0, 0.0]
		for i in indices.size():
			var band: int = (mask >> i) & 1
			split[band].append(indices[i])
			used[band] += 2.0 * float(sizes[indices[i]]) + state.orbit_clearance
		var slack_left: float = bands[0].y - bands[0].x - used[0] + state.orbit_clearance
		var slack_right: float = bands[1].y - bands[1].x - used[1] + state.orbit_clearance
		if (not split[0].is_empty() and slack_left < 0.0) or (not split[1].is_empty() and slack_right < 0.0): continue
		var score := rng.randf_range(0, 3.0)
		if profile.archetype == "scattered": score += float(split[1].size()) * 2.0
		if profile.archetype == "crowded": score += absf(float(split[0].size() - split[1].size()))
		if score <= best_score: continue
		best = split
		best_score = score
	if best.is_empty(): return false
	for band in 2:
		var group: Array = best[band]
		if group.is_empty(): continue
		var cursor: float = bands[band].x
		var slack: float = bands[band].y - cursor - state.orbit_clearance * (group.size() - 1)
		for index in group: slack -= 2.0 * float(sizes[index])
		var spacing: Array[float] = []
		for i in range(group.size() + 1):
			var weight := rng.randf_range(0.08, 1.0)
			if profile.archetype == "crowded" and i > 0 and i < group.size(): weight *= 0.16
			if profile.archetype == "chaotic": weight = pow(weight, 2.5)
			spacing.append(weight)
		var total: float = spacing.reduce(func(sum, amount): return sum + amount, 0.0)
		for i in group.size():
			var index: int = group[i]
			var radius: float = sizes[index]
			cursor += slack * spacing[i] / total
			var distance := cursor + radius
			var phase := rng.randf_range(0, TAU)
			if profile.archetype in ["asymmetric", "crowded"]:
				phase = float(profile.axis) + rng.randf_range(-0.8, 0.8)
			var found := false
			for attempt in 72:
				var at := Vector3(cos(phase), 0, sin(phase)) * distance
				if not occupied.any(func(other): return at.distance_to(other) < radius + 2.2):
					fleet.anchors[index] = at
					occupied.append(at)
					found = true
					break
				phase += TAU / 72.0
			if not found: return false
			cursor += 2.0 * radius + state.orbit_clearance
	return true


static func _infrastructure_position(state: Resource, rng: RandomNumberGenerator, index: int, attempt: int) -> Vector3:
	var profile: Dictionary = state.system_variation
	var limit := Layout.bounds(state.layout_expansion).end.x - 2.0
	var angle := rng.randf_range(0, TAU)
	var radius := rng.randf_range(limit * 0.23, limit * 0.87)
	if attempt < (87 if profile.placement_attempt == 0 else 64):
		match profile.archetype:
			"scattered":
				radius = rng.randf_range(limit * 0.73, limit * 1.17)
			"crowded":
				angle = float(profile.axis) + (0.86 if index % 3 == 0 else -0.86) + rng.randf_range(-0.31, 0.31)
				radius = rng.randf_range(limit * 0.42, limit * 0.78)
			"asymmetric":
				angle = float(profile.axis) + rng.randf_range(-0.94, 0.94)
			"unstable":
				angle = float(profile.axis) + (1.12 if index % 2 else -1.78) + rng.randf_range(-0.62, 0.62)
			"storm_dominated":
				radius = rng.randf_range(limit * 0.40, limit * 0.93)
			"chaotic":
				angle = float(profile.axis) + (1.5 if index % 2 else -1.1) + rng.randf_range(-1.12, 1.12)
				radius = rng.randf_range(limit * 0.27, limit * 1.20)
	return Vector3(cos(angle), 0, sin(angle)) * radius
