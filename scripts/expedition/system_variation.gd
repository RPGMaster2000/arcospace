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
		value.get("version") != 1
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
		if absf(at.y) > 0.001 or absf(at.length() - 2.8) > 0.001:
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
	return true
