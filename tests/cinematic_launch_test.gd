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
	store.path = "user://cinematic_launch.json"
	store.clear_run()
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	menu.save_store = store
	root.add_child(menu)
	current_scene = menu
	menu.showcase.advance()
	menu.showcase.skip_cinematics = true
	menu.showcase.advance()
	await menu.showcase.selection_ready
	menu.showcase.skip_cinematics = false
	menu.showcase.orientation_duration = 0.03
	menu.showcase.departure_pause_duration = 0.1
	menu.map_reveal_duration = 0.1
	menu.white_fade_duration = 0.1
	menu.showcase.get_node("Fleet").rotation.y = 0.15
	menu._select(2)
	menu._start()
	var version: int = store.revision
	menu._start()
	menu._navigate(1)
	check(menu.showcase.phase == menu.showcase.Phase.LAUNCHING and menu.selected_ship == 2 and menu.start_button.disabled, "Launch locks actions and repeated input")
	check(store.revision == version, "Only one initialized run committed")
	await menu.showcase.phase_tween.step_finished
	var mount: Node3D = menu.showcase.selected_model
	var direction: Vector3 = mount.global_basis.x.normalized()
	var before: Vector2 = menu.showcase.camera.unproject_position(mount.global_position)
	var after: Vector2 = menu.showcase.camera.unproject_position(mount.global_position + direction)
	check(after.x > before.x and after.y < before.y, "Forward heading points toward screen upper-right")
	await menu.showcase.departure_finished
	check(not Rect2(Vector2.ZERO, Vector2(root.size)).has_point(menu.showcase.camera.unproject_position(mount.global_position)), "Acceleration exits viewport")
	await create_timer(0.15).timeout
	var expedition = current_scene
	check(expedition != menu and expedition.state.player_ship == 2, "Launch uses selected ship and map")
	check(paused, "Map stays locked during reveal")
	await create_timer(0.2, true).timeout
	check(not paused and expedition.view_kind != "battle", "Reveal restores interaction")
	check(expedition._save_and_quit(), "Return to menu")
	await process_frame
	menu = current_scene
	menu.showcase.skip_cinematics = true
	menu.showcase.advance()
	menu.showcase.advance()
	await menu.showcase.selection_ready
	menu._select(5)
	menu.continue_fade_duration = 0.02
	menu.map_reveal_duration = 0.02
	menu._continue_expedition()
	check(menu.showcase.phase == menu.showcase.Phase.LOADING, "Continue skips departure")
	await create_timer(0.2, true).timeout
	check(current_scene.state.player_ship == 2, "Continue retains saved ship despite highlighted Orion")
	current_scene.queue_free()
	await process_frame
	store.clear_run()
	print("Cinematic launch: %d failures" % failures)
	quit(1 if failures else 0)
