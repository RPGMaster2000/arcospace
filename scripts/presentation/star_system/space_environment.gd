extends Node3D
# One camera-relative sky in the existing viewport; no independent update loop.
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
var sky: MeshInstance3D
var layers: Array[MeshInstance3D] = []
var dust: Array[MultiMeshInstance3D] = []
var origin := Vector3.ZERO
var dust_basis := Basis.IDENTITY
var settings: Resource
var source_camera: Camera3D

func configure(camera: Camera3D, calibration: Resource, rng: RandomNumberGenerator, dust_rng: RandomNumberGenerator = null) -> void:
	settings = calibration
	source_camera = camera
	origin = camera.position
	dust_basis = camera.basis
	var sphere = SphereMesh.new()
	sphere.radius = 70
	sphere.height = 140
	sphere.radial_segments = 24
	sphere.rings = 12
	sky = Models.part(self,sphere,Color.WHITE)
	var space = ShaderMaterial.new()
	space.shader = preload("res://shaders/space_background.gdshader")
	space.set_shader_parameter("star_density",0.12)
	space.set_shader_parameter("star_resolution",500.0)
	space.set_shader_parameter("star_brightness",0.25)
	space.set_shader_parameter("star_jitter",0.9)
	space.set_shader_parameter("variation_seed",rng.randf_range(1,99))
	space.set_shader_parameter("cloud_intensity",0.06*settings.background_strength)
	sky.material_override = space
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
		material.set_shader_parameter("opacity",specification.opacity*settings.background_strength*(0.15 if sparse else 1.0))
		material.set_shader_parameter("rotation",deg_to_rad(specification.rotation_degrees))
		material.set_shader_parameter("variation",rng.randf_range(0,TAU))
		node.material_override = material
		var yaw: float = deg_to_rad(specification.angular_position.x+rng.randf_range(-25,25))
		var pitch: float = deg_to_rad(specification.angular_position.y+rng.randf_range(-12,12))
		node.set_meta("direction",Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch)))
		node.set_meta("parallax",specification.parallax)
		layers.append(node)
	if dust_rng == null: dust_rng = rng
	if settings.stardust_enabled:
		for level in range(2):
			var mesh = QuadMesh.new()
			# Visible fragments rather than subpixel points that shimmer like distant stars.
			mesh.size = Vector2.ONE*(0.16 if level==0 else 0.21)
			var material = ShaderMaterial.new()
			material.shader = preload("res://shaders/stardust.gdshader")
			material.set_shader_parameter("opacity",settings.stardust_opacity)
			mesh.material = material
			var node = MultiMeshInstance3D.new()
			node.multimesh = MultiMesh.new()
			node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			node.multimesh.mesh = mesh
			node.multimesh.instance_count = clampi(settings.stardust_density,0,160)/2
			for i in range(node.multimesh.instance_count):
				var at = Vector3(dust_rng.randf_range(-6,6),dust_rng.randf_range(-4,4),-dust_rng.randf_range(5+level*5,9+level*5))
				var shape = Basis(Vector3.FORWARD,dust_rng.randf_range(0,TAU)).scaled(Vector3(dust_rng.randf_range(0.65,1.4),dust_rng.randf_range(0.5,1.0),1))
				node.multimesh.set_instance_transform(i,Transform3D(shape,at))
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			dust.append(node)
	update_view(camera)
	set_active(true)

func update_view(camera: Camera3D) -> void:
	sky.position = camera.position
	for node in layers:
		node.position = camera.position+node.get_meta("direction")*55-(camera.position-origin)*float(node.get_meta("parallax"))
		node.look_at(camera.position,Vector3.UP)
	for i in range(dust.size()):
		var drift: Vector3 = (camera.position-origin)*settings.stardust_parallax*(0.65+i*0.35)
		# Keep orientation anchored to the system. Rotating with the camera made the
		# foreground look screen-locked and jump during focus/cinematic camera turns.
		dust[i].transform = Transform3D(dust_basis,camera.position-drift)

# Run after camera tweens, immediately before drawing, so the sky never lags a frame.
func _sync() -> void:
	if is_instance_valid(source_camera): update_view(source_camera)

func set_active(enabled: bool) -> void:
	if enabled and not RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.connect(_sync)
	elif not enabled and RenderingServer.frame_pre_draw.is_connected(_sync):
		RenderingServer.frame_pre_draw.disconnect(_sync)

func _exit_tree() -> void:
	set_active(false)
