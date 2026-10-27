extends SceneTree
# Small input/presentation regression. Gameplay legality is tested separately in navigation_leg_test.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func mouse(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	return event
func touch(at: Vector2, pressed: bool, index: int = 0) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = pressed
	event.index = index
	return event
func run() -> void:
	root.size = Vector2i(960,540)
	var map = preload("res://scenes/star_system_3d.tscn").instantiate()
	map.player_profile = preload("res://ships/player/endeavour.tres")
	root.add_child(map)
	var entries: Array = []
	for index in range(9):
		entries.append({"index":index,"name":"Destination %d"%index,"text":"Destination","tooltip":"Test","color":Color.CYAN,"completed":false,"model_kind":"research_station","objective_marker":"!" if index == 0 else ""})
	map.configure(entries,-1,0.04,991)
	map.camera.cancel()
	map.camera.overview(map.settings,true)
	await process_frame
	await process_frame
	check(map.markers.size()==9,"Larger system retains all destinations")
	check(map.markers[0].objective_badge.text=="!","Objective marker is readable beside existing icon")
	var marker = map.markers[0]
	marker.set_objective("🔒")
	check(marker.objective_badge.visible and marker.objective_value=="🔒" and marker.objective_badge.text.is_empty(),"Locked objective uses portable drawn lock instead of missing font glyph")
	marker.set_objective("!")
	var icon: Vector2 = marker.global_position+marker.icon_center
	check(map.nearest_marker(icon)==0,"Visible icon selects itself")
	check(marker.hit_distance(marker.icon_center+Vector2(33,0))!=INF,"Effective touch target extends beyond small graphic")
	var original: Vector2 = map.markers[1].position
	map.markers[1].position = marker.position+marker.icon_center-map.markers[1].icon_center
	check(map.nearest_marker(icon)==1,"Exact overlap picks one deterministic eligible marker")
	var claims := 0
	for button in map.markers.values():
		if button._has_point(icon-button.global_position): claims += 1
	check(claims==1,"Overlap cannot activate two destinations")
	map.markers[1].position = original
	map.hud_regions.append(Rect2(icon-Vector2(5,5),Vector2(10,10)))
	check(map.nearest_marker(icon)==-1,"HUD region excludes overlapping marker target")
	map.hud_regions.clear()
	# Real viewport dispatch must agree with direct touch arbitration and never also fire Button.pressed.
	var marker_taps := [0]
	map.before_travel = func(_index): marker_taps[0] += 1; return false
	for pressed in [true,false]: root.push_input(mouse(icon,pressed),true)
	check(marker_taps[0]==1,"Native GUI mouse dispatch selects the marker once")
	for pressed in [true,false]: root.push_input(touch(icon,pressed),true)
	check(marker_taps[0]==2,"Native touch dispatch adds exactly one marker intent")
	map.before_travel = Callable()
	var free_points: Array[Vector3] = []
	map.free_move_requested.connect(func(point): free_points.append(point))
	var empty := Vector2.ZERO
	for y in range(100,400,30):
		for x in range(100,850,30):
			var at := Vector2(x,y)
			if map.nearest_marker(at)==-1 and not map._point_on_object(at): empty = at
	check(empty != Vector2.ZERO,"A larger system leaves empty-space destinations")
	var hud := Button.new()
	hud.position = empty-Vector2(20,20)
	hud.size = Vector2(40,40)
	root.add_child(hud)
	var hud_taps := [0]
	hud.pressed.connect(func(): hud_taps[0] += 1)
	map.hud_regions.append(hud.get_global_rect())
	await process_frame
	for pressed in [true,false]: root.push_input(mouse(empty,pressed),true)
	check(hud_taps[0]==1 and free_points.is_empty(),"Reserved HUD button receives GUI input without free movement")
	hud.free()
	map.hud_regions.clear()
	map.input_allowed = func(): return false
	map._input(mouse(empty,true))
	map._input(mouse(empty,false))
	check(free_points.is_empty(),"Modal input blocker prevents map movement")
	map.input_allowed = Callable()
	map._input(mouse(empty,true))
	map._input(mouse(empty,false))
	check(free_points.size()==1,"Mouse tap emits one free movement intent")
	check(is_zero_approx(free_points[0].y) and map.settings.system_bounds.has_point(Vector2(free_points[0].x,free_points[0].z)),"Empty tap projects onto bounded navigation plane")
	map._input(touch(empty,true))
	map._input(touch(empty,false))
	check(free_points.size()==2,"Native touch emits one free movement intent")
	map._input(mouse(empty,true))
	map._input(mouse(empty+Vector2(30,0),false))
	check(free_points.size()==2,"Displaced release without motion events is not a tap")
	map._input(touch(empty,true))
	map._input(touch(empty+Vector2(60,0),true,1))
	map._input(touch(empty,false))
	map._input(touch(empty+Vector2(60,0),false,1))
	check(free_points.size()==2,"Pinch releases never emit movement")
	map.gesture_block_until = 0
	var arrivals: Array[int] = []
	var free_arrivals := [0]
	map.arrived.connect(func(index): arrivals.append(index))
	map.free_arrived.connect(func(): free_arrivals[0] += 1)
	map.travel_to_position(Vector3(2,0,3))
	map.travel_to_position(Vector3(-4,0,3))
	await create_timer(.15).timeout
	check(free_arrivals[0]==1 and arrivals.is_empty(),"Redirected free travel arrives once without activating a PoI")
	check(map.ship.position.is_equal_approx(Vector3(-4,0,3)) and map.orbit_index==-1,"Ship stops at final free destination")
	await create_timer(.1).timeout
	check(map.ship.position.is_equal_approx(Vector3(-4,0,3)),"Free position remains stationary")
	map.travel(0)
	map.travel(1)
	await create_timer(.15).timeout
	check(arrivals==[1],"PoI redirect cancels old arrival")
	map.apply_navigation_position(Vector3(1,0,2))
	check(map.ship.position==Vector3(1,0,2) and map.orbit_index==-1,"Authoritative saved position restores without idle orbit")
	map.intercept_free_travel = func(_point): return true
	map.travel_to_position(Vector3(8,0,2))
	map.travel_to_position(Vector3(-8,0,2))
	check(map.interception_pending and map.travel_direction.x>0,"Interception blocks redirects from replacing stop tween")
	map.cancel_presentation()
	map.focus(0)
	check(map.focus_orbit_enabled,"Ordinary PoI retains existing orbit input")
	map.tactical_focus(0,true,preload("res://ships/enemy/marauder.tres"))
	check(not map.focus_orbit_enabled,"Pursuit cinematic retains fixed framing")
	map.free()
	print("Star map navigation: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
