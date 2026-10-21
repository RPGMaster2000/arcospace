extends Node3D

# DOES NOT: Decide damage or repair amounts; Board supplies the resulting strengths.
# RESPONSIBILITY: Animate the prototype mesh; never change combat state.

# BattleEffects owns these tweens, so existing turn timing stays intact.
@onready var body: Node3D = $Body
@onready var shield: MeshInstance3D = $Shield
@export var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
var engine_materials: Array[StandardMaterial3D] = []
var engine_colors: Array[Color] = []
var engine_boost: bool = false
var engine_multiplier: float = 1.0
var hull_material: StandardMaterial3D
var shield_material: ShaderMaterial
var repair_material: ShaderMaterial
var base_color: Color
var damage_material: ShaderMaterial
var hull_strength: int = 30
var rest_position: Vector3
var hover_time: float = 0.0
var shield_was_offline: bool = false


func _process(delta: float) -> void:
	hover_time += delta
	var target: float = visual_settings.engine_ftl_multiplier if engine_boost else 1.0
	engine_multiplier = move_toward(
		engine_multiplier,
		target,
		(
			delta
			* (visual_settings.engine_ftl_multiplier - 1.0)
			/ visual_settings.engine_ftl_transition_duration
		)
	)
	for index in range(engine_materials.size()):
		var material = engine_materials[index]
		material.emission = (
			visual_settings.engine_glow_color
			if visual_settings.override_engine_color
			else engine_colors[index]
		)
		material.emission_energy_multiplier = (
			visual_settings.engine_glow_intensity
			* engine_multiplier
			* (
				1.0
				+ (
					sin(hover_time * TAU * visual_settings.engine_pulse_speed)
					* visual_settings.engine_pulse_amplitude
				)
			)
		)
	var phase: float = 1.7 if name == "EnemyShip" else 0.0
	# TUNE: 7.0 = seconds per hover loop; 0.07 = vertical travel in 3D units.
	position = rest_position + Vector3(0, sin(hover_time * TAU / 7.0 + phase) * 0.07, 0)
	# TUNE: Below 5 hull, add critical shaking; 0.012 below controls shake distance.
	if hull_strength < 5 and hull_strength > 0:
		position += Vector3(sin(hover_time * 43.0), sin(hover_time * 57.0), 0) * 0.012


func set_hull_strength(value: int) -> void:
	hull_strength = value
	# TUNE: Markings start below 15 hull, intensify below 5; 0.45 controls the mild coverage.
	damage_material.set_shader_parameter(
		"damage", 0.0 if value >= 15 else (1.0 if value < 5 else 0.45)
	)


# Duplicate per-instance materials so a hit/repair shader cannot change another ship's appearance.
func _ready() -> void:
	rest_position = position
	hull_material = $Body/Hull.material_override.duplicate()
	base_color = hull_material.albedo_color
	for part in body.get_children():
		if part is MeshInstance3D and part.name != "Engine":
			part.material_override = hull_material
	repair_material = ShaderMaterial.new()
	repair_material.shader = preload("res://shaders/repair_3d.gdshader")
	repair_material.set_shader_parameter("progress", -1.0)
	damage_material = ShaderMaterial.new()
	damage_material.shader = preload("res://shaders/hull_damage_3d.gdshader")
	hull_material.next_pass = damage_material
	damage_material.next_pass = repair_material
	shield_material = shield.material_override.duplicate()
	shield.material_override = shield_material
	shield_material.set_shader_parameter("formation", 1.0)
	shield_material.set_shader_parameter("hit", 0.0)
	_configure_engines()


func _configure_engines() -> void:
	engine_materials.clear()
	engine_colors.clear()
	for part in body.find_children("Engine*", "MeshInstance3D", true, false):
		if part.material_override is StandardMaterial3D:
			part.material_override = part.material_override.duplicate()
			part.material_override.emission_enabled = true
			engine_materials.append(part.material_override)
			engine_colors.append(part.material_override.emission)


func animate_hit(tween: Tween, hull_hit: bool, seconds: float) -> void:
	var origin: Vector3 = body.position
	tween.tween_method(
		func(p: float):
			var elapsed: float = p * seconds
			var shake: float = minf(1.0, elapsed / visual_settings.hull_shake_duration)
			body.position = (
				origin
				+ Vector3(
					0,
					(
						sin(shake * TAU * 3) * visual_settings.hull_shake_strength * (1.0 - shake)
						if hull_hit
						else 0.0
					),
					0
				)
			)
			if hull_hit:
				hull_material.albedo_color = base_color.lerp(
					visual_settings.hull_flash_color,
					(
						sin(minf(1.0, elapsed / visual_settings.hull_flash_duration) * PI)
						* visual_settings.hull_flash_opacity
					)
				),
		0.0,
		1.0,
		seconds
	)
	tween.tween_callback(
		func():
			body.position = origin
			hull_material.albedo_color = base_color
	)


