extends SceneTree
# Render with a display driver for the complete visual evidence set.
var failures: int = 0
var screenshots: String = "res://.godot/testlogs/cinematic"
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(screenshots + "/" + label + ".png") == OK, "Capture " + label)
func settle() -> void:
	for frame in range(4): await process_frame
func run() -> void:
	if DisplayServer.get_name() != "headless": DirAccess.make_dir_recursive_absolute(screenshots)
	preload("res://scripts/ui/menu_preferences.gd").set_skip_cinematics(false)
	root.size = Vector2i(1280, 720)
	var store = preload("res://scripts/persistence/expedition_save.gd").new()
	store.path = "user://cinematic_visual.json"
	store.clear_run()
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	menu.save_store = store
	root.add_child(menu)
	current_scene = menu
	await capture("00-black")
	menu.showcase.phase_tween.pause()
	menu.showcase.phase_tween.custom_step(2.0)
	await capture("01-starfield")
	menu.showcase.advance()
	await capture("02-title")
	menu.showcase.camera_transition_duration = 0.1
	menu.showcase.advance()
	await menu.showcase.selection_ready
	for dimensions in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1560,720), Vector2i(1680,720), Vector2i(686,384)]:
		root.size = dimensions
		await settle()
		for index in [0, 2, 5]:
			menu._select(index)
			menu.showcase.select_ship(index, true)
			await settle()
			var bounds: Rect2 = root.get_visible_rect()
			for button in [menu.start_button, menu.deck_button, menu.previous_ship, menu.next_ship, menu.settings_button]:
				check(bounds.encloses(button.get_global_rect()), "Controls fit " + str(dimensions))
			check(not menu.previous_ship.get_global_rect().intersects(menu.deck_button.get_global_rect()), "Navigation avoids footer")
			check(menu.get_node("Selection/Information").get_global_rect().end.y < menu.start_button.get_global_rect().position.y, "Information and actions separated")
			var selected: Node3D = menu.showcase.models[index].get_child(0)
			for part in selected.get_node("Body").find_children("*", "MeshInstance3D", true, false):
				for corner in range(8):
					var point: Vector3 = part.to_global(part.mesh.get_aabb().get_endpoint(corner))
					var screen: Vector2 = menu.showcase.camera.unproject_position(point)
					check(bounds.has_point(screen) and screen.y < bounds.size.y * 0.55, "Selected geometry fits upper showcase " + str(index))
			await capture("03-fleet-%dx%d-%d" % [dimensions.x, dimensions.y,index])
	root.size = Vector2i(1280,720)
	menu._select(0)
	menu.showcase.select_ship(0, true)
	menu.showcase.rotation_degrees_per_second = 0
	menu._start()
	await menu.showcase.phase_tween.step_finished
	await capture("04-departure-heading")
	await menu.showcase.phase_tween.step_finished
	# Pause midway through acceleration for a reproducible frame.
	menu.showcase.phase_tween.pause()
	await process_frame
	menu.showcase.phase_tween.custom_step(0.35)
	await capture("05-acceleration")
	menu.showcase.phase_tween.play()
	await menu.showcase.departure_finished
	await create_timer(0.4, true).timeout
	await capture("06-white-map-transition")
	await create_timer(1.1, true).timeout
	await capture("07-star-system-map")
	check(current_scene != menu and not paused, "Cinematic finishes on unlocked map")
	current_scene.queue_free()
	await process_frame
	store.clear_run()
	print("Cinematic visual: %d failures" % failures)
	quit(1 if failures else 0)
