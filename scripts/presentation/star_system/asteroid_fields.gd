extends RefCounted
## Stateless renderer of authoritative region records. No colliders, input nodes,
## simulation or saved mesh transforms. Android changes counts, never geometry.
const Regions = preload("res://scripts/expedition/asteroid_regions.gd")
const BELT_COUNT = 1100
const LOCAL_COUNT = 180
const ANDROID_BELT_COUNT = 440
const ANDROID_LOCAL_COUNT = 72

static func build(instances: Array, mobile: bool = OS.has_feature("android")) -> Node3D:
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
		var rng := RandomNumberGenerator.new()
		rng.seed = int(item.visual.get("seed", "0"))
		var belt: bool = item.region.shape == "belt"
		var base_count: int = (ANDROID_BELT_COUNT if mobile else BELT_COUNT) if belt else (ANDROID_LOCAL_COUNT if mobile else LOCAL_COUNT)
		var density: float = clampf(float(item.visual.get("density", 1.0)), 0.5, 1.5)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		multimesh.instance_count = roundi(base_count * density)
		for index in range(multimesh.instance_count):
			var at: Vector3 = Regions.sample(item, rng)
			var size: float = rng.randf_range(0.07, 0.20)
			var rotation := Basis.from_euler(Vector3(rng.randf_range(0, TAU), rng.randf_range(0, TAU), rng.randf_range(0, TAU)))
			var scale := Vector3(size * rng.randf_range(0.65, 1.4), size * rng.randf_range(0.55, 1.1), size * rng.randf_range(0.7, 1.3))
			multimesh.set_instance_transform(index, Transform3D(rotation.scaled_local(scale), at))
			var shade: float = rng.randf_range(0.7, 1.3)
			var tint: Array = item.visual.get("tint", [0.46, 0.39, 0.32])
			var color := Color(0.46, 0.39, 0.32)
			if tint.size() == 3: color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
			multimesh.set_instance_color(index, Color(color.r * shade, color.g * shade, color.b * shade))
		var field := MultiMeshInstance3D.new()
		field.name = item.id
		field.multimesh = multimesh
		field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(field)
	return root
