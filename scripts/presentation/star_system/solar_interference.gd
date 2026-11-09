extends RefCounted
## Two shader-animated meshes, no input, lights, particles or per-frame CPU work.
const Solar = preload("res://scripts/expedition/solar_regions.gd")

static func primary(instances: Array) -> Dictionary:
	var chosen: Dictionary = {}
	for item in instances:
		if not item is Dictionary or item.get("type") != Solar.TYPE or not Solar.valid(item) or not Solar.valid_visual(item.get("visual")): continue
		if chosen.is_empty() or item.id < chosen.id: chosen = item
	return chosen

static func build(item: Dictionary, color: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "SolarInterference"
	if item.is_empty(): return root
	root.position = Vector3(item.position[0], item.position[1], item.position[2])
	var corona := MeshInstance3D.new()
	corona.name = "Corona"
	var quad := QuadMesh.new()
	var extent: float = float(item.configuration.star_radius) * 2.1
	quad.size = Vector2.ONE * extent * 2.0
	corona.mesh = quad
	corona.custom_aabb = AABB(Vector3.ONE * -extent, Vector3.ONE * extent * 2.0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/solar_corona.gdshader")
	material.render_priority = 9
	corona.material_override = material
	root.add_child(corona)
	var influence := MeshInstance3D.new()
	influence.name = "InfluenceBoundary"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * float(item.region.radius) * 2.08
	influence.mesh = plane
	var boundary := ShaderMaterial.new()
	boundary.shader = preload("res://shaders/solar_influence.gdshader")
	influence.material_override = boundary
	root.add_child(influence)
	for mesh in [corona, influence]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.material_override.set_shader_parameter("star_color", color)
		mesh.material_override.set_shader_parameter("intensity", float(item.intensity))
		mesh.material_override.set_shader_parameter("activity", float(item.visual.activity))
		mesh.material_override.set_shader_parameter("phase", float(item.visual.phase))
		mesh.material_override.set_shader_parameter("pulse_rate", float(item.visual.pulse_rate))
	return root
