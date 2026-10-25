extends RefCounted
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const Data = preload("res://scripts/presentation/star_system/visual_system.gd")
const PRESETS = {
	"rocky": preload("res://third_party/naejimer_planets/materials/no_atmosphere.tres"),
	"barren": preload("res://third_party/naejimer_planets/materials/no_atmosphere.tres"),
	"terrestrial": preload("res://third_party/naejimer_planets/materials/terrestrial.tres"),
	"desert": preload("res://third_party/naejimer_planets/materials/sand.tres"),
	"frozen": preload("res://third_party/naejimer_planets/materials/ice.tres"),
	"volcanic": preload("res://third_party/naejimer_planets/materials/lava.tres"),
	"gas_giant": preload("res://third_party/naejimer_planets/materials/gaseous.tres")}

static func sphere(radius: float) -> SphereMesh:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2
	mesh.radial_segments = 32
	mesh.rings = 16
	return mesh

static func build(data: Dictionary, settings: Resource) -> Node3D:
	var root = Node3D.new()
	root.name = "Planet%d" % data.index
	root.scale = Vector3.ONE*1.5
	root.set_meta("radius", data.radius*1.5)
	var body = Models.part(root, sphere(data.radius), Color.WHITE)
	body.name = "Surface"
	body.rotation.y = data.rotation
	var material: ShaderMaterial
	if settings.imported_planets:
		material = PRESETS[data.type].duplicate()
		var rng = Data.random_for(data.material_seed, 0, "material")
		material.set_shader_parameter("noise_scale", rng.randf_range(0.8, 2.3) / data.radius)
		material.set_shader_parameter("noise_offset", Vector3(rng.randf()*20, rng.randf()*20, rng.randf()*20))
		var hue: float = rng.randf_range(-0.025,0.025)
		var brightness: float = rng.randf_range(0.85,1.08)
		for index in range(1,6):
			var key: String = "color_%d" % index
			var color: Color = material.get_shader_parameter(key)
			material.set_shader_parameter(key,Color.from_hsv(fposmod(color.h+hue,1.0),color.s,minf(1.0,color.v*brightness)))
	else:
		material = ShaderMaterial.new()
		material.shader = preload("res://shaders/planet_surface.gdshader")
		material.set_shader_parameter("land_color", Color.from_hsv(fposmod(data.material_seed*0.001,1), 0.35, 0.65))
	body.material_override = material
	if settings.imported_planets and settings.clouds_enabled and data.type in ["terrestrial", "frozen"]:
		var cloud = Models.part(body, sphere(data.radius*1.015), Color.WHITE)
		var clouds = ShaderMaterial.new()
		clouds.shader = preload("res://third_party/naejimer_planets/shaders/clouds.gdshader")
		clouds.set_shader_parameter("noise_texture", material.get_shader_parameter("noise"))
		clouds.set_shader_parameter("brightness", 0.65)
		clouds.set_shader_parameter("threshold", 1.3)
		cloud.material_override = clouds
	if settings.imported_planets and settings.atmospheres_enabled and data.type not in ["rocky", "barren"]:
		var air = Models.part(root, sphere(data.radius*1.035), Color.WHITE)
		var atmosphere = ShaderMaterial.new()
		atmosphere.shader = preload("res://third_party/naejimer_planets/shaders/atmosphere.gdshader")
		atmosphere.set_shader_parameter("alpha", 0.10)
		atmosphere.set_shader_parameter("intensity", 1.1)
		atmosphere.set_shader_parameter("emit", true)
		air.material_override = atmosphere
	return root

static func orbit(data: Dictionary, settings: Resource) -> MeshInstance3D:
	# A single thin triangle strip; consistent width on Mobile and Compatibility.
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var segments: int = clampi(settings.orbit_segments, 32, 128)
	for i in range(segments+1):
		var angle: float = TAU*i/segments
		var at: Vector3 = Data.orbit_point(data, angle)
		var direction: Vector3 = (Data.orbit_point(data, angle+0.001)-at).normalized()
		var side: Vector3 = direction.cross(Vector3.UP).normalized()*settings.orbit_thickness
		mesh.surface_add_vertex(at-side)
		mesh.surface_add_vertex(at+side)
	mesh.surface_end()
	var node = MeshInstance3D.new()
	node.mesh = mesh
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = settings.orbit_color
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
