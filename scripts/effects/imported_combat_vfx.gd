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


const BEAM = preload("res://third_party/combat_vfx/binbun/BeamFX/effects/base/base_beam_vfx.tscn")

static func beam(actor: Node3D, target: Node3D) -> Node3D:
	var effect: Node3D = BEAM.instantiate()
	effect.name = "ImportedBeam"
	actor.get_parent().add_child(effect)
	# Vendor geometry/shaders are reused; particles, flares, impact ball and audio
	# are unnecessary here because BattleEffects already owns impact feedback.
	effect.set_physics_process(false)
	# Keep Binbun core and animated outer shader: disable only costly extras.
	effect.set("primary_color", Color(0.78, 0.96, 1.0))
	effect.set("secondary_color", Color(0.17, 0.64, 1.0))
	effect.set("tertiary_color", Color(0.08, 0.32, 0.92))
	effect.set("emission", 1.7)
	effect.set("beam_radius", 0.075)
	effect.set("pulse_strength", 0.025)
	var core: CylinderMesh = effect.get_node("BeamPivot/BeamScalor/BeamCore").mesh
	core.radial_segments = 12
	core.rings = 1
	for node in effect.find_children("*", "Node", true, false):
		if node is Light3D: node.visible = false
		if node is AudioStreamPlayer3D:
			node.stop()
			node.stream = null
		if node is GPUParticles3D:
			node.emitting = false
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is GeometryInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Small muzzle flash and animated outer shell add visual identity while
	# vendor flares, particles, audio and impact remain disabled on mobile.
	for path in ["BeamPivot/BeamFlare1", "BeamPivot/BeamFlare2", "BeamEndPivot"]:
		effect.get_node(path).hide()
	effect.get_node("BeamStart").scale = Vector3.ONE * 0.42
	update_beam(effect, actor, target, 0.0)
	return effect


static func update_beam(effect: Node3D, actor: Node3D, target: Node3D, progress: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(target): return
	var origin := actor.get_node_or_null("Body/Hull") as Node3D
	var end := target.get_node_or_null("Body/Hull") as Node3D
	effect.global_position = origin.global_position if origin != null else actor.global_position
	var endpoint: Vector3 = end.global_position if end != null else target.global_position
	if effect.global_position.distance_squared_to(endpoint) < 0.0001:
		effect.hide()
		return
	effect.get_node("BeamPivot").look_at(endpoint)
	effect.get_node("BeamPivot/BeamScalor").scale.z = effect.global_position.distance_to(endpoint)
	effect.call("_set_shader_param", "combat_opacity", 1.0 - smoothstep(0.65, 1.0, progress))
