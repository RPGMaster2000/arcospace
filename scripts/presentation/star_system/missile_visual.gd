extends RefCounted

static func build() -> Node3D:
	var root := Node3D.new()
	root.name = "IncomingMissile"
	root.set_meta("radius", 0.48)
	_part(root, 0.13, 0.025, 0.57, -0.13, Color("e7d5bb"))
	_part(root, 0.04, 0.12, 0.72, 0.46, Color(1.0, 0.42, 0.13, 0.55))
	return root

static func shot(parent: Node3D, from: Vector3, to: Vector3, destroyed: bool) -> void:
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(from + Vector3.UP * 0.45)
	line.surface_add_vertex(to + Vector3.UP * 0.18)
	line.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffd697") if destroyed else Color("faac6e")
	var trace := MeshInstance3D.new()
	trace.mesh = line
	trace.material_override = material
	trace.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(trace)
	trace.get_tree().create_timer(0.28).timeout.connect(trace.queue_free)

static func _part(root: Node3D, rear: float, front: float, length: float, at: float, tint: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = front
	mesh.bottom_radius = rear
	mesh.height = length
	mesh.radial_segments = 8
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	if tint.a < 1.0:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = material
	model.rotation.x = -PI * 0.5
	model.position.z = at
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(model)
