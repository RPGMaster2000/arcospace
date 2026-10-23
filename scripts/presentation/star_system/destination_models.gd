extends RefCounted
# Replace these primitive assemblies later without changing navigation or encounter data.
static func part(parent: Node3D, mesh: Mesh, color: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.75
	node.material_override = material
	parent.add_child(node)
	return node

static func ship(profile: Resource) -> Node3D:
	var mount := Node3D.new()
	if profile != null and profile.model_scene != null:
		var model: Node3D = profile.model_scene.instantiate()
		mount.add_child(model)
		model.ready.connect(func():
			if model.has_method("set_hull_color"):
				model.set_hull_color(profile.hull_color)
			if model.has_method("set_hull_strength"):
				model.set_hull_strength(profile.hull_capacity)
			model.set_process(false)
			for node in model.find_children("*", "Light3D", true, false):
				node.hide()
			var shield := model.get_node_or_null("Shield")
			if shield != null:
				shield.hide()
		)
	else:
		push_warning("Star map: missing ship model; using a primitive placeholder")
		var mesh := PrismMesh.new()
		mesh.size = Vector3(2.5, 0.5, 1)
		part(mount, mesh, Color.SLATE_GRAY)
	return mount

static func build(entry: Dictionary, rng: RandomNumberGenerator) -> Node3D:
	if entry.get("profile") != null:
		var model := ship(entry.profile)
		model.scale = Vector3.ONE * 0.55
		return model
	var root := Node3D.new()
	var key: String = entry.get("model_kind", "planet")
	var color := Color.from_hsv(rng.randf(), 0.38, 0.72)
	if key in ["mining_operation", "derelict_starship", "pirate_debris_field"]:
		for i in range(6):
			var mesh := BoxMesh.new()
			mesh.size = Vector3.ONE * rng.randf_range(0.35, 0.85)
			var rock := part(root, mesh, color, Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(-0.4, 0.4), rng.randf_range(-1.0, 1.0)))
			rock.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * PI
	elif key in ["research_station", "trading_outpost", "distress_signal", "quarantined_colony"]:
		var hub := CylinderMesh.new()
		hub.top_radius = 0.6
		hub.bottom_radius = 0.6
		hub.height = 1.6
		hub.radial_segments = 12
		part(root, hub, color)
		for side in [-1, 1]:
			var wing := BoxMesh.new()
			wing.size = Vector3(1.7, 0.3, 0.8)
			part(root, wing, color.lightened(0.2), Vector3(side * 1.2, 0, 0))
		var antenna := CylinderMesh.new()
		antenna.top_radius = 0.04
		antenna.bottom_radius = 0.08
		antenna.height = 1.5
		antenna.radial_segments = 6
		part(root, antenna, color, Vector3(0, 1.2, 0))
	else:
		var sphere := SphereMesh.new()
		sphere.radius = rng.randf_range(0.85, 1.25)
		sphere.height = sphere.radius * 2
		sphere.radial_segments = 24
		sphere.rings = 12
		var planet := part(root, sphere, color)
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/planet_surface.gdshader")
		material.set_shader_parameter("ocean_color", color.darkened(0.45))
		material.set_shader_parameter("land_color", color)
		material.set_shader_parameter("ambient_visibility", 0.25)
		planet.material_override = material
	return root
