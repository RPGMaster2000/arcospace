extends SceneTree
const CONTROLLER = preload("res://scripts/visual/battlefield_grading.gd")
const PRESET = preload("res://scripts/visual/battlefield_grade_preset.gd")
const BOARD = preload("res://scenes/board_3d.tscn")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, text: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(text)
func settle() -> void:
	for i in range(6): await process_frame
func screenshot() -> Image:
	await settle()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func make_board(kind: int) -> Control:
	var board = BOARD.instantiate()
	board.setup_settings = {"modifier": kind}
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
	board.get_node("CardMotion").settings.enabled = false
	board.get_node("ModifierDisplay").cinematic_enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	board.process_mode = Node.PROCESS_MODE_DISABLED
	var backdrop = board.get_node("BattleView/Viewport/Battlefield/MeshInstance3D")
	backdrop.material_override.set_shader_parameter("animation_speed", 0.0)
	return board
func run() -> void:
	root.size = Vector2i(1280, 720)
	var render: bool = DisplayServer.get_name() != "headless"
	var paths: Dictionary = {}
	var seen: Array = []
	for kind in range(6):
		var board = make_board(kind)
		var grade = board.get_node("BattleView")
		var preset: Resource = CONTROLLER.PRESETS[kind]
		check(grade.preset == preset, "Correct environment resource")
		check(not paths.has(preset.resource_path), "Independent preset file")
		paths[preset.resource_path] = true
		check(not seen.has(preset), "Independent resource identity")
		seen.append(preset)
		check(grade.material is ShaderMaterial, "Grading enabled on viewport container")
		check(board.get_node("BattleView/Viewport/Battlefield/WorldEnvironment").compositor == null, "No unsupported compute or other effects attached")
		var before: Dictionary = board._both_states()
		var rng_state: int = board.modifier.rng.state
		var changed: Resource = preset.duplicate(true)
		grade.preset = changed
		var updates: int = grade.parameter_updates
		await settle()
		check(grade.parameter_updates == updates, "No per-frame uniform uploads")
		changed.contrast = changed.contrast
		check(grade.parameter_updates == updates, "Unchanged values do not upload uniforms")
		changed.contrast += 0.01
		check(grade.parameter_updates == updates+1, "Resource edit updates immediately")
		check(preset.contrast != changed.contrast, "Editing local copy does not change shared preset")
		check(board._both_states() == before and board.modifier.rng.state == rng_state, "Grading cannot alter combat or RNG")
		check(board.get_node("PlayerResource1").material == null, "Resource icons are outside grading material")
		changed.strength = 0
		check(grade.material == null, "Strength zero bypasses shader")
		changed.strength = 1
		changed.enabled = false
		check(grade.material == null, "Disabled bypasses shader")
		var neutral = PRESET.new()
		grade.preset = neutral
		check(grade.material == null, "Neutral settings bypass shader exactly")
		var identity: Image
		if render: identity = await screenshot()
		neutral.strength = 0
		if render:
			var zero: Image = await screenshot()
			check(identity.get_data() == zero.get_data(), "Neutral and zero-strength frames identical")
		grade.set_environment(kind)
		if render:
			var graded: Image = await screenshot()
			check(graded.get_region(Rect2i(0,395,1280,325)).get_data() == identity.get_region(Rect2i(0,395,1280,325)).get_data(), "Cards and bottom UI pixels unchanged")
			check(graded.get_region(Rect2i(150,60,950,240)).get_data() != identity.get_region(Rect2i(150,60,950,240)).get_data(), "Preset visibly changes battlefield")
			DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
			graded.save_png("res://.godot/testlogs/grade-%d.png" % kind)
			identity.save_png("res://.godot/testlogs/grade-%d-original.png" % kind)
		grade.set_environment(0)
		check(grade.preset == CONTROLLER.PRESETS[0], "Returning to Standard clears previous environment")
		var material: Material = grade.grade_material
		board.free()
		var fresh = make_board(0)
		check(fresh.get_node("BattleView").grade_material != material, "Per-encounter materials isolated")
		fresh.free()
	var original_contrasts: Array = []
	for item in CONTROLLER.PRESETS: original_contrasts.append(item.contrast)
	var ion: Resource = CONTROLLER.PRESETS[2]
	ion.contrast = 1.23
	for index in range(6):
		if index != 2:
			check(CONTROLLER.PRESETS[index].contrast == original_contrasts[index], "Editing Ion does not modify another preset")
	ion.contrast = original_contrasts[2]
	var saved: Resource = CONTROLLER.PRESETS[2].duplicate(true)
	saved.contrast = 1.17
	saved.shadow_range = Vector2(0.4,0.1)
	check(ResourceSaver.save(saved, "res://.godot/grade-persistence-test.tres") == OK, "Preset saves")
	var loaded: Resource = ResourceLoader.load("res://.godot/grade-persistence-test.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded.contrast == 1.17 and loaded.shadow_range == saved.shadow_range, "Inspector values survive reload")
	check(loaded.parameters().shadow_range.x < loaded.parameters().shadow_range.y, "Ranges sanitized without invalid smoothstep")
	DirAccess.remove_absolute("res://.godot/grade-persistence-test.tres")
	var preview = load("res://scenes/tools/color_grading_preview.tscn").instantiate()
	root.add_child(preview)
	for kind in range(6):
		preview._show(kind)
		check(preview.board.get_node("BattleView").preset.parameters() == CONTROLLER.PRESETS[kind].parameters(), "F6 preview loads saved environment")
	preview.free()
	await settle()
	print("Color grading: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
