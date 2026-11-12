extends RefCounted
## Scene-free generation and geometry. ExpeditionState owns the returned records.
## These constants affect new systems only; saves retain their compact definitions.
const TYPE = "ASTEROID_FIELD"
const BELT_WIDTH = Vector2(2.6, 4.4)
const BELT_RADIUS = Vector2(7.0, 21.0)
const SYSTEM_RADIUS = 27.0
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")

static func generate(run_seed: int, number: int, battle_positions: Array, expansion: float = 0.0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:asteroid-regions:v1" % [run_seed, number])
	var item: Dictionary = _record(run_seed, number, 0, rng)
	var kind: int = rng.randi_range(0, 2)
	var angle: float = rng.randf_range(0, TAU)
	var anchor := Vector2.RIGHT * rng.randf_range(8.0, 18.0)
	if not battle_positions.is_empty():
		var at: Array = battle_positions[rng.randi_range(0, battle_positions.size() - 1)]
		anchor = Vector2(float(at[0]), float(at[2]))
	else:
		anchor = anchor.rotated(rng.randf_range(0, TAU))
	if kind == 0:
		var ratio: float = rng.randf_range(0.84, 1.0)
		var local := anchor.rotated(-angle)
		var radius: float = clampf(Vector2(local.x, local.y / ratio).length(), BELT_RADIUS.x, BELT_RADIUS.y)
		var width: float = rng.randf_range(BELT_WIDTH.x, BELT_WIDTH.y)
		item.region = {"shape": "belt", "inner": radius - width * 0.5,
			"outer": radius + width * 0.5, "ratio": ratio, "angle": angle,
			"half_height": rng.randf_range(0.45, 0.9)}
		item.configuration.subtype = "belt"
		# Orbital arcs are visual thinning only; authoritative annulus stays intact.
		item.visual["arc_fraction"] = rng.randf_range(0.55, 1.0) if rng.randf() < 0.6 else 1.0
	else:
		item.configuration.subtype = "concentration" if kind == 1 else "extended"
		item.position = [anchor.x, 0.0, anchor.y]
		# Tangential collision remnants, curved along the local orbital direction.
		angle = anchor.angle() + PI * 0.5 + rng.randf_range(-0.35, 0.35)
		var extent: float = rng.randf_range(1.8, 3.0) if kind == 1 else rng.randf_range(3.6, 5.2)
		# Bound the debris at outer anchors without relocating the formation.
		extent = minf(extent, maxf(1.4, (SYSTEM_RADIUS - anchor.length() / Layout.scale_factor(expansion)) / 2.0))
		if expansion > 0.0:
			# Place the whole formation inside the map while retaining the
			# sampled pocket sizes and their tangential arrangement.
			var bounds := Layout.bounds(expansion).grow(-extent * 2.35)
			anchor = anchor.clamp(bounds.position, bounds.end)
			item.position = [anchor.x, 0.0, anchor.y]
		var pockets: Array = []
		var count: int = 3 if kind == 1 else 7
		var curve: float = rng.randf_range(0.15, 0.4)
		for pocket in range(count):
			var t: float = (float(pocket) / (count - 1) - 0.5) * 2.0
			pockets.append({"offset": [t * extent * 1.4, t * t * extent * curve],
				"axes": [extent * rng.randf_range(0.6, 0.85), extent * rng.randf_range(0.25, 0.45)],
				"angle": t * curve})
		item.region = {"shape": "pockets", "angle": angle,
			"half_height": rng.randf_range(0.4, 0.85), "pockets": pockets}
	item.generation.version = 2
	# Match persisted precision before first use, not only after resuming.
	return JSON.parse_string(JSON.stringify([item]))

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
		var fraction: float = float(item.visual.get("arc_fraction", 1.0))
		var start: float = float(item.visual.get("gap_angle", 0.0))
		var angle: float = start + rng.randf_range(0, TAU * fraction)
		# Sparse sectors, never an invisible gameplay hole.
		for attempt in range(8):
			var density: float = 0.18 + 0.82 * pow(absf(sin((angle - float(item.visual.get("gap_angle", 0.0))) * 1.5)), 0.6)
			if rng.randf() <= density: break
			angle = start + rng.randf_range(0, TAU * fraction)
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
	if value.has("arc_fraction") and not _number(value.arc_fraction, 0.5, 1.0): return false
	if not value.get("tint") is Array or value.tint.size() != 3: return false
	for channel in value.tint:
		if not _number(channel, 0.0, 1.0): return false
	return true
