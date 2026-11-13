extends Node3D

const COLOR = Color("ff754d")
var lines := ImmediateMesh.new()
var material := StandardMaterial3D.new()

func configure(radius: float, preview: bool) -> void:
	name = "DecoyPreview" if preview else "TacticalDecoy"
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	var geometry := MeshInstance3D.new()
	geometry.mesh = lines
	geometry.material_override = material
	geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(geometry)
	if not preview:
		var body := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.19
		mesh.bottom_radius = 0.49
		mesh.height = 0.8
		mesh.radial_segments = 8
		body.mesh = mesh
		body.position.y = 0.45
		body.material_override = material
		add_child(body)
		var label := Label3D.new()
		label.text = "Tactical Decoy"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.021
		label.position.y = 1.0
		label.modulate = COLOR
		add_child(label)
	draw(radius, Vector3.ZERO, 0.0, [], true)

func draw(radius: float, player: Vector3, deploy_range: float, enemies: Array[Vector3], valid: bool) -> void:
	material.albedo_color = COLOR if valid else Color("b69bb0")
	lines.clear_surfaces()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	_circle(Vector3.ZERO, radius, 72, Color(1, 1, 1, 0.42))
	if deploy_range > 0.0:
		_circle(player - position, deploy_range, 64, Color(0.78, 0.86, 1.0, 0.38))
		for i in range(8):
			var angle := TAU * i / 8.0
			var radial := Vector3(cos(angle), 0, sin(angle))
			_segment(radial * 0.65, radial * 0.27 + Vector3.UP, Color.WHITE)
			_segment(radial * 0.27 + Vector3.UP, Vector3.UP * 1.55, Color.WHITE)
		_circle(Vector3.ZERO, 0.65, 8, Color.WHITE)
	for enemy in enemies:
		var end := enemy - position
		var count := maxi(1, ceili(end.length() / 0.7))
		for i in count:
			_segment(Vector3.UP * 0.22 + end * (float(i) / count),
				Vector3.UP * 0.22 + end * ((i + 0.46) / count), Color.WHITE)
	lines.surface_end()

func _circle(center: Vector3, radius: float, count: int, color: Color) -> void:
	for i in count:
		var a := TAU * i / count
		var b := TAU * (i + 1) / count
		_segment(center + Vector3(cos(a) * radius, 0.04, sin(a) * radius),
			center + Vector3(cos(b) * radius, 0.04, sin(b) * radius), color)

func _segment(a: Vector3, b: Vector3, color: Color) -> void:
	lines.surface_set_color(color)
	lines.surface_add_vertex(a)
	lines.surface_set_color(color)
	lines.surface_add_vertex(b)
