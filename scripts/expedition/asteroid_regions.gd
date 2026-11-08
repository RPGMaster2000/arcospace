extends RefCounted
## Scene-free generation and geometry. ExpeditionState owns the returned records.
## These constants affect new systems only; saves retain their compact definitions.
const TYPE = "ASTEROID_FIELD"
const MAX_LOCAL_FIELDS = 2
const BELT_WIDTH = Vector2(2.6, 4.4)
const BELT_RADIUS = Vector2(7.0, 21.0)
const SYSTEM_RADIUS = 27.0
const Navigation = preload("res://scripts/expedition/navigation_state.gd")

static func generate(run_seed: int, number: int, battle_positions: Array) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:asteroid-regions:v1" % [run_seed, number])
	var result: Array = []
	var angle: float = rng.randf_range(0, TAU)
	var ratio: float = rng.randf_range(0.84, 1.0)
	var radius: float = rng.randf_range(BELT_RADIUS.x, BELT_RADIUS.y)
	# Use an existing physical anchor, never move/create an encounter to obtain an effect.
	# Defense attackers cross the belt while approaching home; exploration gets a
	# belt intersecting one of its static battle locations whenever within bounds.
	if not battle_positions.is_empty():
		var at: Array = battle_positions[rng.randi_range(0, battle_positions.size() - 1)]
		var local := Vector2(float(at[0]), float(at[2])).rotated(-angle)
		radius = clampf(Vector2(local.x, local.y / ratio).length(), BELT_RADIUS.x, BELT_RADIUS.y)
	var width: float = rng.randf_range(BELT_WIDTH.x, BELT_WIDTH.y)
	var belt: Dictionary = _record(run_seed, number, 0, rng)
	belt.region = {"shape": "belt", "inner": radius - width * 0.5,
		"outer": radius + width * 0.5, "ratio": ratio, "angle": angle,
		"half_height": rng.randf_range(1.0, 1.6)}
	result.append(belt)
	var count: int = rng.randi_range(0, MAX_LOCAL_FIELDS)
	for index in range(count):
		var item: Dictionary = _record(run_seed, number, index + 1, rng)
		var extent: float = rng.randf_range(2.3, 3.8)
		var center := Vector2.ZERO
		var placed := false
		for attempt in range(32):
			var heading: float = rng.randf_range(0, TAU)
			var distance: float = rng.randf_range(4.5, SYSTEM_RADIUS - extent * 1.8)
			center = Vector2(cos(heading), sin(heading)) * distance
			var local := center.rotated(-angle)
			var radial: float = Vector2(local.x, local.y / ratio).length()
			if radial > float(belt.region.inner) - extent * 1.6 and radial < float(belt.region.outer) + extent * 1.6: continue
			var clear := true
			for other in result.slice(1):
				if center.distance_to(Vector2(other.position[0], other.position[2])) < extent * 3.3: clear = false
			if clear:
				placed = true
				break
		if not placed: continue
		item.position = [center.x, 0.0, center.y]
		var pockets: Array = []
		for pocket in range(3):
			# Overlapping offset ellipses make an elongated/curved concentration,
			# not a miniature annulus. Same union drives containment and rendering.
			pockets.append({"offset": [(pocket - 1) * extent * 0.65, rng.randf_range(-0.5, 0.5) * extent],
				"axes": [extent * rng.randf_range(0.65, 1.0), extent * rng.randf_range(0.35, 0.65)],
				"angle": rng.randf_range(-0.5, 0.5)})
		item.region = {"shape": "pockets", "angle": rng.randf_range(0, TAU),
			"half_height": rng.randf_range(0.9, 1.5), "pockets": pockets}
		result.append(item)
	# Match persisted precision before first use, not only after resuming.
	return JSON.parse_string(JSON.stringify(result))

