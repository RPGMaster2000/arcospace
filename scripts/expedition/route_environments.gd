extends RefCounted

const Solar = preload("res://scripts/expedition/solar_regions.gd")
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const Storms = preload("res://scripts/expedition/storm_regions.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")

static func points(fleet: RefCounted) -> Array:
	var candidates: Array = []
	for unit in fleet.units:
		if unit.status == "reserve": continue
		for fraction in [0.22, 0.36, 0.50, 0.64, 0.78]:
			candidates.append(fleet.wire(unit.route_origin.lerp(fleet.home, fraction)))
	return candidates

static func relevant(item: Dictionary, fleet: RefCounted) -> bool:
	for unit in fleet.units:
		if unit.status == "reserve": continue
		var origin: Array = fleet.wire(unit.route_origin)
		match item.type:
			Solar.TYPE:
				if Solar.contains(item, origin): return false
			Asteroids.TYPE:
				if Asteroids.contains(item, origin): return false
			Storms.TYPE:
				if Storms.contains(item, origin): return false
	for unit in fleet.units:
		if unit.status == "reserve": continue
		if intersects(item, unit.route_origin, fleet.home): return true
	return false

static func asteroid(seed_value: int, system: int, fleet: RefCounted, candidates: Array) -> Array:
	var generated := Asteroids.generate(seed_value, system, candidates, fleet.layout_expansion)
	if relevant(generated[0], fleet): return generated
	for at in candidates:
		var retry := Asteroids.generate(seed_value, system, [at], fleet.layout_expansion)
		if relevant(retry[0], fleet): return retry
	return []

static func storm(item: Dictionary, fleet: RefCounted, candidates: Array, existing: Array) -> Dictionary:
	if item.is_empty() or relevant(item, fleet): return item
	var bounds := Layout.bounds(fleet.layout_expansion)
	var retry := item.duplicate(true)
	var best := {}
	var best_score := INF
	for at in candidates:
		var point := Vector2(at[0], at[2])
		if point.length() < 12.0 or absf(point.x) + float(item.region.axes[0]) > bounds.end.x \
				or absf(point.y) + float(item.region.axes[2]) > bounds.end.y: continue
		retry.position = at
		if not relevant(retry, fleet): continue
		var score := point.distance_squared_to(Vector2(item.position[0], item.position[2]))
		for region in existing:
			if region.type == Solar.TYPE and Solar.contains(region, at): score += 10000.0
			if region.type == Asteroids.TYPE and Asteroids.contains(region, at): score += 10000.0
		if score >= best_score: continue
		best_score = score
		best = retry.duplicate(true)
	return best

# Initial defense routes lie on the system plane. Transform the segment
# into the region's local unit geometry before finding its closest point.
static func intersects(item: Dictionary, start: Vector3, finish: Vector3) -> bool:
	var center := Vector3(item.position[0], item.position[1], item.position[2])
	var a := start - center
	var b := finish - center
	match item.type:
		Solar.TYPE:
			return Geometry3D.get_closest_point_to_segment(Vector3.ZERO, a, b).length() <= item.region.radius
		Storms.TYPE:
			var axes := Vector3(item.region.axes[0], item.region.axes[1], item.region.axes[2])
			return Geometry3D.get_closest_point_to_segment(Vector3.ZERO, a / axes, b / axes).length_squared() <= 1.0
		Asteroids.TYPE:
			var left := Vector2(a.x, a.z).rotated(-float(item.region.angle))
			var right := Vector2(b.x, b.z).rotated(-float(item.region.angle))
			if item.region.shape == "belt":
				left.y /= float(item.region.ratio)
				right.y /= float(item.region.ratio)
				return Geometry2D.get_closest_point_to_segment(Vector2.ZERO, left, right).length() <= item.region.outer \
					and maxf(left.length(), right.length()) >= item.region.inner
			for pocket in item.region.pockets:
				var offset := Vector2(pocket.offset[0], pocket.offset[1])
				var axes := Vector2(pocket.axes[0], pocket.axes[1])
				var p := (left - offset).rotated(-float(pocket.angle)) / axes
				var q := (right - offset).rotated(-float(pocket.angle)) / axes
				if Geometry2D.get_closest_point_to_segment(Vector2.ZERO, p, q).length_squared() <= 1.0: return true
	return false
