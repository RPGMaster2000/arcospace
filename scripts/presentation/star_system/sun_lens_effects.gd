extends RefCounted
# Session-only experimental switch; never enters expedition saves.
static var requested: bool = true
var effect: CompositorEffect
var environment: WorldEnvironment
var calibration: Resource

static func supported() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_current_rendering_method() != "gl_compatibility" and RenderingServer.get_rendering_device() != null

func attach(target: WorldEnvironment, settings: Resource = null) -> void:
	calibration = settings if settings != null else load("res://resources/presentation/star_system_settings.tres")
	environment = target
	if not supported(): return
	# Load only on RenderingDevice backends; Compatibility keeps the procedural sun.
	effect = load("res://addons/lens_effects/lens_flare_compositor_effect.gd").new()
	effect.enabled = false
	effect.effect_callback_type = CompositorEffect.EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	effect.access_resolved_color = true
	effect.access_resolved_depth = true
	effect.set("SampleCount", 20)
	effect.set("Effect_Multiplier", calibration.lens_flare_multiplier)
	effect.set("Effect_Easing", 0.5)
	effect.set("Anamorphic_Intensity", 7.0)
	effect.set("Anamorphic_Stretch", 0.25)
	effect.set("Anamorphic_Brightness", 0.36)
	effect.set("Weight", 0.095)
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
	# Addon depth taps and radial sampler clamp at the border. Fade only within
	# the final viewport sliver, and never dispatch with an offscreen source.
	var edge: float = minf(minf(uv.x, 1.0 - uv.x), minf(uv.y, 1.0 - uv.y))
	var fade: float = edge_weight(edge, calibration.lens_edge_fade_range)
	if fade <= 0: return
	effect.set("sun_position", uv)
	effect.set("sun_dir_sign", 1.0)
	effect.set("sun_color", color)
	effect.set("Effect_Multiplier", calibration.lens_flare_multiplier * fade)
	effect.enabled = true


static func edge_weight(distance: float, attenuation: Vector2) -> float:
	if distance <= 0.0: return 0.0
	var low: float = maxf(0.0, minf(attenuation.x, attenuation.y))
	var high: float = maxf(low + 0.0001, maxf(attenuation.x, attenuation.y))
	return smoothstep(low, high, distance)
