extends RefCounted
## Matched PR #54 / revised tuning on identical world geometry and camera.
static func apply(shafts: Node3D, revised: bool) -> void:
	var material: ShaderMaterial = shafts.material
	if not material.has_meta("revised_extent"):
		material.set_meta("revised_extent",material.get_shader_parameter("field_extent"))
	var extent: Vector3 = material.get_meta("revised_extent")
	if not revised:
		extent.x *= 1.65/1.40
		extent.z *= 1.65/1.40
	material.set_shader_parameter("field_extent",extent)
	material.set_shader_parameter("shadow_strength",Vector3(0.95,1.20,0.90) if revised else Vector3(0.78,0.50,1.0))

static func patch(map: Control, image: Image, point: Vector3) -> float:
	var pixel: Vector2i = Vector2i(map.camera.unproject_position(point))
	var total := 0.0
	for y in range(-4,5):
		for x in range(-4,5):
			total += image.get_pixelv(pixel+Vector2i(x,y)).get_luminance()/81.0
	return total
