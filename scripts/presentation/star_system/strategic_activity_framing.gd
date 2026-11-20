extends RefCounted
## Selects a local cluster from the strategic map snapshots, then fits it in
## perspective inside the clear part of the view. Never moves simulation actors.

const CLUSTER_RADIUS := 14.0
const SHIP_MARGIN := 1.65
const MIN_DISTANCE := 12.0
const MAX_DISTANCE := 54.0
const REFRESH_SECONDS := 0.2
const RESPONSE := 3.5

var _anchor := -1
var _refresh_in := 0.0
var _target: Transform3D


func begin(map: Control, safe: Rect2) -> void:
	_anchor = -1
	_refresh_in = REFRESH_SECONDS
	var camera: Camera3D = map.camera
	camera.cancel()
	_target = _choose_frame(map, safe)
	camera.global_transform = _target


func update(map: Control, safe_bounds: Callable, seconds: float) -> void:
	_refresh_in -= seconds
	if _refresh_in <= 0.0:
		_refresh_in = REFRESH_SECONDS
		_target = _choose_frame(map, safe_bounds.call())
	var camera: Camera3D = map.camera
	camera.global_transform = camera.global_transform.interpolate_with(_target,
		1.0 - exp(-RESPONSE * minf(seconds, 0.1)))


func _choose_frame(map: Control, safe: Rect2) -> Transform3D:
	var candidates := _contacts(map)
	var camera: Camera3D = map.camera
	var direction: Vector3 = (map.settings.overview_position - map.settings.overview_target).normalized()
	var axes := Basis.looking_at(-direction, Vector3.UP)
	var aspect: float = camera.get_viewport().get_visible_rect().size.aspect()
	var tangent := tan(deg_to_rad(camera.fov * 0.5))
	var slopes := Vector2(tangent * aspect, tangent)
	var points: Array[Vector3] = []
	if candidates.is_empty():
		_anchor = -1
		points = _fallback(map)
	else:
		candidates.sort_custom(func(a, b):
			if a.priority != b.priority: return a.priority > b.priority
			if (a.id == _anchor) != (b.id == _anchor): return a.id == _anchor
			var first: float = (a.points[0] as Vector3).distance_squared_to(map.ship.position)
			var second: float = (b.points[0] as Vector3).distance_squared_to(map.ship.position)
			if a.priority == 3 and not is_equal_approx(first, second): return first < second
			return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
		var anchor: Dictionary = candidates.front()
		_anchor = anchor.id
		points.assign(anchor.points)
		points.append(map.ship.position)
		var required: float = _fit(points, axes, slopes, safe).distance
		var limit := maxf(MAX_DISTANCE, required * 1.13)
		for candidate in candidates.slice(1):
			if (candidate.points[0] as Vector3).distance_to(anchor.points[0]) > CLUSTER_RADIUS:
				continue
			var expanded: Array[Vector3] = points.duplicate()
			expanded.append_array(candidate.points)
			if _fit(expanded, axes, slopes, safe).distance <= limit:
				points = expanded
	var result := _fit(points, axes, slopes, safe)
	return result.pose


func _contacts(map: Control) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var warzone: RefCounted = map.warzone_view
	if warzone != null:
		for fleet in warzone.fleets:
			if fleet.side != "hostile" or not warzone.active(fleet): continue
			var destination: Dictionary = warzone.objectives[fleet.destination]
			var rival: Dictionary = warzone.fleet_at(fleet.engaged)
			var priority := 2 if destination.owner == "allied" else 1
			var points: Array[Vector3] = [fleet.position]
			if warzone.active(rival):
				points.append(rival.position)
				priority = 3
			result.append({"id": fleet.id, "points": points, "priority": priority,
				"distance": (fleet.position as Vector3).distance_squared_to(destination.position)})
		return result
	var defense: Dictionary = map.defense_view
	if defense.is_empty() or defense.complete:
		return result
	var home := _point(defense.home)
	for unit in defense.units:
		if unit.status != "active" or (unit.mothership and not defense.revealed): continue
		var at := _point(unit.position)
		var advancing: bool = unit.mothership and defense.mothership_advancing
		result.append({"id": unit.encounter, "points": [at], "priority": 3 if advancing else (1 if unit.mothership else 2),
			"distance": at.distance_squared_to(home)})
	for missile in defense.get("missiles", {}).get("active", []):
		var at := _point(missile.position)
		result.append({"id": missile.id, "points": [at], "priority": 2, "distance": at.distance_squared_to(home)})
	return result


func _fallback(map: Control) -> Array[Vector3]:
	var player: Vector3 = map.ship.position
	var points: Array[Vector3] = [player]
	var nearest := CLUSTER_RADIUS * CLUSTER_RADIUS
	var objective := player
	var warzone: RefCounted = map.warzone_view
	if warzone != null:
		for site in warzone.objectives:
			var distance: float = player.distance_squared_to(site.position)
			if distance >= nearest: continue
			nearest = distance
			objective = site.position
	elif not map.defense_view.is_empty():
		var home := _point(map.defense_view.home)
		if player.distance_to(home) <= CLUSTER_RADIUS:
			objective = home
	if objective != player: points.append(objective)
	return points


static func _point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func _fit(points: Array[Vector3], axes: Basis, slopes: Vector2, safe: Rect2) -> Dictionary:
	# Project the padded corners in camera-aligned space. Each edge constrains
	# the allowed camera offset at a given depth. Solve the four constraints
	# together so the camera fits an off-center clear rectangle without tilting.
	var low := Vector2(2.0 * safe.position.x - 1.0, 1.0 - 2.0 * safe.end.y) * slopes
	var high := Vector2(2.0 * safe.end.x - 1.0, 1.0 - 2.0 * safe.position.y) * slopes
	var lower := Vector2(-INF, -INF)
	var upper := Vector2(INF, INF)
	var closest := -INF
	var pivot: Vector3 = points.front()
	var inverse := axes.transposed()
	for point in points:
		var center := inverse * (point - pivot)
		for depth in [-SHIP_MARGIN, SHIP_MARGIN]:
			var z: float = center.z + depth
			closest = maxf(closest, z)
			var plane := Vector2(center.x, center.y)
			lower = lower.max(plane + Vector2.ONE * SHIP_MARGIN + high * z)
			upper = upper.min(plane - Vector2.ONE * SHIP_MARGIN + low * z)
	var span := (lower - upper) / (high - low)
	var distance := maxf(MIN_DISTANCE, maxf(closest + 4.0, maxf(span.x, span.y)))
	distance *= 1.12
	var shifted := 0.5 * (lower + upper - (high + low) * distance)
	return {"distance": distance, "pose": Transform3D(axes, pivot + axes * Vector3(shifted.x, shifted.y, distance))}
