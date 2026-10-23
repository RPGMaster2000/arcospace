extends SceneTree
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func touch(point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.pressed = pressed
	root.push_input(event, true)
	await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	preload("res://scripts/ui/menu_preferences.gd").set_skip_cinematics(false)
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	menu.save_store.path = "user://cinematic_touch.json"
	root.add_child(menu)
	current_scene = menu
	await process_frame
	check(root.get_node("Music").current_track == "title", "Title screen plays title music")
	var center := Vector2(640, 350)
	await touch(center, true)
	check(menu.showcase.phase == menu.showcase.Phase.PRESS_TO_PLAY, "Android tap finishes fades without double advance")
	await touch(center, false)
	await touch(menu.get_node("Legend").get_global_rect().get_center(), true)
	await touch(menu.get_node("Legend").get_global_rect().get_center(), false)
	check(menu.info_overlay.shade.visible and menu.showcase.phase == menu.showcase.Phase.PRESS_TO_PLAY, "Legend tap is not consumed by intro")
	menu.info_overlay.dismiss()
	menu.showcase.camera_transition_duration = 0.05
	await touch(center, true)
	check(root.get_node("Music").fade_tween != null or root.get_node("Music").current_track in ["", "shipselect"], "Tap leaving title starts or completes music fade")
	await touch(center, false)
	await create_timer(0.7).timeout
	check(menu.showcase.phase == menu.showcase.Phase.SHIP_SELECTION, "Second screen tap opens selection through viewport GUI")
	check(root.get_node("Music").current_track == "shipselect", "Arrival at fleet starts ship-selection music")
	var overlay = menu.info_overlay
	overlay.show_legend()
	await process_frame
	await process_frame
	var scroll: ScrollContainer = overlay.body.get_parent()
	var origin: Vector2 = scroll.get_global_rect().get_center()
	await touch(origin, true)
	for step in range(1, 9):
		var drag := InputEventScreenDrag.new()
		drag.position = origin - Vector2(0, step * 18)
		drag.relative = Vector2(0, -18)
		drag.velocity = Vector2(0, -900)
		root.push_input(drag, true)
		await create_timer(0.02).timeout
	await touch(origin - Vector2(0, 144), false)
	var released: int = scroll.scroll_vertical
	await create_timer(0.12).timeout
	check(released > 0, "Legend scrolls when dragging over text")
	check(scroll.scroll_vertical > released, "Legend continues with kinetic scrolling after release")
	await touch(origin, true)
	var stopped: int = scroll.scroll_vertical
	await create_timer(0.06).timeout
	check(scroll.scroll_vertical == stopped, "A new touch stops momentum")
	await touch(origin, false)
	overlay.dismiss()
	for dimensions in [Vector2i(1280,720), Vector2i(960,540), Vector2i(1560,720), Vector2i(1680,720), Vector2i(686,384)]:
		root.size = dimensions
		for frame in range(4): await process_frame
		var info: Control = menu.get_node("Selection/Information")
		check(info.size.x <= menu.size.y * 16.0 / 9.0, "Information capped to 16:9 " + str(dimensions))
		var left: Control = menu.get_node("Selection/Information/Margin/Scroll/Column/Identity")
		var right: Control = menu.get_node("Selection/Information/Margin/Scroll/Column/Description")
		check(left.get_global_rect().end.x <= right.get_global_rect().position.x, "Information columns do not overlap")
	check(menu.showcase.rotation_degrees_per_second == 14.0 and menu.showcase.title_font_size == 152, "Double spin and logo defaults")
	check(menu.showcase.get_node("PlanetSunlight").light_cull_mask == menu.showcase.get_node("Planet").layers, "Planet lighting isolated from ships")
	menu.queue_free()
	await process_frame
	print("Cinematic touch: %d failures" % failures)
	quit(1 if failures else 0)