func set_shield_strength(value: int) -> void:
	shield.visible = value > 0
	# TUNE: 10.0 = shield strength required for full bubble opacity.
	shield_material.set_shader_parameter("strength", clampf(value / 10.0, 0.0, 1.0))


func animate_shield(tween: Tween, seconds: float, increase: bool = false) -> void:
	var resting_tint = shield_material.get_shader_parameter("tint")
	if increase:
		shield_material.set_shader_parameter("keep_shell", not shield_was_offline)
		shield_material.set_shader_parameter("formation", 0.0)
		tween.tween_method(
			func(p: float): shield_material.set_shader_parameter("formation", p), 0.0, 1.0, seconds
		)
	else:
		shield_material.set_shader_parameter("tint", visual_settings.shield_impact_color)
		shield_material.set_shader_parameter(
			"ripple_strength", visual_settings.shield_ripple_strength
		)
		shield_material.set_shader_parameter("ripple_speed", visual_settings.shield_ripple_speed)
		shield_material.set_shader_parameter("impact_opacity", visual_settings.shield_flash_opacity)
		tween.tween_method(
			func(p: float): shield_material.set_shader_parameter("hit", p),
			0.001,
			1.0,
			minf(seconds, visual_settings.shield_flash_duration)
		)
	tween.tween_callback(
		func():
			shield_material.set_shader_parameter("formation", 1.0)
			shield_material.set_shader_parameter("hit", 0.0)
			shield_material.set_shader_parameter("tint", resting_tint)
	)


func animate_repair(tween: Tween, seconds: float) -> void:
	repair_material.set_shader_parameter("center_y", global_position.y)
	tween.tween_method(
		func(p: float): repair_material.set_shader_parameter("progress", p), 0.0, 1.0, seconds
	)
	tween.tween_callback(func(): repair_material.set_shader_parameter("progress", -1.0))


func animate_explosions(tween: Tween, seconds: float) -> void:
	# Small temporary flashes on actual hull surfaces; no physics or gameplay changes.
	var flashes: Array[MeshInstance3D] = []
	var hull_mesh: MeshInstance3D = $Body/Hull
	var faces: PackedVector3Array = hull_mesh.mesh.get_faces()
	var visible_faces: Array[int] = []
	var camera: Camera3D = get_viewport().get_camera_3d()
	for face_index in range(0, faces.size(), 3):
		var a: Vector3 = hull_mesh.to_global(faces[face_index])
		var b: Vector3 = hull_mesh.to_global(faces[face_index + 1])
		var c: Vector3 = hull_mesh.to_global(faces[face_index + 2])
		# Godot triangles use clockwise front-face winding.
		if camera == null or (c - a).cross(b - a).dot(camera.global_position - a) > 0.0:
			visible_faces.append(face_index)
	if visible_faces.is_empty():
		visible_faces.append(0)
	for i in range(5):
		var face: int = visible_faces.pick_random()
		var a: Vector3 = faces[face]
		var b: Vector3 = faces[face + 1]
		var c: Vector3 = faces[face + 2]
		var u: float = sqrt(randf())
		var v: float = randf()
		var flash := MeshInstance3D.new()
		flash.mesh = SphereMesh.new()
		flash.mesh.radius = 0.12
		flash.mesh.height = 0.24
		flash.mesh.radial_segments = 8
		flash.mesh.rings = 4
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1, 0.5, 0.08)
		flash.material_override = material
		hull_mesh.add_child(flash)
		flash.position = (
			a * (1.0 - u) + b * u * (1.0 - v) + c * u * v + (c - a).cross(b - a).normalized() * 0.06
		)
		flash.scale = Vector3.ONE * 0.001
		flashes.append(flash)
	tween.tween_method(
		func(p: float):
			for i in range(flashes.size()):
				var age: float = clampf((p - i * 0.1) / 0.6, 0.0, 1.0)
				flashes[i].scale = Vector3.ONE * maxf(0.001, sin(age * PI) * 1.8)
				flashes[i].material_override.albedo_color = Color(
					1, 0.55 * (1.0 - age), 0.05, 1.0 - age
				),
		0.0,
		1.0,
		seconds
	)
	tween.tween_callback(
		func():
			for flash in flashes:
				flash.queue_free()
	)


func set_hull_color(color: Color) -> void:
	# Each instance already owns a duplicated Hull material; effect materials stay untouched.
	base_color = color
	hull_material.albedo_color = color
