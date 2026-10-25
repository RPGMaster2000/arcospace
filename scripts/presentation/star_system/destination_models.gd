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


static func beacon(parent: Node3D, at: Vector3, color: Color, size: float = 0.12) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size*2
	mesh.radial_segments = 8
	mesh.rings = 4
	var lamp := part(parent,mesh,color,at)
	lamp.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp.material_override.emission_enabled = true
	lamp.material_override.emission = color

static func ship(profile: Resource) -> Node3D:
	var mount := Node3D.new()
	if profile != null:
		# Standard enemies use the same legacy hull as the battlefield; variants provide model_scene.
		var scene: PackedScene = (
			profile.model_scene if profile.model_scene != null
			else preload("res://scenes/ship_3d.tscn")
		)
		var model: Node3D = scene.instantiate()
		mount.add_child(model)
		model.ready.connect(func():
			if model.has_method("set_hull_color"):
				model.set_hull_color(profile.hull_color.lightened(0.12))
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
	beacon(mount,Vector3(-1.2,0,0.25),Color("5edbff"),0.2)
	beacon(mount,Vector3(-1.2,0,-0.25),Color("5edbff"),0.2)
	return mount


static func ring(parent: Node3D, radius: float, tint: Color, at := Vector3.ZERO) -> MeshInstance3D:
	var mesh = TorusMesh.new()
	mesh.inner_radius = radius*0.88
	mesh.outer_radius = radius
	mesh.rings = 24
	mesh.ring_segments = 8
	return part(parent, mesh, tint, at)

static func build(entry: Dictionary, rng: RandomNumberGenerator, replacement: PackedScene = null) -> Node3D:
	if entry.get("profile") != null:
		var model := ship(entry.profile)
		model.scale = Vector3.ONE*0.55
		return model
	if replacement != null:
		return replacement.instantiate()
	var root = Node3D.new()
	var key: String = entry.get("model_kind", "research_station")
	var color = Color.from_hsv(rng.randf(),0.24,0.55)
	if key == "gas_giant":
		var sphere := SphereMesh.new()
		sphere.radius = 1.25
		sphere.height = 2.5
		sphere.radial_segments = 32
		sphere.rings = 16
		var body := part(root,sphere,Color.WHITE)
		body.name = "Surface"
		body.material_override = preload("res://third_party/naejimer_planets/materials/gaseous.tres").duplicate()
		root.set_meta("radius",1.25)
		return root
	if key == "derelict_starship":
		var profile = preload("res://ships/enemy/marauder.tres").duplicate(false)
		profile.hull_color = Color("394047")
		var wreck = ship(profile)
		wreck.rotation = Vector3(0.4,0.8,0.6)
		wreck.scale = Vector3.ONE*0.5
		beacon(root,Vector3(0,0.2,0),Color("b54b37"),0.09)
		root.add_child(wreck)
	if key in ["mining_operation","derelict_starship","pirate_debris_field"]:
		for i in range(7):
			var mesh = BoxMesh.new()
			mesh.size = Vector3.ONE*rng.randf_range(0.25,0.7)
			var node = part(root,mesh,color,Vector3(rng.randf_range(-1.5,1.5),rng.randf_range(-0.4,0.4),rng.randf_range(-1.1,1.1)))
			node.rotation = Vector3(rng.randf(),rng.randf(),rng.randf())*PI
		if key != "mining_operation": return root
	if key == "radiation_nebula":
		var quad = QuadMesh.new()
		quad.size = Vector2(3.2,2.0)
		var cloud = part(root,quad,Color.WHITE)
		var material = ShaderMaterial.new()
		material.shader = preload("res://shaders/cosmic_layer.gdshader")
		material.set_shader_parameter("billboard",true)
		material.set_shader_parameter("tint",Color("9876ab"))
		material.set_shader_parameter("opacity",0.55)
		material.set_shader_parameter("variation",rng.randf_range(0,99))
		cloud.material_override = material
		return root
	if key in ["spatial_anomaly","unstable_wormhole"]:
		var core = SphereMesh.new()
		core.radius = 0.7
		core.height = 1.4
		core.radial_segments = 20
		core.rings = 10
		var dark = part(root,core,Color.BLACK)
		dark.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var halo = ring(root,1.25,Color.WHITE)
		if key == "unstable_wormhole": halo.rotation.x = PI*0.5
		else: halo.rotation.z = 0.25
		var material = ShaderMaterial.new()
		material.shader = preload("res://shaders/anomaly_ring.gdshader")
		material.set_shader_parameter("tint",Color("7496cf") if key == "unstable_wormhole" else Color("cfa06e"))
		halo.material_override = material
		return root
	# A hub, service ring, radial docks and small emissive windows; no dynamic lights.
	var hub = CylinderMesh.new()
	hub.top_radius = 0.42
	hub.bottom_radius = 0.65
	hub.height = 1.15
	hub.radial_segments = 12
	part(root,hub,color)
	ring(root,1.3,color.lightened(0.15))
	if key == "trading_outpost":
		var service_ring = ring(root,0.9,Color("9dc5c9"),Vector3(0,0.7,0))
		service_ring.rotation.x = 0.25
	for i in range(4):
		var angle: float = i*PI*0.5
		var at = Vector3(cos(angle),0,sin(angle))
		var beam = BoxMesh.new()
		beam.size = Vector3(1.35,0.12,0.2)
		var spoke = part(root,beam,color,at*0.75)
		spoke.rotation.y = -angle
		var dock = BoxMesh.new()
		dock.size = Vector3(0.55,0.45,0.7)
		part(root,dock,color.lightened(0.1),at*1.4)
		var window = BoxMesh.new()
		window.size = Vector3(0.25,0.05,0.3)
		var accent = part(root,window,Color("75c8df"),at*1.4+Vector3(0,0.25,0))
		accent.material_override.emission_enabled = true
		var glow := Color("ffb457") if key == "mining_operation" else (Color("92ddff") if key == "research_station" else Color("75d6bd"))
		accent.material_override.emission = glow
		accent.material_override.albedo_color = glow
		beacon(root,at*1.5+Vector3(0,0.35,0),glow,0.1)
	return root
