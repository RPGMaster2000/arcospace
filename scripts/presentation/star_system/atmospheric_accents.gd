extends RefCounted
## Stateless presentation recipe; never writes expedition/layout/environment records.
## Versioned independent channels reconstruct accents from the existing system seed.
const Visual = preload("res://scripts/presentation/star_system/visual_system.gd")
const Meshes = preload("res://scripts/presentation/environment_meshes.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
const PANORAMAS = {
	"nebula":
	"res://third_party/willosuna_space/nebula_rose_blue/nebula_rose_blue_panorama_4096.jpg",
	"galaxy":
	"res://third_party/willosuna_space/galaxy_spiral_blue/galaxy_spiral_blue_panorama_4096.jpg",
	"anomaly": "res://third_party/willosuna_space/black_hole_gold/black_hole_gold_panorama_4096.jpg"
}


static func recipe(
	seed_value: int,
	number: int,
	data: Dictionary,
	variation: Dictionary,
	settings: Resource,
	expansion: float,
	environments: Array = [],
	exclusions: Array = []
) -> Dictionary:
	var result := {"kind": "quiet", "rocks": [], "moon": {}, "sky": {}}
	if settings == null or not settings.enabled:
		return result
	var rng := Visual.random_for(seed_value, number, "atmospheric-accents-v1")
	# Existing conspicuous skies, twin suns and dense/dominant systems get less.
	var busy: bool = (
		not variation.get("companion", {}).is_empty()
		or variation.get("intensity", 0) == 2
		or variation.get("archetype", "") in ["crowded", "storm_dominated", "chaotic"]
		or variation.get("background", []).size() >= 2
	)
	for item in environments:
		if item.get("type") == "SOLAR_INTERFERENCE" and float(item.get("region", {}).get("radius", 0)) >= 12.0:
			busy = true
	var budget: float = settings.busy_system_multiplier if busy else 1.0
	var roll := rng.randf()
	var cursor := 0.0
	for choice in [
		["panorama", settings.panorama_chance],
		["rocks", settings.rocks_chance],
		["moon", settings.moon_chance],
		["anomaly", settings.anomaly_chance]
	]:
		cursor += clampf(float(choice[1]), 0, 1) * budget
		if roll < cursor:
			result.kind = choice[0]
			break
	if result.kind in ["panorama", "anomaly"]:
		# Never compete with an existing quasar or multiple background landmarks.
		if (
			variation.get("background", []).size() >= 2
			or variation.get("background", []).any(func(layer): return layer.kind == 4)
		):
			result.kind = "quiet"
			return result
		var kind: String = (
			"anomaly"
			if result.kind == "anomaly"
			else ("nebula" if rng.randf() < 0.65 else "galaxy")
		)
		result.sky = {
			"asset": kind,
			"yaw": rng.randf_range(0.12, 0.22) * (-1 if rng.randf() < 0.5 else 1),
			"pitch": rng.randf_range(0.04, 0.11),
			"roll": rng.randf_range(-0.3, 0.3),
			"extent": 0.08 if kind == "anomaly" else (0.14 if kind == "galaxy" else 0.18),
			"opacity": settings.image_opacity * (0.65 if busy else 1.0),
			"brightness": settings.image_brightness
		}
	elif result.kind == "rocks":
		var bounds := Layout.bounds(expansion)
		var angle := rng.randf_range(0, TAU)
		var direction := Vector3(cos(angle), 0, sin(angle))
		# Scenery beyond the navigable rectangle cannot imply a new combat region.
		var distance := (
			minf(
				absf(bounds.end.x / maxf(absf(direction.x), 0.001)),
				absf(bounds.end.y / maxf(absf(direction.z), 0.001))
			)
			+ 3.0
		)
		var center := direction * distance + Vector3.DOWN * 2.5
		for i in settings.rock_count:
			var size := rng.randf_range(0.12, 0.35)
			var at := (
				center
				+ Vector3(
					rng.randf_range(-1, 1), rng.randf_range(-0.6, 0.6), rng.randf_range(-1, 1)
				)
			)
			var rotation := Basis.from_euler(
				Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
			)
			if not (
				preload("res://scripts/presentation/star_system/asteroid_fields.gd")
				. clear_position(at, size * 1.2 + 1.0, exclusions)
			):
				continue
			result.rocks.append(
				Transform3D(rotation.scaled_local(Vector3(size, size * 0.7, size * 1.2)), at)
			)
		if result.rocks.is_empty():
			result.kind = "quiet"
	elif result.kind == "moon":
		# No interactive moon or ring is added; use one unassigned planet only.
		var candidates: Array = data.planets.filter(func(p): return p.encounter == -1)
		if candidates.is_empty():
			result.kind = "quiet"
		else:
			var planet: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
			result.moon = {
				"planet": planet.index,
				"radius": planet.radius * 0.19,
				"offset": Vector3(planet.radius * 1.65, planet.radius * 0.12, planet.radius * 0.3)
			}
			var at: Vector3 = planet.position + result.moon.offset * 1.5
			for other in exclusions:
				if other.position.is_equal_approx(planet.position):
					continue
				if (
					at.distance_to(other.position)
					< float(other.radius) + result.moon.radius * 1.5 + 1.0
				):
					result.moon = {}
					result.kind = "quiet"
					break
	return result


static func build_world(
	plan: Dictionary,
	root: Node3D,
	planets: Dictionary,
	settings: Resource,
	lighting: Resource,
	mobile: bool = OS.has_feature("android")
) -> Array[Node3D]:
	var nodes: Array[Node3D] = []
	if not plan.rocks.is_empty():
		var transforms: Array[Transform3D] = []
		for transform in plan.rocks:
			transforms.append(transform)
		var material := Meshes.material(Color("34383f"))
		var field := Meshes.instances(
			root,
			"AtmosphericRockAccent",
			Meshes.rock(),
			material,
			transforms,
			settings.android_fraction if mobile else 1.0
		)
		nodes.append(field)
	if not plan.moon.is_empty() and planets.has(plan.moon.planet):
		# Child of the real planet: follows its existing orbit, with no update loop.
		var moon := SphereMesh.new()
		moon.radius = plan.moon.radius
		moon.height = moon.radius * 2
		moon.radial_segments = 16
		moon.rings = 8
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/planet_surface.gdshader")
		material.set_shader_parameter("ocean_color", Color("393e48"))
		material.set_shader_parameter("land_color", Color("5b6069"))
		material.set_shader_parameter("rim_intensity", 0.0)
		preload("res://scripts/presentation/star_system/stellar_lighting.gd").shader(
			material, lighting
		)
		nodes.append(
			Meshes.part(
				planets[plan.moon.planet], "AtmosphericMoonAccent", moon, plan.moon.offset, material
			)
		)
	return nodes
