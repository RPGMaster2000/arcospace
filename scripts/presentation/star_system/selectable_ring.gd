extends MeshInstance3D
## Presentation only. No input areas, collisions, timers or lights.
var radius := 1.0
var emphasized := false

func configure(body_radius: float, color: Color) -> void:
	name = "SelectableRing"
	radius = maxf(0.65, body_radius + 0.24)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.25
	mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/poi_selection_ring.gdshader")
	material.set_shader_parameter("ring_color", color)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func sync(marker: Control, body: Node3D) -> void:
	visible = marker.visible and not marker.completed
	# World aligned, below the visible surface rather than slicing through it.
	position = body.position - Vector3.UP * (float(body.get_meta("radius", 0.65)) + 0.08)
	var highlight: bool = marker.highlighted()
	if highlight != emphasized:
		emphasized = highlight
		material_override.set_shader_parameter("emphasis", 1.0 if highlight else 0.0)
