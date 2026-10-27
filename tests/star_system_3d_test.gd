extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var map = preload("res://scenes/star_system_3d.tscn").instantiate()
	root.add_child(map)
	map.player_profile = preload("res://ships/player/endeavour.tres")
	var entries: Array = []
	for i in range(6):
		entries.append({"index":i, "name":"Destination %d" % i, "text":"Destination", "tooltip":"Test", "color":Color.CORNFLOWER_BLUE, "completed":false, "model_kind":"gas_giant"})
	entries.append({"index":-2, "name":"Trading Outpost", "text":"Trading Outpost", "tooltip":"Test", "color":Color.CORNFLOWER_BLUE, "completed":false, "model_kind":"trading_outpost"})
	map.configure(entries, -1, 0.08, 999)
	await process_frame
	await process_frame
	check(map.objects.size() == 8 and map.markers.size() == 7, "Sun, six destinations and independent outpost")
	check(map.ship.get_child_count() > 0, "Selected ship instantiated")
	var positions: Array = []
	for i in range(6):
		positions.append(map.objects[i].position)
	map.configure(entries, -1, 0.08, 999)
	for i in range(6):
		check(map.objects[i].position == positions[i], "Visual seed reproducible")
	await create_timer(0.9).timeout
	var arrivals: Array = []
	map.arrived.connect(func(index): arrivals.append(index))
	map.travel(0)
	map.travel(1)
	check(map.traveling, "Travel permits a destination redirect")
	await create_timer(0.15).timeout
	check(arrivals == [1] and map.orbit_index == 1, "Only redirected arrival starts orbit")
	var at: Vector3 = map.ship.position
	await create_timer(0.1).timeout
	check(map.ship.position.distance_to(at) > 0.01, "Ship moves in orbit")
	map.travel(0)
	check(map.orbit_index == -1, "Departure cancels orbit")
	await create_timer(0.15).timeout
	check(arrivals == [1, 0], "Next arrival once")
	for index in range(2, 6):
		map.travel(index)
		await create_timer(0.15).timeout
	check(arrivals == [1, 0, 2, 3, 4, 5], "All six destinations reachable")
	map.travel(-2)
	await create_timer(0.15).timeout
	check(map.orbit_index == -2 and arrivals.back() == -2, "Separate Trading Outpost arrival")
	arrivals.pop_back()
	map.intercept_travel = func(_index): return true
	map.travel(2)
	await create_timer(0.6).timeout
	check(map.orbit_index == -1 and arrivals == [1, 0, 2, 3, 4, 5], "Interception cancels arrival")
	map.queue_free()
	await process_frame
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	root.add_child(host)
	await process_frame
	await process_frame
	check(host.star_map != null and host.star_map.get_parent() == host.screen, "3D map persists outside encounter UI")
	check(host.star_map.markers.size() >= 6, "Controller supplies all destinations")
	host.star_map.travel_duration = 0.04
	host.star_map.travel(0)
	await create_timer(0.12).timeout
	check(host.state.navigation_origin == 0 and host.map_destination == 0, "Controller owns arrival state")
	var retained_map: Control = host.star_map
	host.show_system()
	await process_frame
	check(host.star_map == retained_map and host.star_map.orbit_index == 0, "Overview retains ship and map")
	var poi = preload("res://encounters/mining_operation.tres")
	host.state.encounters[0] = {"kind":"poi", "poi":poi, "title":poi.title, "completed":false}
	host.show_poi(0)
	await process_frame
	await process_frame
	check(host.grid.columns == 1 and host.screen.model_space.visible, "Approaches are a vertical list beside model")
	check(host.star_map.camera.viewing == &"destination", "Camera focuses destination")
	var salvage: int = host.state.salvage
	host._select_approach(0)
	host._confirm_approach()
	host._confirm_approach()
	check(host.presenting_outcome and host.state.salvage == salvage + 3, "Outcome commits exactly once before suspense")
	await create_timer(0.1).timeout
	check(host.view_kind == "poi" and host.return_button.disabled, "Suspense locks return and delays reveal")
	host.show_system()
	check(host.view_kind == "poi", "Cannot leave during suspense")
	await create_timer(2.7).timeout
	check(host.view_kind == "outcome" and not host.presenting_outcome, "Result revealed after two-second pause and flash")
	host.show_system()
	await process_frame
	check(host.star_map.orbit_index == 0 and host.star_map.camera.viewing == &"overview", "Result returns to overview at last destination")
	host.state.service = {"kind":"service", "poi":preload("res://encounters/trading_outpost.tres"), "title":"Trading Outpost", "completed":false}
	host.star_map.free()
	host.star_map = null
	host.show_system()
	await process_frame
	host.star_map.travel_duration = 0.04
	host.star_map.travel(-2)
	await create_timer(0.15).timeout
	check(host.selected_encounter == -2 and host.grid.columns == 1 and host.approach_buttons.size() == 4, "Outpost retains services in scrollable right pane")
	host.queue_free()
	await process_frame
	print("Star system 3D: %d failures" % failures)
	quit(failures)
