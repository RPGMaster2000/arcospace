extends Node3D

# RESPONSIBILITY: Animate the prototype mesh; never change combat state.
# BattleEffects owns these tweens, so existing turn timing stays intact.
@onready var body: Node3D = $Body
@onready var shield: MeshInstance3D = $Shield
var hull_material: StandardMaterial3D
var shield_material: StandardMaterial3D
var base_color: Color

func _ready() -> void:
	hull_material = $Body/Hull.material_override.duplicate()
	base_color = hull_material.albedo_color
	for part in body.get_children():
		if part is MeshInstance3D and part.name != "Engine":
			part.material_override = hull_material
	shield_material = shield.material_override.duplicate()
	shield.material_override = shield_material

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

func animate_shield(tween: Tween, seconds: float) -> void:
	var original: Vector3 = shield.scale
	tween.tween_method(func(p: float):
		var pulse: float = absf(sin(p * PI * 6)) * (1.0 - p)
		shield.scale = original * (1.0 + pulse * 0.04)
		shield_material.albedo_color.a = 0.18 + pulse * 0.32,
		0.0, 1.0, seconds)
	tween.tween_callback(func():
		shield.scale = original
		shield_material.albedo_color.a = 0.18)

func animate_repair(tween: Tween, seconds: float) -> void:
	tween.tween_method(func(p: float):
		hull_material.albedo_color = base_color.lerp(Color(0.5, 1, 0.8), sin(p * PI)),
		0.0, 1.0, seconds)
	tween.tween_callback(func(): hull_material.albedo_color = base_color)
