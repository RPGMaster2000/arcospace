extends SceneTree
var failures := 0
func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
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
	var fitted_zoom: float = camera.zoom_target
	check(fitted_zoom == camera.zoom_scale and fitted_zoom > 0, "Generated overview initializes synchronized fitted zoom")
	var rng: int = host.state.rng.state
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = map.get_global_rect().get_center()
	map._unhandled_input(wheel)
	check(camera.zoom_target > fitted_zoom, "Wheel zooms overview")
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
	await create_timer(0.2).timeout
	var center: Vector2 = map.get_global_rect().get_center()
	var initial_pan: Vector2 = camera.pan_offset
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.position = center + Vector2(100, 50)
	motion.relative = Vector2(100, 50)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(motion, true)
	check(map.dragging and camera.pan_offset != initial_pan, "Left mouse drag pans camera")
	map.travel(0)
	check(not map.traveling, "Mouse drag cannot select destination")
	press.pressed = false
	press.position = motion.position
	root.push_input(press, true)
	check(not map.dragging and not map.mouse_down and not map.markers[0].disabled, "Mouse release restores input")
	host.resource_bar.overlay.show_legend()
	check(not map._zoom_enabled(), "Reference overlay blocks camera gestures")
	host.resource_bar.overlay.dismiss()
	map.traveling = true
	check(map._zoom_enabled(), "Camera gestures remain enabled during PoI travel")
	var pan_after_mouse: Vector2 = camera.pan_offset
	var finger := InputEventScreenTouch.new()
	finger.index = 0
	finger.position = center
	finger.pressed = true
	root.push_input(finger, true)
	var swipe := InputEventScreenDrag.new()
	swipe.index = 0
	swipe.position = center + Vector2(-80, 30)
	swipe.relative = Vector2(-80, 30)
	root.push_input(swipe, true)
	check(map.dragging and camera.pan_offset != pan_after_mouse, "One finger pans camera")
	finger.pressed = false
	finger.position = swipe.position
	root.push_input(finger, true)
	check(not map.dragging and map.traveling, "Finger release leaves ongoing travel intact")
	map.traveling = false
	camera.pan_screen(Vector2(640, 300), Vector2(-100000, -100000))
	var bounds: Rect2 = settings.pan_bounds.abs()
	check(camera.pan_offset.x >= bounds.position.x and camera.pan_offset.x <= bounds.end.x and camera.pan_offset.y >= bounds.position.y and camera.pan_offset.y <= bounds.end.y, "Panning respects calibration bounds")
	camera.pan_offset = Vector2.ZERO
	camera.position = camera._overview_position(settings)
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
	var overflow_poi: Resource = host.state.encounters[0].poi.duplicate(true)
	overflow_poi.description += "\nScrollable location detail.".repeat(30)
	host.state.encounters[0].poi = overflow_poi
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
