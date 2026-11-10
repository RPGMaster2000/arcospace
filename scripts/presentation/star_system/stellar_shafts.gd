extends Node3D
## Bounded world-space dust, with analytic planetary shadow corridors.
var bodies: Array = []
var source: Node3D
var source_radius := 2.52
var material: ShaderMaterial
var shared_mesh := BoxMesh.new()
var records: Array = []
var strength := 0.035

func configure(star: Node3D, radius: float, objects: Array, color: Color) -> void:
	name = "StellarShafts"
	source = star
	source_radius = radius
	bodies = objects
	material = ShaderMaterial.new()
	material.render_priority = -20 # Dust behind atmospheric/UI ribbons; stable across camera sorting.
	material.shader = preload("res://shaders/stellar_dust_volume.gdshader")
	material.set_shader_parameter("dust_color",Color(0.42,0.50,0.58).lerp(color,0.15))
	# A fixed unit proxy is shared; instance uniforms expand its vertices.
	shared_mesh.size = Vector3.ONE
	for body in bodies.slice(0,3):
		if not is_instance_valid(body) or float(body.get_meta("radius",0.0)) < 0.5: continue
		var volume := MeshInstance3D.new()
		volume.mesh = shared_mesh
		volume.material_override = material
		volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Shader dimensions use unscaled world units.
		add_child(volume)
		records.append({"body":body,"volume":volume,"position":Vector3.INF,"star":Vector3.INF,"radius":0.0})
	_update_geometry()

func _process(_delta: float) -> void:
	_update_geometry()

func _update_geometry() -> void:
	if not is_instance_valid(source): return
	for record in records:
		var body: Node3D = record.body
		if not is_instance_valid(body):
			record.volume.hide()
			continue
		var radius: float = body.get_meta("radius",0.5)
		if record.position == body.global_position and record.star == source.global_position and record.radius == radius: continue
		record.position = body.global_position
		record.star = source.global_position
		record.radius = radius
		var away: Vector3 = body.global_position-source.global_position
		var distance: float = away.length()
		if distance <= radius+source_radius:
			record.volume.hide()
			continue
		var length: float = clampf(radius*8.0,5.0,12.0)
		var spread: float = clampf(source_radius/distance*0.45,0.08,0.22)
		var width: float = radius*1.65+spread*length
		var volume: MeshInstance3D = record.volume
		# Size the shared-box instance via a per-node custom AABB and vertex extent.
		var extent := Vector3(width*2.0,width*2.0,length)
		volume.custom_aabb = AABB(-extent*0.5,extent)
		volume.set_instance_shader_parameter("volume_extent",extent)
		volume.global_basis = Basis.looking_at(-away.normalized(),Vector3.FORWARD if absf(away.normalized().dot(Vector3.UP)) > 0.98 else Vector3.UP)
		volume.global_position = body.global_position + away.normalized()*length*0.5
		volume.set_instance_shader_parameter("body_radius",radius)
		volume.set_instance_shader_parameter("shaft_length",length)
		volume.set_instance_shader_parameter("spread",spread)
		volume.set_instance_shader_parameter("umbra_slope",(radius-source_radius)/distance)
		var gas: bool = body.get_meta("stellar_medium","") == "gas_giant"
		volume.set_instance_shader_parameter("density",strength * (0.75 if gas else 1.0))
		volume.show()
