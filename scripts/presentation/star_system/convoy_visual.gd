extends Node3D
## The route and beacon are presentation-only and use committed navigation points.
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const TINT := Color("75e4c7")
var extraction_label: Label
var extraction: Vector3


func configure(route: Array, map: Control) -> void:
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
	extraction_label = Label.new()
	extraction_label.name = "EvacuationBeacon"
	extraction_label.text = "EVAC BEACON"
	extraction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extraction_label.z_index = 25
	extraction_label.add_theme_font_size_override("font_size", 14)
	extraction_label.add_theme_color_override("font_color", TINT)
	extraction_label.add_theme_color_override("font_outline_color", Color("071616"))
	extraction_label.add_theme_constant_override("outline_size", 5)
	map.add_child(extraction_label)


func project_beacon(map: Control) -> void:
	extraction_label.visible = visible and not map.focused and not map.introducing and not map.camera.is_position_behind(extraction)
	if not extraction_label.visible: return
	var at: Vector2 = map.camera.unproject_position(extraction + Vector3.UP * 1.3)
	var area := Rect2(Vector2.ZERO, map.size).grow(-4.0)
	var extent := extraction_label.get_minimum_size()
	extraction_label.visible = area.has_point(at)
	if not extraction_label.visible: return
	var position_at := at - Vector2(extent.x * 0.5, extent.y + 5.0)
	var reserved: Array = map.hud_regions.duplicate()
	for tag in map.markers.values():
		if tag.visible: reserved.append(tag.get_rect().grow(3.0))
	for shift in [Vector2.ZERO, Vector2(0, extent.y + 14), Vector2(extent.x, 0), Vector2(-extent.x, 0)]:
		var candidate: Vector2 = (position_at + shift).clamp(area.position, area.end - extent)
		if not reserved.any(func(rect): return rect.intersects(Rect2(candidate, extent))):
			extraction_label.position = candidate
			return
	extraction_label.position = position_at.clamp(area.position, area.end - extent)


func _exit_tree() -> void:
	if is_instance_valid(extraction_label): extraction_label.queue_free()


static func _point(wire: Array) -> Vector3:
	return Vector3(wire[0], wire[1], wire[2])
