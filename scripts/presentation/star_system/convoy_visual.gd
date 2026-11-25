extends Node3D
## The route and beacon are presentation-only and use committed navigation points.
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const TINT := Color("75e4c7")
var extraction_label: Label3D
var extraction: Vector3


func configure(route: Array) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, route.size()):
		var a := _point(route[i - 1]) + Vector3.UP * 0.12
		var b := _point(route[i]) + Vector3.UP * 0.12
		var offset := Vector3.UP.cross((b - a).normalized()) * 0.10
		var distance := a.distance_to(b)
		for step in range(ceili(distance / 2.2)):
			var p := a.move_toward(b, step * 2.2)
			var q := a.move_toward(b, step * 2.2 + 1.55)
			for vertex in [p - offset, q - offset, q + offset, p - offset, q + offset, p + offset]:
				mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = mesh
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.albedo_color = Color(TINT, 0.64)
	line.material_override = paint
	add_child(line)
	extraction = _point(route.back())
	Models.ring(self, 1.65, TINT, extraction + Vector3.UP * 0.2).rotation.x = PI * 0.5
	Models.beacon(self, extraction + Vector3.UP * 0.9, TINT, 0.33)
	extraction_label = Label3D.new()
	extraction_label.name = "EvacuationBeacon"
	extraction_label.text = "EVAC BEACON"
	extraction_label.position = extraction + Vector3.UP * 1.8
	extraction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	extraction_label.modulate = TINT
	extraction_label.font_size = 26
	extraction_label.pixel_size = 0.023
	add_child(extraction_label)


static func _point(wire: Array) -> Vector3:
	return Vector3(wire[0], wire[1], wire[2])
