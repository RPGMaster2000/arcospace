extends SceneTree
const Lens = preload("res://scripts/presentation/star_system/sun_lens_effects.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(8): await process_frame
func run() -> void:
	# A headless import can report success while a GLSL include failed. Check
	# the imported resource itself before any renderer-specific assertions.
	var shader := load("res://addons/lens_effects/lens_flares.glsl") as RDShaderFile
	check(shader != null and shader.base_error.is_empty() and shader.get_version_list().has(&""), "Lens shader imported a default SPIR-V version")
	if shader != null and shader.get_version_list().has(&""):
		check(shader.get_spirv().get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE).is_empty(), "Lens compute shader compiles")
	root.size = Vector2i(961, 541) # Non-workgroup-aligned size exercises shader bounds.
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer did not fall back")
	var map = preload("res://scenes/star_system_3d.tscn").instantiate()
	root.add_child(map)
	map.player_profile = preload("res://ships/player/endeavour.tres")
	map.configure([], -1, 0.1, 1042)
	await settle()
	var effect: CompositorEffect = map.sun_lens.effect
	if not Lens.supported():
		check(effect == null and map.sun_lens.environment.compositor == null, "Unsupported renderer creates no compositor")
		check(is_instance_valid(map.objects[-100]), "Procedural sun survives fallback")
	else:
		check(effect != null and effect.enabled, "Visible map enables compositor")
		check(effect.get("SampleCount") == 20, "Conservative sample count")
		check(is_equal_approx(effect.get("Anamorphic_Brightness"), 0.36) and is_equal_approx(effect.get("Weight"), 0.075), "Higher contrast uses scalar tuning without changing samples")
		check(map.viewport.world_3d != root.world_3d, "Effect world is isolated from other scenes")
		var uv: Vector2 = map.camera.unproject_position(map.objects[-100].global_position) / Vector2(map.viewport.size)
		check(effect.get("sun_position").is_equal_approx(uv), "Sun projection uses SubViewport dimensions")
		var pipeline: RID = effect.get("shader_pipeline")
		check(pipeline.is_valid(), "Rendered frames created the shader pipeline")
		check(effect.get("composite_pipeline").is_valid(), "Mobile-safe additive composite pipeline exists")
		map.camera.position.x += 1.0
		await settle()
		check(effect.get("shader_pipeline") == pipeline, "Camera movement reuses the GPU pipeline")
		Lens.requested = false
		await settle()
		check(not effect.enabled, "Performance toggle disables dispatch")
		Lens.requested = true
		await settle()
		check(effect.enabled, "Performance toggle restores dispatch")
		map.set_active(false)
		check(not effect.enabled, "Inactive map disables effect immediately")
		map.set_active(true)
		await settle()
		check(effect.enabled, "Reactivated map restores effect")
		map.hide()
		check(not effect.enabled, "Hidden map disables effect immediately")
		map.show()
		var sun: Node3D = map.objects[-100]
		var origin: Vector3 = sun.global_position
		sun.global_position = map.camera.global_position + map.camera.global_basis.z * 10.0
		await settle()
		check(not effect.enabled, "Sun behind camera disables dispatch")
		sun.global_position = map.camera.global_position - map.camera.global_basis.z * 10.0 + map.camera.global_basis.x * 100.0
		await settle()
		check(not effect.enabled, "Off-screen sun disables dispatch")
		sun.global_position = origin
		root.size = Vector2i(803, 453)
		await settle()
		check(effect.enabled, "Resize restores visible effect")
		uv = map.camera.unproject_position(sun.global_position) / Vector2(map.viewport.size)
		check(effect.get("sun_position").is_equal_approx(uv), "Projection follows resize")
	map.free()
	Lens.requested = true
	await settle()
	print("Star-system lens effects: %d failures" % failures)
	quit(1 if failures else 0)
