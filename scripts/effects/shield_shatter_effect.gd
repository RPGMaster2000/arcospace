extends Node3D
# RESPONSIBILITY: Lightweight one-shot shield fragments, driven by the combat timeline.
# 32 shared-mesh instances, one material, no physics, random generator or damage logic.
static var fragment_mesh: ArrayMesh
var settings: Resource
var shield: MeshInstance3D
var particles: MultiMeshInstance3D
var fragment_material: ShaderMaterial
var radii: Vector3
var active: bool = true
var burst_started: bool = false
var intact_visible: bool = true
var original_tint: Color
var original_ripple: float = 1.0


func configure(surface: MeshInstance3D, tuning: Resource, resting_tint: Color) -> void:
	shield = surface
	# Freeze timings for this burst; Inspector edits affect the next sequence.
	settings = tuning.duplicate(true)
	original_tint = resting_tint
	var previous_ripple = shield.material_override.get_shader_parameter("ripple_strength")
	original_ripple = 1.0 if previous_ripple == null else float(previous_ripple)
	shield.material_override.set_shader_parameter("tint", settings.shatter_fragment_color)
	shield.material_override.set_shader_parameter(
		"ripple_strength", maxf(original_ripple, 1.8) * 1.5
	)
	position = shield.position
	rotation = shield.rotation
	radii = shield.mesh.get_aabb().size * shield.scale * 0.5
	if fragment_mesh == null:
		fragment_mesh = ArrayMesh.new()
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(
			[Vector3(-0.5, -0.3, 0), Vector3(0, 0.6, 0), Vector3(0.5, -0.3, 0)]
		)
		fragment_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	particles = MultiMeshInstance3D.new()
	particles.multimesh = MultiMesh.new()
	particles.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	particles.multimesh.mesh = fragment_mesh
	particles.multimesh.instance_count = clampi(settings.shatter_fragment_count, 24, 40)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fragment_material = ShaderMaterial.new()
	fragment_material.shader = preload("res://shaders/shield_fragment.gdshader")
	fragment_material.set_shader_parameter("tint", settings.shatter_fragment_color)
	fragment_material.set_shader_parameter("brightness", settings.shatter_brightness)
	particles.material_override = fragment_material
	add_child(particles)
	particles.hide()
	seek(0.0)


func seek(time: float) -> void:
	if not active:
		return
	var burst: float = settings.shatter_burst_start
	var total: float = maxf(burst + 0.01, settings.shatter_total_duration)
	var material: ShaderMaterial = shield.material_override
	var fracture: float = clampf(
		(
			(time - settings.shatter_fracture_start)
			/ maxf(0.01, settings.shatter_fracture_end - settings.shatter_fracture_start)
		),
		0,
		1
	)
	material.set_shader_parameter("fracture", fracture)
	material.set_shader_parameter(
		"collapse", clampf((time - burst) / maxf(0.01, settings.shatter_fracture_end - burst), 0, 1)
	)
	material.set_shader_parameter(
		"shatter_flash", maxf(0.0, 1.0 - time / settings.shatter_flash_duration)
	)
	material.set_shader_parameter("hit", clampf(time / maxf(0.01, burst), 0.001, 0.999))
	intact_visible = time < maxf(settings.shatter_fracture_end, burst)
	shield.visible = intact_visible
	if time >= burst:
		burst_started = true
		particles.show()
		var age: float = time - burst
		fragment_material.set_shader_parameter(
			"fade", pow(clampf(1.0 - age / (total - burst), 0, 1), settings.shatter_fade_power)
		)
		for index in range(particles.multimesh.instance_count):
			# Even ellipsoid coverage and deterministic variation without combat RNG consumption.
			var y: float = 1.0 - 2.0 * (index + 0.5) / particles.multimesh.instance_count
			var angle: float = index * 2.399963
			var direction = Vector3(cos(angle) * sqrt(1 - y * y), y, sin(angle) * sqrt(1 - y * y))
			var variation: float = 1.0 + sin(index * 13.7) * settings.shatter_randomness
			var origin: Vector3 = (
				direction * radii + direction * age * settings.shatter_fragment_speed * variation
			)
			var basis = Basis.from_euler(
				Vector3(
					angle,
					angle * 0.7 + age * settings.shatter_fragment_rotation_speed * variation,
					angle * 0.3
				)
			)
			basis = basis.scaled(Vector3.ONE * settings.shatter_fragment_scale * variation)
			particles.multimesh.set_instance_transform(index, Transform3D(basis, origin))
	if time >= total:
		cancel()


func cancel() -> void:
	if not active:
		return
	active = false
	if is_instance_valid(shield):
		for key in ["fracture", "collapse", "shatter_flash", "hit"]:
			shield.material_override.set_shader_parameter(key, 0.0)
		shield.material_override.set_shader_parameter("tint", original_tint)
		shield.material_override.set_shader_parameter("ripple_strength", original_ripple)
		shield.visible = get_parent().shield_strength > 0
	queue_free()
