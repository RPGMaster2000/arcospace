extends Node3D

const APERTURE = preload("res://shaders/temporal_rift.gdshader")
var instance_id: String
var materials: Array[ShaderMaterial] = []
var caption: Label3D
var display_seconds := -1
var opacity := 0.0
var closing := false


func configure(record: Dictionary) -> void:
	instance_id = record.id
	name = "PhysicalTemporalRift"
	position = Vector3(record.position[0], record.position[1], record.position[2])
	var radius: float = record.region.radius
	var phase := TAU * float(int(record.visual.seed) % 997) / 997.0
	var footprint := _sheet(radius * 2.0 / 0.95, phase, true)
	footprint.position.y = -0.10
	var aperture := _sheet(radius * 2.16, phase, false)
	aperture.position.y = 0.14
	aperture.rotation.z = 0.11 * sin(phase)
	caption = Label3D.new()
	caption.name = "Lifetime"
	caption.position = Vector3(0.0, -0.1, radius * 0.92)
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.fixed_size = true
	caption.font_size = 26
	caption.pixel_size = 0.00029
	caption.outline_size = 6
	caption.modulate = Color(0.76, 0.86, 1.0, 0.0)
	add_child(caption)
	update_lifetime(record.simulation.remaining)


func _sheet(size_in_world: float, phase: float, boundary: bool) -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * size_in_world
	sheet.mesh = plane
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = APERTURE
	material.render_priority = -5
	material.set_shader_parameter("phase", phase)
	material.set_shader_parameter("boundary", boundary)
	materials.append(material)
	sheet.material_override = material
	add_child(sheet)
	return sheet


func update_lifetime(seconds: float) -> void:
	var whole := ceili(seconds)
	if display_seconds == whole: return
	display_seconds = whole
	caption.text = "Temporal Rift · %ds" % whole


func expire() -> void:
	closing = true
	caption.hide()
	if opacity <= 0.0: queue_free()


func _process(delta: float) -> void:
	var target := 0.0 if closing else 1.0
	if opacity == target: return
	opacity = move_toward(opacity, target, delta / (0.65 if closing else 0.5))
	var eased := smoothstep(0.0, 1.0, opacity)
	for material in materials: material.set_shader_parameter("visibility", eased)
	caption.modulate.a = eased * 0.86
	if closing and opacity <= 0.0: queue_free()
