extends RefCounted
## Builds compact immutable-by-convention generation records. State owns the result.
## Each feature has its own stream; this module never uses expedition/combat RNG.
const ARCHETYPES = [
	"conventional", "scattered", "crowded", "asymmetric", "unstable", "storm_dominated", "chaotic"
]
const FORMATIONS = ["spread", "clustered", "staggered", "pincer", "vanguard", "unstructured"]
const PALETTE = ["7451b3", "367ba8", "ad485b", "387d75", "686bb4"]
const Settings = preload("res://scripts/expedition/system_variety_settings.gd")


static func rng_for(seed_value: int, number: int, channel: String) -> RandomNumberGenerator:
	var result := RandomNumberGenerator.new()
	result.seed = hash("%d:%d:system-variety:%s:v1" % [seed_value, number, channel])
	return result


static func weighted(rng: RandomNumberGenerator, weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += maxf(0, float(weight))
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= maxf(0, float(weights[i]))
		if roll < 0:
			return i
	return 0


static func generate(seed_value: int, number: int, settings: Resource) -> Dictionary:
	if settings == null or not settings.enabled:
		return {}
	var rng := rng_for(seed_value, number, "layout")
	var weights: Vector4 = settings.layout_weights
	var tier := weighted(rng, [weights.x, weights.y, weights.z, weights.w])
	var archetype: String = "conventional"
	if tier == 1:
		archetype = ["scattered", "crowded", "asymmetric"][rng.randi_range(0, 2)]
	if tier == 2:
		archetype = ["unstable", "storm_dominated"][rng.randi_range(0, 1)]
	if tier == 3:
		archetype = "chaotic"
	var count_rng := rng_for(seed_value, number, "poi-count")
	var count_weights: Vector3 = settings.poi_count_weights
	var band: Vector2i = [
		settings.common_poi_range, settings.sparse_poi_range, settings.dense_poi_range
	][weighted(count_rng, [count_weights.x, count_weights.y, count_weights.z])]
	var environment_rng := rng_for(seed_value, number, "environment-profile")
	var intensity := weighted(environment_rng, [55, 33, 12])
	if archetype in ["unstable", "storm_dominated"]:
		intensity = 2
	var solar: Vector2 = (
		settings.solar_radius_ranges[mini(intensity, settings.solar_radius_ranges.size() - 1)]
		if not settings.solar_radius_ranges.is_empty()
		else Vector2(8, 13)
	)
	var storm: Vector2 = (
		settings.storm_extent_ranges[mini(intensity, settings.storm_extent_ranges.size() - 1)]
		if not settings.storm_extent_ranges.is_empty()
		else Vector2(5, 7)
	)
	solar = Vector2(clampf(minf(solar.x, solar.y), 1, 24), clampf(maxf(solar.x, solar.y), 1, 24))
	storm = Vector2(clampf(minf(storm.x, storm.y), 1, 18), clampf(maxf(storm.x, storm.y), 1, 18))
	var formation_rng := rng_for(seed_value, number, "formation")
	var stars_rng := rng_for(seed_value, number, "companion")
	var companion := {}
	if stars_rng.randf() < settings.binary_chance:
		var angle := stars_rng.randf_range(0, TAU)
		companion = {
			"position": [cos(angle) * 2.8, 0.0, sin(angle) * 2.8],
			"radius": stars_rng.randf_range(0.3, 0.48),
			"color": ["a7dfff", "ffc278", "ff8674", "fff0bd"][stars_rng.randi_range(0, 3)]
		}
	var background_rng := rng_for(seed_value, number, "background")
	var background: Array = []
	if background_rng.randf() < settings.background_chance:
		for i in background_rng.randi_range(1, 3):
			background.append(_layer(background_rng, background_rng.randi_range(0, 3)))
	if background_rng.randf() < settings.quasar_chance:
		background.append(_layer(background_rng, 4))
	var profile := {
		"version": 1,
		"archetype": archetype,
		"tier": tier,
		"axis": rng.randf_range(0, TAU),
		"poi_count":
		count_rng.randi_range(clampi(band.x, 3, 12), clampi(maxi(band.x, band.y), 3, 12)),
		"formation": FORMATIONS[formation_rng.randi_range(0, FORMATIONS.size() - 1)],
		"intensity": intensity,
		"solar_range": [solar.x, solar.y],
		"storm_range": [storm.x, storm.y],
		"storm_count": environment_rng.randi_range(1, 2) if intensity == 2 else 1,
		"minimum_arrival": clampf(settings.minimum_arrival_seconds, 10, 40),
		"companion": companion,
		"background": background
	}

	# Canonical wire numbers/keys make fresh-process saves byte-stable.
	return JSON.parse_string(JSON.stringify(profile))


const SIZE_CLASSES := ["Compact", "Standard", "Expansive"]
const HOME_REGIONS := ["Inner Habitable", "Middle Orbit", "Outer Frontier"]
const SIZE_RANGES := [Vector2(0.85, 0.95), Vector2(0.95, 1.10), Vector2(1.10, 1.25)]
const HOME_RANGES := [Vector2(0.70, 0.85), Vector2(0.85, 1.05), Vector2(1.05, 1.20)]
const SIZE_WEIGHTS := [[15, 70, 15], [5, 25, 70], [70, 25, 5], [30, 40, 30],
	[15, 50, 35], [10, 50, 40], [30, 35, 35]]
const HOME_WEIGHTS := [[20, 60, 20], [15, 35, 50], [50, 40, 10], [34, 32, 34],
	[25, 50, 25], [25, 45, 30], [34, 32, 34]]
# Radius, light energy, corona strength and color are paired as stellar classes.
const STARS := [
	["Cool Dwarf", 0.75, 0.75, 0.78, "ffbe91"],
	["Main Sequence", 1.0, 1.0, 1.0, "fff1cc"],
	["Luminous Star", 1.35, 1.22, 1.18, "fff7d8"],
	["Blue-white Star", 1.14, 1.12, 1.10, "b3d9ff"],
	["Orange Star", 0.92, 0.88, 0.92, "ff9861"],
]


static func later(profile: Dictionary, seed_value: int, system: int, settings: Resource,
		previous: String, overrides: Dictionary) -> Dictionary:
	if profile.is_empty() or system < 3 or not settings.progressive_geometry: return profile
	var rng := rng_for(seed_value, system, "environment-geometry")
	var stage := mini(system - 3, 2)
	var stage_weights: Vector4 = settings.later_layout_weights[stage] if stage < settings.later_layout_weights.size() else Vector4(10, 35, 35, 20)
	var weights := [stage_weights.x, stage_weights.y / 3, stage_weights.y / 3, stage_weights.y / 3,
		stage_weights.z * 0.5, stage_weights.z * 0.5, stage_weights.w]
	var prior := ARCHETYPES.find(previous)
	if prior >= 0 and weights.any(func(weight): return weight > 0.0) and float(weights[prior]) < stage_weights.dot(Vector4.ONE):
		weights[prior] = 0.0
	var archetype := overrides.get("environment", "") as String
	var index := ARCHETYPES.find(archetype)
	if index < 0: index = weighted(rng, weights)
	archetype = ARCHETYPES[index]
	var size := SIZE_CLASSES.find(overrides.get("size_class", ""))
	if size < 0: size = weighted(rng, SIZE_WEIGHTS[index])
	var region := HOME_REGIONS.find(overrides.get("home_region", ""))
	if region < 0: region = weighted(rng, HOME_WEIGHTS[index])
	var scale: Vector2 = SIZE_RANGES[size]
	var radial: Vector2 = HOME_RANGES[region]
	var colors := rng_for(seed_value, system, "stellar-appearance")
	var star := colors.randi_range(0, STARS.size() - 1)
	var companion := {}
	var binary := int(overrides.get("binary", -1))
	if binary == 1 or (binary < 0 and colors.randf() < settings.later_binary_chances[stage]):
		var angle := colors.randf_range(0, TAU)
		var separation := colors.randf_range(3.25, 4.6)
		var tint := ["a7dfff", "ffc278", "ff8674", "fff0bd"]
		companion = {"position":[cos(angle) * separation, 0.0, sin(angle) * separation],
			"radius":colors.randf_range(0.31, 0.58), "color":tint[(star + colors.randi_range(1, 3)) % 4]}
	var density: Vector3 = settings.later_density_weights[index] if index < settings.later_density_weights.size() else Vector3(15, 70, 15)
	var band: Vector2i = [settings.sparse_poi_range, settings.common_poi_range, settings.dense_poi_range][weighted(rng, [density.x, density.y, density.z])]
	profile.merge({"version":2, "archetype":archetype, "tier":[0, 1, 1, 1, 2, 2, 3][index],
		"poi_count":rng.randi_range(clampi(band.x, 3, 12), clampi(maxi(band.x, band.y), 3, 12)),
		"companion":companion, "size_class":size, "home_region":region, "geometry_scale":rng.randf_range(scale.x, scale.y),
		"home_scale":rng.randf_range(radial.x, radial.y), "star":star, "planet_scales":{}, "planet_types":{}, "placement_attempt":0,
		"military_fallback":false}, true)
	var intensity_bias: Array = [[72, 24, 4], [60, 32, 8], [60, 34, 6],
		[40, 47, 13], [5, 42, 53], [0, 0, 100], [25, 35, 40]][index]
	profile.intensity = weighted(rng, intensity_bias)
	profile.solar_range = _valid_band(settings.solar_radius_ranges, int(profile.intensity), Vector2(8, 13), 24)
	profile.storm_range = _valid_band(settings.storm_extent_ranges, int(profile.intensity), Vector2(5, 7), 18)
	profile.storm_count = 1
	if archetype == "storm_dominated":
		profile.storm_count = 2
		profile.storm_range = [9, 15]
	elif archetype == "unstable":
		profile.storm_count = 1
		profile.storm_range = [6, 11]
	elif archetype == "chaotic":
		profile.storm_count = rng.randi_range(1, 2)
	var tint: String = PALETTE[[2, 1, 4, 1, 0, 3, 2][index]]
	for layer in profile.background:
		if layer.kind != 4: layer.color = tint
	return canonical(profile)


static func _valid_band(bands: Array[Vector2], index: int, fallback: Vector2, ceiling: float) -> Array:
	var band := fallback if bands.is_empty() else bands[mini(index, bands.size() - 1)]
	return [clampf(minf(band.x, band.y), 1, ceiling), clampf(maxf(band.x, band.y), 1, ceiling)]


static func canonical(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))


