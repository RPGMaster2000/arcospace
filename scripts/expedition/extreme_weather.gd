extends RefCounted
## Later Defense weather budgets and deterministic placement of bounded fronts.
const Storms = preload("res://scripts/expedition/storm_regions.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
const MAX_STORMS := 9
const MAX_RIFTS := 4
const ARCHETYPES := ["unstable", "storm_dominated", "chaotic"]
const COVERAGE_GRID := 14


static func plan(archetype: String, settings: Resource, rng: RandomNumberGenerator) -> Dictionary:
	var index := ARCHETYPES.find(archetype)
	if index < 0 or not settings.extreme_weather: return {}
	var counts: Vector2i = settings.extreme_storm_counts[index]
	var coverage: Vector2 = settings.extreme_storm_coverage[index]
	var count := rng.randi_range(clampi(counts.x, 1, MAX_STORMS), clampi(maxi(counts.x, counts.y), 1, MAX_STORMS))
	var target := rng.randf_range(clampf(coverage.x, 0.10, 0.70), clampf(maxf(coverage.x, coverage.y), 0.10, 0.70))
	return {"storms": count, "coverage": target, "rift_cap": clampi(settings.extreme_rift_caps[index], 1, MAX_RIFTS),
		"rift_rate": clampf(settings.extreme_rift_rates[index], 1, 6),
		"rift_chance": [0.78, 0.58, 0.88][index], "rift_life": [24.0, 18.0, 26.0][index],
		"rift_radius": [3.30, 2.55, 2.95][index]}


static func valid(data: Variant, archetype: String) -> bool:
	if not data is Dictionary or archetype not in ARCHETYPES: return false
	for key in ["storms", "rift_cap"]:
		var limit := MAX_STORMS if key == "storms" else MAX_RIFTS
		if not _number(data.get(key), 1, limit) or int(data[key]) != data[key]: return false
	return _number(data.get("coverage"), 0.0999, 0.7001) \
		and _number(data.get("rift_rate"), 1, 6) and _number(data.get("rift_chance"), 0, 1) \
		and _number(data.get("rift_life"), 0.1, 120) and _number(data.get("rift_radius"), 2.35, 5)


static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high


# Allocate large and satellite ellipses. Greedy scoring approximates covered
# area on a fixed grid. Actual battles and map boundaries use exact ellipsoids.
static func fronts(state: Resource, requested: Dictionary, rng: RandomNumberGenerator) -> Array:
	if state.rules.space_storm_chance <= 0.0: return []
	var bounds := Layout.bounds(state.layout_expansion)
	var width := bounds.size.x
	var count: int = int(requested.storms)
	var preferences: Array[float] = []
	var scale_sum := 0.0
	for index in count:
		var scale := rng.randf_range(0.60, 0.77) if index % 3 == 2 else rng.randf_range(1.0, 1.22)
		preferences.append(scale)
		scale_sum += scale * scale
	var radius := sqrt(float(requested.coverage) / (PI * 0.83 * scale_sum)) * width
	var points := PackedVector2Array()
	for x in COVERAGE_GRID:
		for z in COVERAGE_GRID:
			points.append(bounds.position + Vector2(x + 0.5, z + 0.5) * width / COVERAGE_GRID)
	var covered := PackedByteArray()
	covered.resize(points.size())
	var result: Array = []
	var cumulative := 0
	var used := 0.0
	var palette_shift := rng.randi_range(0, Storms.SUBTYPES.size() - 1)
	for index in count:
		var scale := preferences[index]
		used += scale * scale
		var target := roundi(points.size() * float(requested.coverage) * used / scale_sum)
		var variation := rng.randf_range(0.75, 1.27)
		var axes := Vector2(radius * scale * variation, radius * scale / variation)
		axes = axes.limit_length(width * 0.48)
		var angle := rng.randf_range(0.0, TAU)
		var extents := Storms.planar_extent(axes, angle)
		var legal := Rect2(bounds.position + extents, bounds.size - extents * 2.0)
		var best_at := legal.get_center()
		var best_score := INF
		var best_pixels := PackedInt32Array()
		for attempt in 36:
			var at := legal.position + Vector2(rng.randf(), rng.randf()) * legal.size
			var pixels := PackedInt32Array()
			var new_pixels := 0
			for sample in points.size():
				if ((points[sample] - at).rotated(angle) / axes).length_squared() > 1.0: continue
				pixels.append(sample)
				if covered[sample] == 0: new_pixels += 1
			if new_pixels == 0: continue
			var score := absf(cumulative + new_pixels - target) + float(pixels.size() - new_pixels) * 0.07
			# Reward a front that crosses a hostile route, while preserving
			# room for detached patches and useful gaps elsewhere in the sector.
			for unit in state.defense.units:
				if unit.reinforcement or unit.mothership: continue
				var site: Vector3 = unit.route_origin.lerp(state.defense.home, 0.42)
				if ((Vector2(site.x, site.z) - at).rotated(angle) / axes).length_squared() <= 1.0:
					score -= 1.5
					break
			if at.length() < width * 0.08: score += 3.5
			if score >= best_score: continue
			best_score = score
			best_at = at
			best_pixels = pixels
		for sample in best_pixels:
			if covered[sample] == 0:
				covered[sample] = 1
				cumulative += 1
		var subtype: String = Storms.SUBTYPES[(palette_shift + index) % Storms.SUBTYPES.size()]
		result.append(Storms.front(state.seed_used, state.system_number, index, best_at, axes, angle,
			subtype, rng.randf_range(0.74, 0.99), rng.randf_range(0.0, TAU)))
	return JSON.parse_string(JSON.stringify(result))
