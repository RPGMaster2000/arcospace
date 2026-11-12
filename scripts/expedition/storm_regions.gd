extends RefCounted

const TYPE = "SPACE_STORM"
const SUBTYPES = ["ion", "metal", "psionic"]
const MODIFIER_IDS = {"ion": 2, "metal": 6, "psionic": 7}
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
const Solar = preload("res://scripts/expedition/solar_regions.gd")
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")

static func modifier_id(subtype: Variant) -> int:
	return MODIFIER_IDS.get(subtype, 0) if subtype is String else 0

static func generate(run_seed: int, system: int, chance: float, hostile_positions: Array,
		existing: Array, expansion: float = 0.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:space-storm:v1" % [run_seed, system])
	var roll := rng.randf()
	if chance <= 0.0 or (chance < 1.0 and roll >= chance): return {}
	var subtype: String = SUBTYPES[rng.randi_range(0, SUBTYPES.size() - 1)]
	var axes := Vector3(rng.randf_range(5.0, 7.5), rng.randf_range(2.4, 3.5),
		rng.randf_range(4.5, 7.0))
	var limit := Layout.bounds(expansion).end.x
	var candidates: Array[Vector3] = []
	for location in hostile_positions:
		if not Navigation.valid_point(location, false): continue
		if absf(float(location[1])) > axes.y: continue
		var point := Vector3(location[0], 0.0, location[2])
		if point.length() < 12.0 or absf(point.x) + axes.x > limit or absf(point.z) + axes.z > limit: continue
		if existing.any(func(item): return _covers_with_priority(item, location)): continue
		candidates.append(point)
	var center: Vector3
	if candidates.is_empty():
		var angle := rng.randf_range(0.0, TAU)
		center = Vector3(cos(angle), 0.0, sin(angle)) * (rng.randf_range(15.0, 19.0) * Layout.scale_factor(expansion))
	else:
		center = candidates[rng.randi_range(0, candidates.size() - 1)]
	var record := {"id": "storm-%d" % system, "type": TYPE,
		"position": [center.x, center.y, center.z],
		"region": {"shape": "ellipsoid", "axes": [axes.x, axes.y, axes.z]},
		"intensity": rng.randf_range(0.68, 0.88), "configuration": {"subtype": subtype},
		"visual": {"color": Modifiers.storm_color(modifier_id(subtype)).to_html(false),
			"phase": rng.randf_range(0.0, TAU)},
		"simulation": {},
		"generation": {"version": 1, "seed": str(rng.seed), "run_seed": str(run_seed), "system": system}}
	return JSON.parse_string(JSON.stringify(record))

static func _covers_with_priority(item: Dictionary, location: Array) -> bool:
	match item.get("type"):
		Solar.TYPE: return Solar.contains(item, location)
		Asteroids.TYPE: return Asteroids.contains(item, location)
	return false

static func valid(item: Dictionary) -> bool:
	if not Navigation.valid_point(item.get("position"), false): return false
	var region: Variant = item.get("region")
	if not region is Dictionary or region.get("shape") != "ellipsoid": return false
	var axes: Variant = region.get("axes")
	if not Navigation.valid_point(axes, false): return false
	for extent in axes:
		if extent < 1.0 or extent > 9.0: return false
	var configuration: Variant = item.get("configuration")
	return configuration is Dictionary and modifier_id(configuration.get("subtype")) != 0

static func valid_visual(value: Variant, subtype: Variant) -> bool:
	var selection := modifier_id(subtype)
	if selection == 0 or not value is Dictionary: return false
	var phase: Variant = value.get("phase")
	return value.get("color") == Modifiers.storm_color(selection).to_html(false) \
		and (phase is float or phase is int) and is_finite(float(phase)) and phase >= 0.0 and phase <= TAU

static func valid_generation(value: Dictionary) -> bool:
	var seed_value: Variant = value.get("seed")
	return value.get("version") == 1 and seed_value is String and seed_value.is_valid_int()

static func contains(item: Dictionary, location: Array) -> bool:
	if not valid(item) or not Navigation.valid_point(location, false): return false
	var distance_squared := 0.0
	for axis in range(3):
		var normalized := (float(location[axis]) - float(item.position[axis])) / float(item.region.axes[axis])
		distance_squared += normalized * normalized
	return distance_squared <= 1.0
