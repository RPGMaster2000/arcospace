extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(12): await process_frame
func run() -> void:
	root.size = Vector2i(1280, 720)
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 1042
	root.add_child(host)
	await settle()
	var map = host.star_map
	var camera = map.camera
	var settings = map.settings
	check(camera.zoom_target == settings.default_zoom and settings.default_zoom > 1, "Closer default overview")
	var rng: int = host.state.rng.state
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = map.get_global_rect().get_center()
	map._unhandled_input(wheel)
	check(camera.zoom_target > settings.default_zoom, "Wheel zooms overview")
	camera.zoom_by(100)
	check(is_equal_approx(camera.zoom_target, settings.maximum_zoom), "Maximum zoom clamps")
	camera.zoom_by(0.001)
	check(is_equal_approx(camera.zoom_target, settings.minimum_zoom), "Minimum zoom clamps")
	var gesture_origin: Vector2 = map.markers[0].get_global_rect().get_center()
	for index in [0, 1]:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.pressed = true
		touch.position = gesture_origin + Vector2(index * 100, 0)
		root.push_input(touch, true)
	var before: float = camera.zoom_target
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = gesture_origin + Vector2(160, 0)
	root.push_input(drag, true)
	check(map.pinching and camera.zoom_target > before, "Two-finger spread zooms")
	map.travel(0)
	check(not map.traveling, "Pinch cannot activate destination")
	for index in [0, 1]:
		var touch := InputEventScreenTouch.new()
		touch.index = index
		touch.position = gesture_origin + Vector2(index * 100, 0)
		root.push_input(touch, true)
	check(not map.pinching and map.touches.is_empty(), "Touch release clears gesture")
	check(not map.markers[0].disabled and not map.traveling, "Pinch cancels held marker and restores its enabled state")
	for index in map.markers:
		var point: Vector3 = map.objects[index].position
		check(settings.system_bounds.has_point(Vector2(point.x, point.z)), "Destinations respect calibrated borders")
	check(host.state.rng.state == rng, "Zoom and gestures preserve gameplay RNG")
	map.camera.close_ship(map.ship.position, 0, &"ftl")
	var at: Vector3 = map.ship.position
	var camera_at: Vector3 = camera.position
	map.depart()
	var clearance: float = (camera_at - at).cross(map.travel_direction).length()
	check(clearance > 0.8, "FTL passes beside the camera with real clearance")
	map.motion.kill()
	map.traveling = false
	map.overview()
	host.map_destination = 0
	host.show_poi(0)
	await settle()
	var scroll: ScrollContainer = host.scroll
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var scroll_rect := scroll.get_global_rect()
	var page: float = bar.page
	check(host.more_hint is TextureRect and host.more_hint.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Fade replaces hint without consuming input")
	check(host.more_hint.visible, "Overflow displays fade")
	check(not host.more_hint.get_global_rect().intersects(bar.get_global_rect()), "Scrollbar excluded from fade")
	for offset in [10, 35, 70, 0]:
		scroll.scroll_vertical = offset
		await settle()
		check(scroll.get_global_rect() == scroll_rect and bar.page == page, "Scrolling never resizes layout or scrollbar")
	scroll.scroll_vertical = int(bar.max_value)
	await settle()
	check(not host.more_hint.visible, "Fade clears at bottom without changing layout")
	check(scroll.get_global_rect() == scroll_rect and bar.page == page, "Fade visibility never shifts scroll area")
	host.queue_free()
	await settle()
	print("Map zoom/fade: %d failures" % failures)
	quit(failures)
