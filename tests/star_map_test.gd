extends SceneTree
var failures: int = 0
var checks: int = 0
var host: Control
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(12): await process_frame
func run() -> void:
	host = preload("res://scenes/expedition.tscn").instantiate()
	root.add_child(host)
	host.star_map_travel_duration = .02
	host.state.start(0, host.rules, 777)
	host.state.service = {"kind":"service", "poi":preload("res://encounters/trading_outpost.tres"), "title":"Trading Outpost", "completed":false}
	for dimensions in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(960,540)]:
		root.size = dimensions
		host.show_system()
		await settle()
		var map: Control = host.star_map
		check(map.markers.size() == 6 + int(not host.state.service.is_empty()), "All encounters and independent service")
		check(map.size.y > 200, "Map fills available height")
		for index in map.markers:
			var button: Button = map.markers[index]
			check(map.get_global_rect().encloses(button.get_global_rect()), "Marker inside map")
			check(button.size.y >= 64 and button.size.x >= 120, "Touch target")
			for other in map.markers:
				if index != other: check(not button.get_global_rect().intersects(map.markers[other].get_global_rect()), "No marker overlap")
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "No map scrolling")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
			root.get_texture().get_image().save_png("res://.godot/testlogs/star-map-%s.png" % dimensions.x)
	var map: Control = host.star_map
	var initial: Vector2 = map.ship_position
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = map.markers[0].get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
	map.travel(1)
	check(map.traveling and host.view_kind == "system", "Travel starts without opening early")
	await create_timer(.08).timeout
	check(host.map_destination == 0 and ((host.view_kind == "preview" and host.view.get_child(0).text.contains(host.state.encounters[0].title)) or host.selected_encounter == 0), "Only first arrival opens correct encounter")
	host.show_system()
	await settle()
	check(host.star_map.ship_position == host.star_map.destination(0) and initial != host.star_map.ship_position, "Return retains ship location")
	host.state.encounters[0].completed = true
	host.show_system()
	check(host.star_map.markers[0].disabled, "Completed destination disabled")
	var charge: int = host.state.ftl_charge
	host.star_map.travel(0)
	check(not host.star_map.traveling and host.state.ftl_charge == charge, "Completed destination cannot reopen or reward")
	# A free service is separate from the six progression slots and remains revisitable.
	host.state.service = {"kind":"service", "poi":preload("res://encounters/trading_outpost.tres"), "title":"Trading Outpost", "completed":false}
	host.show_system()
	host.star_map.travel(-2)
	await create_timer(.08).timeout
	check(host.selected_encounter == -2 and host.state.ftl_charge == charge, "Service arrival has no FTL cost/reward")
	host.show_system()
	check(not host.star_map.markers[-2].disabled and host.state.encounters.size() == 6, "Service remains independent and revisitable")
	host.star_map.travel(1)
	host.state.ftl_charge = host.state.required_ftl_charge + 3
	host._jump()
	await create_timer(.08).timeout
	check(host.state.ftl_charge == 0 and host.map_destination == -1 and host.view_kind == "system", "Transition cancels old travel, discards carryover and resets map")
	# Mandatory Boss gating is still owned by expedition state.
	while host.state.system_number < 6:
		host.state.ftl_charge = host.state.required_ftl_charge
		host._jump()
	check(host.state.mandatory_boss_pending(), "System six retains mandatory Boss")
	host.state.ftl_charge = host.state.required_ftl_charge
	host._jump()
	check(host.state.system_number == 6, "Map cannot bypass Boss")
	host.use_star_map = false
	host.show_system()
	check(is_instance_valid(host.grid) and host.grid.get_child_count() == 6 and host.star_map == null, "Toggle restores original six-tile grid")
	host.use_star_map = true
	host.start_expedition()
	check(host.map_destination == -1 and host.state.ftl_charge == 0, "New expedition resets position and FTL")
	host.queue_free()
	await process_frame
	print("Star map: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
