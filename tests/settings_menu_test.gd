extends SceneTree
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func activate(control: Control, touch: bool = false) -> void:
	for pressed in [true, false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 0
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func capture(caption: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/settings-" + caption + ".png")


func run() -> void:
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	await settle()
	if "--quit-probe" in OS.get_cmdline_user_args():
		menu.settings_button.pressed.emit()
		menu.settings_button.menu.quit_button.pressed.emit()
		await create_timer(0.2).timeout
		push_error("Quit Game did not terminate the process")
		quit(1)
		return
	var music: Node = root.get_node("Music")
	var original_enabled: bool = music.enabled
	for dimensions in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(960,540), Vector2i(686,384)]:
		root.size = dimensions
		await settle()
		check(root.get_visible_rect().encloses(menu.settings_button.get_global_rect()), "Selection gear fits")
		await activate(menu.settings_button, dimensions.x == 960)
		var settings = menu.settings_button.menu
		check(settings.shade.visible and paused, "Settings opens and pauses gameplay")
		check(settings.main_menu_button.disabled, "Main Menu is disabled in the menu itself")
		check(settings.track_label.text.contains(music.current_title()), "Bundled track title displayed")
		check(music.player.can_process(), "Music remains active while gameplay is paused")
		check(is_instance_valid(settings.extra_settings), "Future settings have a dedicated container")
		await settle()
		check(root.get_visible_rect().encloses(settings.panel.get_global_rect()), "Settings panel fits landscape")
		for control in [settings.close_button, settings.music_toggle, settings.main_menu_button, settings.quit_button]:
			check(settings.panel.get_global_rect().encloses(control.get_global_rect()), "Settings actions fit panel")
		var was_enabled: bool = music.enabled
		await activate(settings.music_toggle, dimensions.x == 960)
		check(music.enabled != was_enabled and settings.music_toggle.button_pressed == music.enabled, "Music toggles with mouse/touch while paused")
		music.play_result(true)
		check(settings.track_label.text.contains("Mission Accomplished"), "Track title updates while open")
		await capture("menu-%d" % dimensions.x)
		var escape := InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		root.push_input(escape, true)
		await settle()
		check(not paused and not settings.shade.visible, "Escape closes settings and restores play")
		music.play_starmap()
	# Respect an existing pause and release our own pause if the owner is freed.
	paused = true
	menu.settings_button.menu.present()
	menu.settings_button.menu.dismiss()
	check(paused, "Closing settings preserves an earlier pause")
	paused = false
	menu.settings_button.menu.present()
	menu.free()
	check(not paused, "Freeing an open menu cannot leave gameplay paused")
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 777
	root.add_child(host)
	current_scene = host
	await settle()
	host.settings_button.pressed.emit()
	check(paused and host.settings_button.menu.track_label.text.contains("Star Map"), "Exploration uses the shared settings window")
	host.settings_button.menu.dismiss()
	var index: int = -1
	for slot in range(host.state.encounters.size()):
		if host.state.encounters[slot].kind == "battle":
			index = slot
			break
	host.start_battle(index)
	var board = host.battle
	await settle()
	check(not host.settings_button.is_visible_in_tree() and board.settings_button.is_visible_in_tree(), "Exactly one gear is visible in battle")
	for dimensions in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(960,540), Vector2i(686,384)]:
		root.size = dimensions
		await settle()
		var gear: Rect2 = board.settings_button.get_global_rect()
		check(root.get_visible_rect().encloses(gear), "Battle gear fits landscape")
		check(not gear.intersects(board.get_node("TurnLabel").get_global_rect()), "Gear clears turn counter")
		check(not gear.intersects(board.get_node("ModeLabel").get_global_rect()), "Gear clears enemy name")
		check(not gear.intersects(board.get_node("ModifierDisplay/Meter").get_global_rect()), "Gear clears hazard countdown")
		await capture("battle-%d" % dimensions.x)
		await activate(board.settings_button, dimensions.x == 960)
		check(paused and board.settings_button.menu.shade.visible, "Battle gear is clickable")
		await capture("battle-open-%d" % dimensions.x)
		board.settings_button.menu.dismiss()
	board.enemy_timer.start(1.0)
	board.settings_button.pressed.emit()
	var remaining: float = board.enemy_timer.time_left
	var turn: int = board.turn_number
	await create_timer(0.15).timeout
	check(is_equal_approx(board.enemy_timer.time_left, remaining) and board.turn_number == turn, "Enemy timer and turns freeze behind settings")
	board.settings_button.menu.dismiss()
	board.enemy_timer.stop()
	board.winner = "player"
	board.battle_effects.enabled = false
	board.refresh_display()
	await settle()
	check(not board.get_node("MatchResult/Panel/Configure").visible, "Victory removes ship-selection button")
	await activate(board.settings_button)
	check(paused and board.settings_button.menu.shade.visible, "Settings remains reachable over the victory shade")
	await activate(board.settings_button.menu.main_menu_button)
	check(not paused and current_scene.scene_file_path.ends_with("battle_setup.tscn"), "Battle Main Menu returns to ship selection and unpauses")
	check(not is_instance_valid(host) and not is_instance_valid(board), "Leaving battle removes the expedition")
	current_scene._start()
	await settle()
	var exploration = current_scene
	await activate(exploration.settings_button)
	await activate(exploration.settings_button.menu.main_menu_button)
	check(not paused and current_scene.scene_file_path.ends_with("battle_setup.tscn"), "Exploration Main Menu returns to ship selection")
	music.set_enabled(original_enabled)
	# Exercise real process termination in a child process, so this runner can report failures.
	var output: Array = []
	var exit_code: int = OS.execute(OS.get_executable_path(), [
		"--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tests/settings_menu_test.gd", "--", "--quit-probe"
	], output, true)
	check(exit_code == 0, "Quit Game terminates a real native game process")
	current_scene.free()
	print("Settings: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
