extends SceneTree
# Regression for pointer double cues, preview layering, and menu chrome sizing.
var checks: int = 0
var failures: int = 0
var sfx: Node

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func reset_audio() -> void:
	sfx.stop_all()
	sfx._last_played.clear()
	sfx._ui_confirm_frame = -10

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/polish")
	root.get_texture().get_image().save_png("res://.godot/testlogs/polish/" + name + ".png")

func run() -> void:
	await process_frame
	sfx = root.get_node("Sfx")
	var old_volume: float = sfx.volume
	sfx.set_volume(1.0, false)
	for id in [&"ui_select", &"ui_confirm"]:
		check(is_equal_approx(db_to_linear(sfx.catalog.find_event(id).volume_db + 5.0), 0.5), "UI amplitude halved: " + str(id))
	var screen := Control.new()
	root.add_child(screen)
	current_scene = screen
	var button := Button.new()
	button.text = "Test"
	screen.add_child(button)
	sfx.bind_button(button)
	reset_audio()
	button.mouse_entered.emit()
	check(sfx._last_played.is_empty(), "Pointer hover is silent")
	button.grab_focus()
	button.pressed.emit()
	await process_frame
	check(sfx._last_played.has(&"ui_confirm") and not sfx._last_played.has(&"ui_select"), "Pointer focus plus click produces only confirmation")
	reset_audio()
	button.release_focus()
	await process_frame
	button.grab_focus()
	await process_frame
	await process_frame
	check(sfx._last_played.has(&"ui_select"), "Keyboard/controller focus retains navigation cue")
	reset_audio()
	# Connect the specific action after the shared binding: callback order must not double-play.
	button.pressed.connect(func(): sfx.play_event(&"upgrade_acquired", screen))
	button.pressed.emit()
	await process_frame
	check(not sfx._last_played.has(&"ui_confirm"), "Specific action cue suppresses extra click confirmation")
	screen.free()
	for dimensions in [Vector2i(1280,720), Vector2i(960,540), Vector2i(686,384), Vector2i(1680,720)]:
		root.size = dimensions
		var menu = load("res://scenes/battle_setup.tscn").instantiate()
		root.add_child(menu)
		current_scene = menu
		menu.showcase._stop_tween()
		for phase in [menu.showcase.Phase.PRESS_TO_PLAY, menu.showcase.Phase.SHIP_SELECTION]:
			menu.showcase.phase = phase
			menu.get_node("Selection").visible = phase == menu.showcase.Phase.SHIP_SELECTION
			menu._layout()
			await process_frame
			var legend: Control = menu.get_node("Legend")
			var gear: Control = menu.settings_button
			check(not legend.get_global_rect().intersects(gear.get_global_rect()), "Reference and gear are separate: " + str(dimensions))
			check(root.get_visible_rect().encloses(legend.get_global_rect()) and root.get_visible_rect().encloses(gear.get_global_rect()), "Both controls fit: " + str(dimensions))
			await capture("menu-%d-%d" % [dimensions.x, phase])
		menu.free()
	root.size = Vector2i(1280,720)
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {"player_ship":0, "enemy_ship":0, "modifier":0}
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	current_scene = board
	board.enemy_timer.stop()
	board.get_node("ModifierDisplay").cinematic_enabled = false
	var card = board.get_node(board.card_slots[0])
	card.card_data = preload("res://scripts/cards/card_library.gd").CARDS[11]
	board.hand.cards[0] = card.card_data
	board.refresh_display()
	await process_frame
	var snapshot: String = str(board._both_states())
	card.hold_input._hold()
	await create_timer(0.3).timeout
	var preview = board.hud.tactical
	check(preview.target_glows.size() >= 2, "Payment and shield damage have target glows")
	for glow in preview.target_glows:
		check(glow.get_parent() is Label and glow.show_behind_parent, "Glow draws behind target text")
		check(glow.mouse_filter == Control.MOUSE_FILTER_IGNORE and glow.material is ShaderMaterial, "Glow is an input-transparent shader")
		var tint: Color = glow.material.get_shader_parameter("tint")
		if glow.get_parent().name == "energy": check(tint.b > tint.r, "Energy cost glows blue")
		if glow.get_parent().name == "EnemyShieldsLabel": check(tint.r > tint.b, "Shield damage glows warm/red")
	check(str(board._both_states()) == snapshot, "Inspection glow changes no combat state")
	await capture("battle-glows")
	preview.dismiss(true)
	check(preview.target_glows.is_empty() and preview.target_marks.is_empty(), "Dismiss removes all temporary highlights")
	board.free()
	sfx.set_volume(old_volume, false)
	print("UI feedback: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
