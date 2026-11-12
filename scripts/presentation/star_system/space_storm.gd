extends RefCounted

const Storms = preload("res://scripts/expedition/storm_regions.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
const Cloud = preload("res://shaders/space_storm.gdshader")
const SLICES = [-0.54, 0.0, 0.52]
const BOUNDARY_SEGMENTS = 72

static func primary(instances: Array) -> Dictionary:
	for item in instances:
		if item.get("type") != Storms.TYPE or not Storms.valid(item): continue
		if Storms.valid_visual(item.get("visual"), item.configuration.subtype): return item
	return {}

static func build(storm: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "PhysicalSpaceStorm"
	if storm.is_empty(): return root
	var axes := Vector3(storm.region.axes[0], storm.region.axes[1], storm.region.axes[2])
	root.position = Vector3(storm.position[0], storm.position[1], storm.position[2])
	var tint := Color.from_string(storm.visual.color, Color.WHITE)
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	for slice in SLICES:
		# Every cloud sheet fits the matching cross section of the saved ellipsoid.
		var scale_factor := sqrt(1.0 - float(slice) * float(slice))
		var sheet := MeshInstance3D.new()
		sheet.mesh = plane
		sheet.position.y = axes.y * slice
		sheet.scale = Vector3(axes.x * scale_factor, 1.0, axes.z * scale_factor)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = Cloud
		material.render_priority = -10
		material.set_shader_parameter("storm_color", tint)
		material.set_shader_parameter("phase", storm.visual.phase)
		material.set_shader_parameter("density", float(storm.intensity) * (0.36 if slice == 0.0 else 0.30))
		material.set_shader_parameter("layer", float(slice))
		sheet.material_override = material
		root.add_child(sheet)
	root.add_child(_boundary(axes, tint))
	return root

static func _boundary(axes: Vector3, tint: Color) -> MeshInstance3D:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(BOUNDARY_SEGMENTS + 1):
		var angle := TAU * i / BOUNDARY_SEGMENTS
		var at := Vector3(cos(angle) * axes.x, 0.035, sin(angle) * axes.z)
		mesh.surface_add_vertex(Vector3(at.x * 0.986, at.y, at.z * 0.986))
		mesh.surface_add_vertex(at)
	mesh.surface_end()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(tint, 0.32)
	var ring := MeshInstance3D.new()
	ring.name = "EngagementBoundary"
	ring.mesh = mesh
	ring.material_override = material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return ring

static func legend(storm: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "StormLegend"
	panel.z_index = 12
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111c2b")
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var modifier := Storms.modifier_id(storm.configuration.subtype)
	var button := Button.new()
	button.text = "%s · %s" % [Modifiers.NAMES[modifier], Modifiers.storm_family(modifier).capitalize()]
	button.tooltip_text = Modifiers.description(modifier)
	button.add_theme_color_override("font_color", Color.from_string(storm.visual.color, Color.WHITE).lightened(0.32))
	button.custom_minimum_size.y = 40
	column.add_child(button)
	var detail := Label.new()
	detail.text = "Effects ×2 or ×½\n%d rounds · Both ships\nCard costs unchanged" % Modifiers.ACTIVE_ROUNDS
	detail.hide()
	column.add_child(detail)
	button.pressed.connect(func():
		detail.visible = not detail.visible
		panel.size.y = 0.0)
	return panel
