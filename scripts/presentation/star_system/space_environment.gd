extends Node3D
# One camera-relative sky in the existing viewport; no independent update loop.
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
var sky: MeshInstance3D
var layers: Array[MeshInstance3D] = []
var dust: Array[MultiMeshInstance3D] = []
var origin := Vector3.ZERO
var dust_basis := Basis.IDENTITY
var settings: Resource

func configure(camera: Camera3D, calibration: Resource, rng: RandomNumberGenerator, dust_rng: RandomNumberGenerator = null, atmosphere_strength: float = 1.0) -> void:
	settings = calibration
	origin = camera.position
	dust_basis = camera.basis
	var sphere = SphereMesh.new()
	sphere.radius = 70
	sphere.height = 140
	sphere.radial_segments = 24
	sphere.rings = 12
	sky = Models.part(self,sphere,Color.WHITE)
	var space = ShaderMaterial.new()
	space.shader = preload("res://shaders/map_sky.gdshader")
	# The far-depth sky must draw before every transparent celestial object.
	space.render_priority = -128
	space.set_shader_parameter("reference_origin",origin)
	space.set_shader_parameter("parallax",settings.starfield_parallax)
	space.set_shader_parameter("star_density",0.12)
	space.set_shader_parameter("star_resolution",220.0)
	space.set_shader_parameter("star_brightness",0.25)
	space.set_shader_parameter("star_jitter",0.9)
	space.set_shader_parameter("variation_seed",rng.randf_range(1,99))
	space.set_shader_parameter("cloud_intensity",0.06*settings.background_strength*atmosphere_strength)
	sky.material_override = space
	sky.extra_cull_margin = 1000.0
	var sparse: bool = rng.randf()<0.3
	for specification in settings.background_layers:
		if specification == null: continue
		var quad = QuadMesh.new()
		quad.size = specification.apparent_size
		var node = Models.part(self,quad,Color.WHITE)
		var material = ShaderMaterial.new()
		material.shader = preload("res://shaders/cosmic_layer.gdshader")
		material.set_shader_parameter("use_texture",specification.texture != null)
		if specification.texture != null: material.set_shader_parameter("source_texture",specification.texture)
		material.set_shader_parameter("galaxy",specification.kind == 1)
		material.set_shader_parameter("tint",specification.tint)
		material.set_shader_parameter("opacity",specification.opacity*settings.background_strength*atmosphere_strength*(0.15 if sparse else 1.0))
		material.set_shader_parameter("rotation",deg_to_rad(specification.rotation_degrees))
		material.set_shader_parameter("variation",rng.randf_range(0,TAU))
		node.material_override = material
		var yaw: float = deg_to_rad(specification.angular_position.x+rng.randf_range(-25,25))
		var pitch: float = deg_to_rad(specification.angular_position.y+rng.randf_range(-12,12))
		material.set_shader_parameter("camera_relative",true)
		material.set_shader_parameter("foreground_protection",specification.foreground_protection)
		material.set_shader_parameter("sky_direction",Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch)))
		material.set_shader_parameter("reference_origin",origin)
		material.set_shader_parameter("sky_parallax",specification.parallax)
		material.render_priority = -100+layers.size()
		node.extra_cull_margin = 1000.0
		layers.append(node)
	if dust_rng == null: dust_rng = rng
	if settings.stardust_enabled:
		for level in range(2):
			var mesh = QuadMesh.new()
			# Soft white points, with finite pixel footprints at both depth layers.
			mesh.size = Vector2.ONE*(0.035 if level==0 else 0.06)
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/stardust.gdshader")
			material.set_shader_parameter("opacity",settings.stardust_opacity)
			material.set_shader_parameter("reference_origin",origin)
			material.set_shader_parameter("reference_basis",dust_basis)
			material.set_shader_parameter("parallax",settings.stardust_parallax*(1.0 if level==0 else 0.5))
			material.set_shader_parameter("near_depth",5.0+level*5.0)
			mesh.material = material
			var node = MultiMeshInstance3D.new()
			node.multimesh = MultiMesh.new()
			node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			node.multimesh.mesh = mesh
			node.multimesh.instance_count = clampi(settings.stardust_density,0,160)/2
			for i in range(node.multimesh.instance_count):
				var at = Vector3(dust_rng.randf_range(-12,12),dust_rng.randf_range(-6,6),-dust_rng.randf_range(5+level*5,9+level*5))
				node.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,at))
			# Shader positioning bypasses CPU transforms; do not cull against the origin.
			node.extra_cull_margin = 1000.0
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			dust.append(node)
	set_active(true)

func set_active(enabled: bool) -> void:
	# All sky/debris placement uses render-camera matrices. No pre-draw callbacks.
	visible = enabled
