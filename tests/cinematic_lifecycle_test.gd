extends SceneTree
const Save = preload("res://scripts/persistence/expedition_save.gd")
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var store = Save.new()
	store.path = "user://cinematic_lifecycle.json"
	var state = preload("res://scripts/expedition_state.gd").new()
	state.start(3, preload("res://encounters/expedition_rules.tres"), 98765)
	check(store.save_run(state), "Existing run saved")
	var original: String = FileAccess.get_file_as_string(store.path)
	for phase in [0, 1, 2]:
		var menu = load("res://scenes/battle_setup.tscn").instantiate()
		menu.save_store = store
		root.add_child(menu)
		current_scene = menu
		if phase >= 1: menu.showcase.advance()
		if phase == 2: menu.showcase.advance()
		root.size = Vector2i(1560,720)
		await process_frame
		menu.queue_free()
		await process_frame
		await process_frame
		check(FileAccess.get_file_as_string(store.path) == original, "Closing intro/camera cannot overwrite run")
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	menu.save_store = store
	root.add_child(menu)
	current_scene = menu
	menu.showcase.skip_cinematics = true
	menu.showcase.advance()
	menu.showcase.advance()
	await menu.showcase.selection_ready
	await process_frame
	menu._request_new()
	check(menu.overwrite_confirmation.visible, "Existing run always asks")
	menu.overwrite_confirmation.canceled.emit()
	menu.overwrite_confirmation.hide()
	menu._navigate(1)
	check(FileAccess.get_file_as_string(store.path) == original, "Cancel and fleet browsing preserve save")
	menu.continue_fade_duration = 0.001
	menu.map_reveal_duration = 2.0
	menu.showcase.skip_cinematics = false
	menu._continue_expedition()
	for frame in range(8): await process_frame
	check(current_scene != menu and paused, "Destination locked during reveal")
	current_scene.queue_free()
	await process_frame
	check(not paused, "Exiting during reveal restores pause ownership")
	store.clear_run()
	print("Cinematic lifecycle: %d failures" % failures)
	quit(1 if failures else 0)
