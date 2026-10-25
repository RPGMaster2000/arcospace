extends RefCounted
# Pure cosmetic data. Never reads State, rolls an encounter or persists camera data.
const Names = preload("res://scripts/presentation/star_system/astronomical_names.gd")
const TYPES = ["rocky", "terrestrial", "desert", "frozen", "volcanic", "gas_giant", "barren"]
const PLANETARY = {"mining_operation": "rocky", "gas_giant": "gas_giant", "research_station": "frozen", "quarantined_colony": "terrestrial"}
const ROMAN = ["I", "II", "III", "IV"]
const ANCHORS = [Vector3(-12,0,-7), Vector3(0,0,-9), Vector3(12,0,-7), Vector3(-12,0,7), Vector3(0,0,9), Vector3(12,0,7)]

static func random_for(seed_value: int, number: int, channel: String) -> RandomNumberGenerator:
	var rng = RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:%s:v1" % [seed_value, number, channel])
	return rng

static func orbit_point(planet: Dictionary, angle: float) -> Vector3:
	# Eccentric anomaly parameterization: star at the focus, not ellipse center.
	var a: float = planet.distance
	var e: float = planet.eccentricity
	var point = Vector3(a * (cos(angle) - e), 0, a * sqrt(1.0 - e * e) * sin(angle))
	return Basis(Vector3.UP, planet.orientation) * Basis(Vector3.RIGHT, planet.inclination) * point

static func generate(seed_value: int, number: int, entries: Array, settings: Resource) -> Dictionary:
	var rng = random_for(seed_value, number, "planets")
	var result: Dictionary = {"name": Names.system_name(seed_value, number), "planets": [], "anchors": {}, "assignments": {}}
	var count: int = rng.randi_range(2, clampi(settings.maximum_planets, 2, 4))
	# Disjoint radial shells guarantee clearance even when inclined paths cross in projection.
	var band: float = 8.4 / maxi(1, count)
	for i in range(count):
		var kind: String = TYPES[rng.randi_range(0, TYPES.size()-1)]
		var inner: float = 1.4 + i * band
		var outer: float = inner + band
		var space: float = minf(settings.minimum_orbit_spacing, band * 0.3)
		var radius: float = rng.randf_range(settings.planet_radius_range.x, settings.planet_radius_range.y)
		if kind == "gas_giant": radius *= 1.2
		radius = clampf(radius, 0.15, (band - space) * 0.45)
		var low: float = inner + radius + space * 0.5
		var high: float = outer - radius - space * 0.5
		var a: float = rng.randf_range(low, high)
		var allowed_e: float = maxf(0, minf(a-low, high-a) / a)
		var p: Dictionary = {"index": i, "name": result.name + " " + ROMAN[i], "type": kind,
			"radius": radius, "distance": a, "eccentricity": rng.randf_range(0, minf(settings.maximum_eccentricity, allowed_e)),
			"inclination": deg_to_rad(rng.randf_range(-settings.maximum_inclination, settings.maximum_inclination)),
			"orientation": rng.randf_range(0, TAU), "phase": rng.randf_range(0, TAU),
			"rotation": rng.randf_range(0, TAU), "rotation_speed": rng.randf_range(0.015, 0.04),
			"material_seed": rng.randi(), "encounter": -1}
		p.position = orbit_point(p, p.phase)
		result.planets.append(p)
	var eligible: Array = []
	for entry in entries:
		if PLANETARY.has(entry.get("model_kind", "")) and entry.get("profile") == null:
			eligible.append(entry)
	eligible.sort_custom(func(a,b): return a.index < b.index)
	var assignment_rng = random_for(seed_value, number, "assignments")
	for p in result.planets:
		if eligible.is_empty() or assignment_rng.randf() < 0.25: continue
		var entry: Dictionary = eligible.pop_at(assignment_rng.randi_range(0, eligible.size()-1))
		p.encounter = entry.index
		p.type = PLANETARY[entry.model_kind]
		result.assignments[entry.index] = p.index
		result.anchors[entry.index] = p.position
	var occupied: Array = result.planets.map(func(p): return {"position":p.position,"radius":p.radius*1.5})
	var ordered: Array = entries.duplicate()
	ordered.sort_custom(func(a,b): return a.index < b.index)
	for entry in ordered:
		if result.anchors.has(entry.index): continue
		var local = random_for(seed_value, number, "destination-%d" % entry.index)
		var anchor: Vector3 = ANCHORS[entry.index] if entry.index >= 0 and entry.index < 6 else Vector3(14,0,0)
		var at: Vector3 = anchor
		for attempt in range(64):
			at = anchor + Vector3(local.randf_range(-1.3,1.3), local.randf_range(-0.3,0.3), local.randf_range(-1.0,1.0))
			var bounds: Rect2 = settings.system_bounds.abs()
			var xz: Vector2 = Vector2(at.x,at.z).clamp(bounds.position, bounds.end)
			at = Vector3(xz.x, at.y, xz.y)
			if occupied.all(func(o): return at.distance_to(o.position) > o.radius + 1.6): break
		result.anchors[entry.index] = at
		occupied.append({"position": at, "radius": 1.2})
	var star_rng = random_for(seed_value, number, "star")
	result.star_color = Color.from_hsv(star_rng.randf_range(0.02,0.16), 0.45, 1)
	return result