static func _record(run_seed: int, number: int, index: int, rng: RandomNumberGenerator) -> Dictionary:
	return {"id": "asteroids-%d-%d" % [number, index], "type": TYPE,
		"position": [0.0, 0.0, 0.0], "region": {}, "intensity": 1.0,
		"configuration": {"subtype": "belt" if index == 0 else "concentration"},
		"visual": {"seed": str(rng.randi()), "density": rng.randf_range(0.8, 1.2),
			"gap_angle": rng.randf_range(0, TAU), "tint": [0.46, 0.39, 0.32]},
		"simulation": {}, "generation": {"version": 1, "run_seed": str(run_seed), "system": number}}

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func valid(item: Dictionary) -> bool:
	if not Navigation.valid_point(item.get("position"), false): return false
	var region: Variant = item.get("region")
	if not region is Dictionary: return false
	if not _number(region.get("angle"), -TAU, TAU) or not _number(region.get("half_height"), 0.1, 8.0): return false
	if region.get("shape") == "belt":
		return _number(region.get("inner"), 0.1, 40.0) and _number(region.get("outer"), 0.2, 48.0) and region.outer > region.inner and _number(region.get("ratio"), 0.5, 1.0)
	if region.get("shape") != "pockets" or not region.get("pockets") is Array or region.pockets.is_empty() or region.pockets.size() > 8: return false
	for pocket in region.pockets:
		if not pocket is Dictionary: return false
		for key in ["offset", "axes"]:
			if not pocket.get(key) is Array or pocket[key].size() != 2: return false
		for value in pocket.offset:
			if not _number(value, -16.0, 16.0): return false
		for value in pocket.axes:
			if not _number(value, 0.1, 12.0): return false
		if not _number(pocket.get("angle"), -TAU, TAU): return false
	return true

static func contains(item: Dictionary, location: Array) -> bool:
	if not valid(item) or not Navigation.valid_point(location, false): return false
	var region: Dictionary = item.region
	if absf(float(location[1]) - float(item.position[1])) > float(region.half_height): return false
	var point := Vector2(float(location[0]) - float(item.position[0]), float(location[2]) - float(item.position[2])).rotated(-float(region.angle))
	if region.shape == "belt":
		var radial: float = Vector2(point.x, point.y / float(region.ratio)).length()
		return radial >= float(region.inner) and radial <= float(region.outer)
	for pocket in region.pockets:
		var offset := Vector2(pocket.offset[0], pocket.offset[1])
		var local: Vector2 = (point - offset).rotated(-float(pocket.angle))
		var normalized := Vector2(local.x / float(pocket.axes[0]), local.y / float(pocket.axes[1]))
		if normalized.length_squared() <= 1.0: return true
	return false

# Renderer-only stream, independent of region generation, gameplay and combat.
static func sample(item: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var region: Dictionary = item.region
	var point := Vector2.ZERO
	if region.shape == "belt":
		var angle: float = rng.randf_range(0, TAU)
		# Sparse sectors, never an invisible gameplay hole.
		for attempt in range(8):
			var density: float = 0.18 + 0.82 * pow(absf(sin((angle - float(item.visual.get("gap_angle", 0.0))) * 1.5)), 0.6)
			if rng.randf() <= density: break
			angle = rng.randf_range(0, TAU)
		var radius: float = sqrt(rng.randf_range(pow(float(region.inner), 2), pow(float(region.outer), 2)))
		point = Vector2(cos(angle), sin(angle) * float(region.ratio)) * radius
	else:
		var pocket: Dictionary = region.pockets[rng.randi_range(0, region.pockets.size() - 1)]
		var angle: float = rng.randf_range(0, TAU)
		var radial: float = pow(rng.randf(), 0.7)
		point = (Vector2(cos(angle) * float(pocket.axes[0]), sin(angle) * float(pocket.axes[1])) * radial).rotated(float(pocket.angle))
		point += Vector2(pocket.offset[0], pocket.offset[1])
	point = point.rotated(float(region.angle))
	return Vector3(point.x + float(item.position[0]), float(item.position[1]) + rng.randf_range(-1, 1) * float(region.half_height), point.y + float(item.position[2]))


static func valid_visual(value: Variant) -> bool:
	if not value is Dictionary or not value.get("seed") is String or not value.seed.is_valid_int(): return false
	if not _number(value.get("density"), 0.5, 1.5) or not _number(value.get("gap_angle"), -TAU, TAU): return false
	if not value.get("tint") is Array or value.tint.size() != 3: return false
	for channel in value.tint:
		if not _number(channel, 0.0, 1.0): return false
	return true
