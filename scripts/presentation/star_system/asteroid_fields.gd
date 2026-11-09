extends RefCounted
## Stateless renderer of authoritative region records. No colliders, input nodes,
## simulation or saved mesh transforms. Android changes counts, never geometry.
const Regions = preload("res://scripts/expedition/asteroid_regions.gd")
const BELT_COUNT = 1100
const LOCAL_COUNT = 340
const ANDROID_BELT_COUNT = 440
const ANDROID_LOCAL_COUNT = 136
const EXTENDED_COUNT = 620
const ANDROID_EXTENDED_COUNT = 248

static func build(instances: Array, mobile: bool = OS.has_feature("android"), exclusions: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = "AsteroidFields"
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 1.0
	mesh.material = material
	for item in instances:
		if not item is Dictionary or item.get("type") != Regions.TYPE or not Regions.valid(item) or not Regions.valid_visual(item.get("visual")): continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		var layout: Array = sample_layout(item, mobile, exclusions)
		multimesh.instance_count = layout.size()
		for index in range(layout.size()):
			multimesh.set_instance_transform(index, layout[index].transform)
			multimesh.set_instance_color(index, layout[index].color)
		var field := MultiMeshInstance3D.new()
		field.name = item.id
		field.multimesh = multimesh
		field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(field)
	return root


# CPU layout is also testable with Godot's headless dummy rendering server.
static func sample_layout(item: Dictionary, mobile: bool, exclusions: Array = []) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(item.visual.seed)
	var belt: bool = item.region.shape == "belt"
	var base_count: int = (ANDROID_BELT_COUNT if mobile else BELT_COUNT) if belt else (ANDROID_LOCAL_COUNT if mobile else LOCAL_COUNT)
	if item.configuration.get("subtype") == "extended": base_count = ANDROID_EXTENDED_COUNT if mobile else EXTENDED_COUNT
	var density: float = clampf(float(item.visual.density), 0.5, 1.5)
	var layout: Array = []
	for index in range(roundi(base_count * density)):
		var at: Vector3 = Regions.sample(item, rng)
		var size: float = rng.randf_range(0.045, 0.125)
		var rotation := Basis.from_euler(Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU)))
		var scale := Vector3(size * rng.randf_range(0.65, 1.4), size * rng.randf_range(0.55, 1.1), size * rng.randf_range(0.7, 1.3))
		var shade: float = rng.randf_range(0.7, 1.3)
		var tint: Array = item.visual.tint
		var color := Color(float(tint[0]) * shade, float(tint[1]) * shade, float(tint[2]) * shade)
		# Sphere bounds include every rotated mesh vertex. Rejection never changes
		# subsequent samples or containment, and Android retains a desktop prefix.
		if not clear_position(at, maxf(scale.x, maxf(scale.y, scale.z)), exclusions): continue
		layout.append({"transform": Transform3D(rotation.scaled_local(scale), at), "color": color})
	return layout


static func clear_position(at: Vector3, radius: float, exclusions: Array) -> bool:
	for body in exclusions:
		if at.distance_squared_to(body.position) <= pow(float(body.radius) + radius + 0.22, 2): return false
	return true
