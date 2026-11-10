extends Node3D
## One continuous star-centered medium; analytical occluders darken that medium.
var bodies: Array = []
var source: Node3D
var source_radius := 2.52
var material: ShaderMaterial
var shared_mesh := BoxMesh.new()
var records: Array = []
var strength := 0.007
var field_radius := 66.0
var half_height := 14.0
var field: MeshInstance3D
var last_star := Vector3.INF

func configure(star: Node3D, radius: float, objects: Array, color: Color) -> void:
	name = "StellarShafts"
	source = star
	source_radius = radius
	bodies = objects
	material = ShaderMaterial.new()
	material.render_priority = -20
	material.shader = preload("res://shaders/stellar_dust_volume.gdshader")
	material.set_shader_parameter("dust_color",Color(0.32,0.41,0.50).lerp(color,0.10))
	material.set_shader_parameter("star_radius",source_radius)
	material.set_shader_parameter("density",strength)
	shared_mesh.size = Vector3.ONE
	field = MeshInstance3D.new()
	field.name = "SystemScatteringField"
	field.mesh = shared_mesh
	field.material_override = material
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(field)
	for body in bodies.slice(0,6):
		if not is_instance_valid(body) or float(body.get_meta("radius",0.0))<0.5: continue
		records.append({"body":body,"volume":field,"position":Vector3.INF,"radius":0.0,"axis":Vector3.ZERO})
	_update_geometry()

func _process(_delta: float) -> void:
	_update_geometry()

func _update_geometry() -> void:
	if not is_instance_valid(source): return
	var dirty: bool = last_star != source.global_position
	last_star = source.global_position
	field.global_position = last_star
	for record in records:
		if not is_instance_valid(record.body):
			dirty = true
			continue
		var radius: float = record.body.get_meta("radius",0.5)
		if record.position != record.body.global_position or record.radius != radius:
			dirty = true
			record.position = record.body.global_position
			record.radius = radius
	if not dirty: return
	var table := PackedVector4Array()
	var axes := PackedVector4Array()
	var reach: float = field_radius
	for record in records:
		if not is_instance_valid(record.body): continue
		var relative: Vector3 = record.position-last_star
		var distance: float = relative.length()
		if distance <= record.radius+source_radius: continue
		record.axis = relative.normalized()
		table.append(Vector4(relative.x,relative.y,relative.z,record.radius))
		axes.append(Vector4(record.axis.x,record.axis.y,record.axis.z,(record.radius-source_radius)/distance))
		reach = maxf(reach,(distance+record.radius)*1.65)
	var count: int = table.size()
	while table.size()<6:
		table.append(Vector4.ZERO)
		axes.append(Vector4.ZERO)
	var extent := Vector3(reach,half_height,reach)
	field.custom_aabb = AABB(-extent,extent*2.0)
	material.set_shader_parameter("field_extent",extent)
	material.set_shader_parameter("body_count",count)
	material.set_shader_parameter("bodies",table)
	material.set_shader_parameter("axes",axes)
