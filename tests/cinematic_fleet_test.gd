extends SceneTree
const Ships = preload("res://scripts/ships/ship_library.gd")
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(menu)
	check(not menu.settings_button.visible and not menu.get_node("Legend").visible, "Initial black frame has no menu chrome")
	check(menu.selected_ship == 0 and menu.showcase.models.size() == 6, "Endeavour and six persistent models")
	check(menu.find_children("*", "SubViewport", true, false).size() == 1, "One shared viewport")
	menu.showcase.skip_cinematics = true
	menu.showcase.advance()
	menu.showcase.advance()
	await menu.showcase.selection_ready
	var right := InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right)
	check(menu.selected_ship == 1, "Arrow navigation works while Begin has keyboard focus")
	menu.info_overlay.show_legend()
	root.push_input(right)
	check(menu.selected_ship == 1, "Legend input cannot browse behind modal")
	menu.info_overlay.dismiss()
	for index in range(6):
		menu._select(index)
		var model = menu.showcase.models[index].get_child(0)
		check(model.scene_file_path == Ships.PLAYERS[index].model_scene.resource_path, "Correct model order")
		check(not model.get_node("Shield").visible and not model.is_processing(), "No combat animation or shields")
		check(menu.get_node("Selection/Information/Margin/Scroll/Column/Description").text == Ships.PLAYERS[index].summary, "Profile description")
	menu._navigate(1)
	check(menu.selected_ship == 5 and menu.next_ship.disabled, "Right boundary does not wrap")
	for step in range(12): menu._navigate(-1)
	check(menu.selected_ship == 0 and menu.previous_ship.disabled, "Rapid retarget ends at left boundary")
	await create_timer(0.65).timeout
	check(menu.showcase.camera.position.is_equal_approx(menu.showcase.selection_anchor.position), "Latest selection camera target")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://fleet-stage-b.png")
	menu.free()
	print("Cinematic fleet: %d failures" % failures)
	quit(1 if failures else 0)
