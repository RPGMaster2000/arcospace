extends RefCounted
# Session-only experimental switch; never enters expedition saves.
static var requested: bool = true
var effect: CompositorEffect
var environment: WorldEnvironment

static func supported() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() != "gl_compatibility" and RenderingServer.get_rendering_device() != null

func attach(target: WorldEnvironment) -> void:
	environment = target
	if not supported(): return
	# Load only on RenderingDevice backends; Compatibility keeps the procedural sun.
	effect = load("res://addons/lens_effects/lens_flare_compositor_effect.gd").new()
	effect.enabled = false
	effect.effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	effect.access_resolved_color = true
	effect.access_resolved_depth = true
	effect.set("SampleCount", 20)
	effect.set("Effect_Multiplier", 0.35)
	effect.set("Effect_Easing", 0.5)
	effect.set("Anamorphic_Intensity", 12.0)
	effect.set("Anamorphic_Stretch", 0.25)
	effect.set("Anamorphic_Brightness", 0.25)
	effect.set("Weight", 0.06)
	effect.set("Decay", 0.95)
	effect.set("Density", 0.85)
	environment.compositor = Compositor.new()
	environment.compositor.compositor_effects = [effect]

func disable() -> void:
	if effect != null: effect.enabled = false

func update(active: bool, viewport: SubViewport, camera: Camera3D, sun: Node3D, color: Color) -> void:
	if effect == null: return
	disable()
	if effect.get("initialization_failed"): return
	if not active or not requested or not is_instance_valid(sun) or not sun.is_visible_in_tree(): return
	if viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED or camera.is_position_behind(sun.global_position): return
	var dimensions := Vector2(viewport.size)
	if dimensions.x <= 0 or dimensions.y <= 0: return
	var uv: Vector2 = camera.unproject_position(sun.global_position) / dimensions
	# Fade before the edge; the addon samples depth around the projected sun.
	var edge: float = minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
	var fade: float = smoothstep(0.02, 0.10, edge)
	if fade <= 0: return
	effect.set("sun_position", uv)
	effect.set("sun_dir_sign", 1.0)
	effect.set("sun_color", color)
	effect.set("Effect_Multiplier", 0.35 * fade)
	effect.enabled = true
