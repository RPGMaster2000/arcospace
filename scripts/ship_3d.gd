extends Node3D

# RESPONSIBILITY: Animate the prototype mesh; never change combat state.
# BattleEffects owns these tweens, so existing turn timing stays intact.
@onready var body: Node3D = $Body
@onready var shield: MeshInstance3D = $Shield
var hull_material: StandardMaterial3D
var shield_material: ShaderMaterial
var repair_material: ShaderMaterial
var base_color: Color

func _ready() -> void:
	hull_material = $Body/Hull.material_override.duplicate()
	base_color = hull_material.albedo_color
	for part in body.get_children():
		if part is MeshInstance3D and part.name != "Engine":
			part.material_override = hull_material
	repair_material = ShaderMaterial.new()
	repair_material.shader = preload("res://shaders/repair_3d.gdshader")
	repair_material.set_shader_parameter("progress", -1.0)
	hull_material.next_pass = repair_material
	shield_material = shield.material_override.duplicate()
	shield.material_override = shield_material
	shield_material.set_shader_parameter("formation", 1.0)
	shield_material.set_shader_parameter("hit", 0.0)

func animate_hit(tween: Tween, hull_hit: bool, seconds: float) -> void:
	var origin: Vector3 = body.position
	tween.tween_method(func(p: float):
		body.position = origin + Vector3(0, sin(p * TAU * 3) * 0.08 * (1.0 - p), 0)
		if hull_hit:
			hull_material.albedo_color = base_color.lerp(Color(1, 0.08, 0.04), sin(p * PI)),
		0.0, 1.0, seconds)
	tween.tween_callback(func():
		body.position = origin
		hull_material.albedo_color = base_color)

func set_shield_strength(value: int) -> void:
	shield.visible = value > 0
	shield_material.set_shader_parameter("strength", clampf(value / 10.0, 0.0, 1.0))

func animate_shield(tween: Tween, seconds: float, increase: bool = false) -> void:
	if increase:
		shield_material.set_shader_parameter("formation", 0.0)
		tween.tween_method(func(p: float): shield_material.set_shader_parameter("formation", p), 0.0, 1.0, seconds)
	else:
		tween.tween_method(func(p: float):
			shield_material.set_shader_parameter("hit", absf(sin(p * PI * 6)) * (1.0 - p)), 0.0, 1.0, seconds)
	tween.tween_callback(func():
		shield_material.set_shader_parameter("formation", 1.0)
		shield_material.set_shader_parameter("hit", 0.0))

func animate_repair(tween: Tween, seconds: float) -> void:
	repair_material.set_shader_parameter("center_y", global_position.y)
	tween.tween_method(func(p: float): repair_material.set_shader_parameter("progress", p), 0.0, 1.0, seconds)
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
		flash.position = a * (1.0 - u) + b * u * (1.0 - v) + c * u * v + (c - a).cross(b - a).normalized() * 0.06
		flash.scale = Vector3.ONE * 0.001
		flashes.append(flash)
	tween.tween_method(func(p: float):
		for i in range(flashes.size()):
			var age: float = clampf((p - i * 0.1) / 0.6, 0.0, 1.0)
			flashes[i].scale = Vector3.ONE * maxf(0.001, sin(age * PI) * 1.8)
			flashes[i].material_override.albedo_color = Color(1, 0.55 * (1.0 - age), 0.05, 1.0 - age), 0.0, 1.0, seconds)
	tween.tween_callback(func():
		for flash in flashes:
			flash.queue_free())
