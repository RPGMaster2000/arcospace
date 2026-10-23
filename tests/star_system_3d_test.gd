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
	map.configure(entries, -1, 0.08, 999)
	await process_frame
	await process_frame
	check(map.objects.size() == 7 and map.markers.size() == 6, "Sun and six destinations")
	check(map.ship.get_child_count() > 0, "Selected ship instantiated")
	var positions: Array = []
	for i in range(6):
		positions.append(map.objects[i].position)
	map.configure(entries, -1, 0.08, 999)
	for i in range(6):
		check(map.objects[i].position == positions[i], "Visual seed reproducible")
	var arrivals: Array = []
	map.arrived.connect(func(index): arrivals.append(index))
	map.travel(0)
	map.travel(1)
	check(map.traveling, "Travel locks repeated selections")
	await create_timer(0.15).timeout
	check(arrivals == [0] and map.orbit_index == 0, "Single arrival starts orbit")
	var at: Vector3 = map.ship.position
	await create_timer(0.1).timeout
	check(map.ship.position.distance_to(at) > 0.01, "Ship moves in orbit")
	map.travel(1)
	check(map.orbit_index == -1, "Departure cancels orbit")
	await create_timer(0.15).timeout
	check(arrivals == [0, 1], "Next arrival once")
	map.intercept_travel = func(_index): return true
	map.travel(2)
	await create_timer(0.6).timeout
	check(map.orbit_index == -1 and arrivals == [0, 1], "Interception cancels arrival")
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
	host.queue_free()
	await process_frame
	print("Star system 3D: %d failures" % failures)
	quit(failures)
