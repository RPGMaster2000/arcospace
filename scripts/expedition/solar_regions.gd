extends RefCounted
## Authoritative stationary stellar influence. No scene state or combat simulation.
const TYPE = "SOLAR_INTERFERENCE"
# menu_sun: half of the 18-unit quad times the opaque core's outer UV radius.
const CORE_RADIUS_PER_SCALE = 1.26
const Navigation = preload("res://scripts/expedition/navigation_state.gd")

static func generate(run_seed: int, number: int, star_position: Array, star_radius: float,
		influence_range: Vector2 = Vector2(8.0, 13.0)) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:solar-interference:v1" % [run_seed, number])
	var low: float = clampf(minf(influence_range.x, influence_range.y), star_radius + 1.0, 63.0)
	var high: float = clampf(maxf(influence_range.x, influence_range.y), low, 64.0)
	var record := {"id": "solar-%d" % number, "type": TYPE,
		"position": star_position.duplicate(), "region": {"shape": "sphere", "radius": rng.randf_range(low, high)},
		"intensity": rng.randf_range(0.55, 0.9),
		"configuration": {"subtype": "stellar_corona", "star_radius": star_radius},
		"visual": {"seed": str(rng.randi()), "activity": rng.randf_range(0.3, 0.85),
			"phase": rng.randf_range(0.0, TAU), "pulse_rate": rng.randf_range(0.35, 0.7)},
		"simulation": {}, "generation": {"version": 1, "run_seed": str(run_seed), "system": number}}
	return JSON.parse_string(JSON.stringify(record))

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high

static func valid(item: Dictionary) -> bool:
	if not Navigation.valid_point(item.get("position"), false): return false
	var region: Variant = item.get("region")
	var config: Variant = item.get("configuration")
	return region is Dictionary and region.get("shape") == "sphere" and _number(region.get("radius"), 1.0, 64.0) and config is Dictionary and _number(config.get("star_radius"), 0.1, 16.0) and float(config.star_radius) < float(region.radius)

static func valid_visual(value: Variant) -> bool:
	return value is Dictionary and value.get("seed") is String and value.seed.is_valid_int() and _number(value.get("activity"), 0.0, 1.0) and _number(value.get("phase"), 0.0, TAU) and _number(value.get("pulse_rate"), 0.1, 2.0)

static func contains(item: Dictionary, location: Array) -> bool:
	if not valid(item) or not Navigation.valid_point(location, false): return false
	var distance_squared := 0.0
	for axis in range(3):
		distance_squared += pow(float(location[axis]) - float(item.position[axis]), 2)
	return distance_squared <= pow(float(item.region.radius), 2)
