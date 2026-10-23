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
	map.queue_free()
	await process_frame
	print("Star system 3D: %d failures" % failures)
	quit(failures)