static func star_radius(profile: Dictionary, baseline: float) -> float:
	return baseline * float(STARS[int(profile.star)][1]) if profile.get("version") == 2 else baseline


static func system_title(profile: Dictionary) -> String:
	if profile.is_empty(): return ""
	return str(profile.archetype).replace("_", " ").capitalize()


static func _layer(rng: RandomNumberGenerator, kind: int) -> Dictionary:
	return {
		"kind": kind,
		"color": PALETTE[rng.randi_range(0, PALETTE.size() - 1)],
		"size": [rng.randf_range(25, 60), rng.randf_range(16, 38)],
		"yaw": rng.randf_range(PI - (0.3 if kind == 4 else 0.7), PI + (0.3 if kind == 4 else 0.7)),
		"pitch": rng.randf_range(-0.8 if kind == 4 else -1.05, -0.3 if kind == 4 else -0.2),
		"rotation": rng.randf_range(0, TAU),
		"opacity": rng.randf_range(0.20, 0.38),
		"variation": rng.randf_range(0, 99)
	}


static func number(value: Variant, low: float, high: float) -> bool:
	return (
		(value is float or value is int)
		and is_finite(float(value))
		and value >= low
		and value <= high
	)


static func valid(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.is_empty():
		return true  # Historical systems have no variety profile.
	if (
		(value.get("version") != 1 and value.get("version") != 2)
		or value.get("archetype") not in ARCHETYPES
		or value.get("formation") not in FORMATIONS
	):
		return false
	for key in ["tier", "intensity", "poi_count", "storm_count"]:
		if not number(value.get(key), 0, 12) or float(value[key]) != floor(float(value[key])):
			return false
	if (
		value.tier > 3
		or value.intensity > 2
		or value.poi_count < 3
		or value.storm_count < 1
		or value.storm_count > 2
	):
		return false
	if not number(value.get("axis"), 0, TAU) or not number(value.get("minimum_arrival"), 10, 40):
		return false
	for key in ["solar_range", "storm_range"]:
		var band: Variant = value.get(key)
		if (
			not band is Array
			or band.size() != 2
			or not number(band[0], 1, 24)
			or not number(band[1], band[0], 24)
		):
			return false
	var companion: Variant = value.get("companion")
	if not companion is Dictionary:
		return false
	if not companion.is_empty():
		if not preload("res://scripts/expedition/navigation_state.gd").valid_point(
			companion.get("position"), false
		):
			return false
		if (
			not number(companion.get("radius"), 0.2, 0.6)
			or companion.get("color") not in ["a7dfff", "ffc278", "ff8674", "fff0bd"]
		):
			return false
		var at := Vector3(companion.position[0], companion.position[1], companion.position[2])
		var allowed := Vector2(3.24, 4.61) if value.version == 2 else Vector2(2.799, 2.801)
		if absf(at.y) > 0.001 or not number(at.length(), allowed.x, allowed.y):
			return false
	var layers: Variant = value.get("background")
	if not layers is Array or layers.size() > 4:
		return false
	for layer in layers:
		if (
			not layer is Dictionary
			or not number(layer.get("kind"), 0, 4)
			or layer.kind != floor(float(layer.kind))
			or layer.get("color") not in PALETTE
		):
			return false
		if not layer.get("size") is Array or layer.size.size() != 2:
			return false
		for dimension in layer.size:
			if not number(dimension, 10, 64):
				return false
		for key in ["yaw", "pitch", "rotation", "variation"]:
			if not number(layer.get(key), -PI, 100):
				return false
		if not number(layer.get("opacity"), 0, 0.4):
			return false
	if value.version == 2:
		for key in ["size_class", "home_region", "star", "placement_attempt"]:
			if not number(value.get(key), 0.0, {"star":4, "placement_attempt":16}.get(key, 2)) or int(value[key]) != value[key]:
				return false
		var size: Vector2 = SIZE_RANGES[int(value.size_class)]
		var home: Vector2 = HOME_RANGES[int(value.home_region)]
		if not number(value.get("geometry_scale"), size.x - 0.00001, size.y + 0.00001) \
			or not number(value.get("home_scale"), home.x - 0.00001, home.y + 0.00001):
			return false
		if not value.get("planet_scales") is Dictionary or value.planet_scales.size() > 12 or not value.get("military_fallback") is bool:
			return false
		if not value.get("planet_types") is Dictionary or value.planet_types.size() != value.planet_scales.size(): return false
		for key in value.planet_scales:
			if value.planet_types.get(key) not in ["rocky", "terrestrial", "gas_giant", "frozen"]: return false
			if not str(key).is_valid_int() or not number(value.planet_scales[key], 0.84999, 1.20001):
				return false
	return true
