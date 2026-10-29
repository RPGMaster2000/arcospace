extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func tap(at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	root.push_input(event, true)
	await process_frame
func run() -> void:
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(960,540)
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 42042
	root.add_child(host)
	await create_timer(1.2).timeout
	var map = host.star_map
	var targets: Array[int] = []
	for i in range(host.state.encounters.size()):
		if map.markers.has(i) and map.markers[i].visible and not map.markers[i].disabled: targets.append(i)
	check(targets.size() >= 2, "Two selectable touch targets")
	if targets.size() >= 2:
		var first: int = targets[0]
		var second: int = targets[1]
		var position: Vector3 = map.ship.position
		await tap(map.markers[first].get_global_rect().get_center())
		check(map.selected_touch_index == first and host.state.travel_destination == -1 and map.ship.position == position, "First touch selects without travelling")
		await tap(map.markers[second].get_global_rect().get_center())
		check(map.selected_touch_index == second and host.state.travel_destination == -1, "Different target cannot confirm travel")
		await create_timer(0.45).timeout
		await tap(map.markers[second].get_global_rect().get_center())
		check(host.state.travel_destination == -1, "Expired first tap cannot confirm travel")
		await tap(map.markers[second].get_global_rect().get_center())
		check(host.state.travel_destination == second and host.state.navigation.leg_active, "Second same-target touch confirms travel")
	# Empty-space touch must navigate on one tap, unlike PoI/enemy markers.
	var free_point := Vector2(-1, -1)
	var rect: Rect2 = map.get_global_rect()
	for row in range(4, 13):
		if free_point.x >= 0: break
		for col in range(4, 19):
			var candidate: Vector2 = rect.position + rect.size * Vector2(float(col) / 20.0, float(row) / 16.0)
			if map.point_is_reserved(candidate) or map.nearest_marker(candidate) >= 0 or map._point_on_object(candidate): continue
			var blocked: bool = false
			for marker in map.markers.values():
				if marker.visible and marker.hit_distance(candidate - marker.global_position) != INF: blocked = true
			if not blocked:
				free_point = candidate
				break
	check(free_point.x >= 0, "Find empty navigable space for touch regression")
	if free_point.x >= 0:
		await tap(free_point)
		check(host.state.travel_destination == host.state.FREE_DESTINATION and host.state.navigation.leg_active, "Single empty-space touch initiates free travel")
	host.queue_free()
	await process_frame
	print("Starfront touch gestures: %d failures" % failures)
	quit(1 if failures else 0)
