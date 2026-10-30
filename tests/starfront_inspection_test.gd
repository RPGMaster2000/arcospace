extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)
func mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	root.push_input(event, true)
func run() -> void:
	root.content_scale_size = Vector2i(1280,720)
	root.size = Vector2i(1280,720)
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 42042
	root.add_child(host)
	await create_timer(1.2).timeout
	var map = host.star_map
	var poi := -1
	for i in range(3, host.state.encounters.size()):
		if host.state.encounters[i].kind == "poi" and map.markers[i].visible:
			poi = i
			break
	check(poi >= 0, "Visible PoI for touch inspection")
	var gesture_point: Vector2 = map.markers[poi].get_global_rect().get_center()
	touch(gesture_point, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = gesture_point + Vector2(30, 10)
	drag.relative = Vector2(30, 10)
	root.push_input(drag, true)
	await create_timer(0.5).timeout
	check(not host.inspecting and host.state.travel_destination == -1, "A drag over a marker cancels the hold without travelling")
	touch(drag.position, false)
	await create_timer(0.4).timeout
	gesture_point = map.markers[poi].get_global_rect().get_center()
	touch(gesture_point, true)
	var second := InputEventScreenTouch.new()
	second.index = 1
	second.position = gesture_point + Vector2(60, 0)
	second.pressed = true
	root.push_input(second, true)
	await create_timer(0.5).timeout
	check(not host.inspecting and host.state.travel_destination == -1, "A pinch cancels the hold without travelling")
	second.pressed = false
	root.push_input(second, true)
	touch(gesture_point, false)
	await create_timer(1.0).timeout
	var pos: Vector3 = map.ship.position
	var camera: Vector3 = map.camera.position
	var enemy: Vector3 = host.state.defense.units[0].position
	var before: Dictionary = host.state.defense.snapshot()
	var at: Vector2 = map.markers[poi].get_global_rect().get_center()
	touch(at, true)
	await create_timer(0.55).timeout
	check(host.inspecting and host.selected_encounter == poi, "Long touch opens the existing PoI preview")
	check(map.ship.position == pos and map.camera.position == camera and host.state.defense.units[0].position == enemy, "Inspection keeps ship, camera and strategic time fixed")
	check(host.approach_buttons.all(func(button): return button.disabled), "PoI actions are read-only")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
		root.get_texture().get_image().save_png("res://.godot/testlogs/starfront-v11-inspect.png")
	check(host.state.defense.snapshot() == before, "Opening and holding an inspection adds no strategic penalty")
	touch(at, false)
	await create_timer(0.7).timeout
	check(host.state.travel_destination == -1 and not host.state.encounters[poi].completed, "Long-touch release neither travels nor resolves")
	var outside := Vector2(480, 475)
	for y in range(100, 500, 40):
		for x in range(100, 700, 40):
			var candidate := Vector2(x, y)
			if not map.point_is_reserved(candidate) and map.nearest_marker(candidate) == -1 and not map._point_on_object(candidate):
				outside = candidate
				break
	touch(outside, true)
	await process_frame
	touch(outside, false)
	await create_timer(1.0).timeout
	check(not host.inspecting and host.phase == host.Phase.OVERVIEW, "Tapping outside dismisses inspection")
	var hostile: int = 0 if map.markers[0].visible else 1
	at = map.markers[hostile].get_global_rect().get_center()
	pos = map.ship.position
	camera = map.camera.position
	mouse(at, true)
	await create_timer(0.55).timeout
	check(host.inspecting and host.view_kind == "preview", "Mouse hold opens enemy inspection without contact")
	var enter: Node = host.screen.find_child("CombatEntry", true, false)
	check(enter == null and not host.return_button.visible, "Enemy inspection omits combat action and hides Back")
	check(map.ship.position == pos and map.camera.position == camera, "Enemy inspection does not change camera or ship")
	mouse(at, false)
	await create_timer(0.7).timeout
	check(host.state.defense.contact < 0 and not is_instance_valid(host.battle), "Hold release cannot start combat")
	host.queue_free()
	await process_frame
	print("Starfront v1.1 inspection: %d failures" % failures)
	quit(1 if failures else 0)
