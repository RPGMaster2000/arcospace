extends RefCounted
# Presentation-only adapter. BattleEffects owns duration and cancellation.
const HIT = preload("res://third_party/combat_vfx/binbun/StylizedHitFX/effects/hit/vfx_hit_01.tscn")

static func hull_hit(ship: Node3D, seconds: float) -> Node3D:
	var effect: Node3D = HIT.instantiate()
	effect.name = "ImportedHullHit"
	effect.set("autoplay", false)
	effect.set("one_shot", true)
	ship.add_child(effect)
	var camera: Camera3D = ship.get_viewport().get_camera_3d()
	# Put a small flash on the camera-facing surface, rather than inside the hull.
	var hull := ship.get_node_or_null("Body/Hull") as MeshInstance3D
	var center: Vector3 = hull.global_position if hull != null else ship.global_position
	var radius: float = 0.3
	if hull != null:
		radius = hull.get_aabb().size.length() * hull.global_basis.get_scale().length() / sqrt(3.0) * 0.25
	var direction: Vector3 = (camera.global_position - center).normalized() if camera != null else Vector3.FORWARD
	effect.global_position = center + direction * radius
	effect.scale = Vector3.ONE * 0.3
	if camera != null: effect.look_at(camera.global_position, Vector3.UP)
	for node in effect.find_children("*", "Node", true, false):
		if node is Light3D: node.visible = false
		if node is AudioStreamPlayer3D: node.stream = null
		if node is GeometryInstance3D: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if node is GPUParticles3D:
			node.amount = mini(node.amount, 8)
			node.one_shot = true
	effect.set("proximity_fade", false)
	effect.set("light_energy", 0.0)
	effect.set("emission", 0.8)
	# The 1.6-second source animation includes an idle tail; particles last 0.7s.
	effect.set("speed_scale", 0.7 / maxf(seconds, 0.05))
	# Use the animation directly: the vendor play() coroutine outlives cancelled hits.
	effect.get_node("AnimationPlayer").play("main")
	return effect
