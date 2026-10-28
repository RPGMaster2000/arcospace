extends SceneTree
# Actual GUI event routing and rendered frames, using production viewport proportions.
var checks := 0
var failures := 0
func _initialize() -> void:
	# Retained exploration-mode regression.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle():
	await create_timer(0.3).timeout
	for i in range(8): await process_frame
func tap(control: Control, touch: bool):
	for pressed in [true,false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 0
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
func frame(name: String):
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	var renderer: String = RenderingServer.get_current_rendering_method()
	check(root.get_texture().get_image().save_png("res://.godot/testlogs/foundation-"+renderer+"-"+name+".png") == OK,"Rendered frame captured")
func drag(map: Control, touch: bool):
	var point := Vector2(260,240)
	var press: InputEvent
	var motion: InputEvent
	if touch:
		press = InputEventScreenTouch.new()
		press.index = 0
		motion = InputEventScreenDrag.new()
		motion.index = 0
	else:
		press = InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		motion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	press.position = point
	press.pressed = true
	root.push_input(press,true)
	motion.position = point+Vector2(8,-12)
	motion.relative = Vector2(8,-12)
	root.push_input(motion,true)
	check(map.orbit_velocity.x < 0 and map.orbit_velocity.y < 0,"Mouse/touch drag reaches inverted orbit handler through viewport")
	press.pressed = false
	press.position = motion.position
	root.push_input(press,true)
func run():
	root.content_scale_size = Vector2i(960,540)
	root.size = Vector2i(960,540)
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0],"Requested renderer is active without fallback")
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	await settle()
	await frame("overview")
	var battle := -1
	var poi := -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind == "battle": battle = i
		else: poi = i
	for touch in [false,true]:
		await tap(host.resource_bar.entries.energy,touch)
		check(host.resource_bar.overlay.shade.visible,"Existing resource modal accepts GUI mouse/touch taps")
		await tap(host.resource_bar.overlay.close,touch)
		check(not host.resource_bar.overlay.shade.visible,"Modal closes through GUI input")
	host.map_destination = poi
	host.show_poi(poi)
	await settle()
	for touch in [false,true]: drag(host.star_map,touch)
	check(host.screen.overview_hud.focused,"Essential HUD remains active during input")
	await frame("poi")
	host.map_destination = battle
	host.show_battle_preview(battle)
	await settle()
	var modifier = host.view.find_child("ModifierDetails",true,false)
	await tap(modifier,true)
	check(host.view.get_child(0)._overlay.shade.visible,"Modifier rules open through touch routing")
	await tap(host.view.get_child(0)._overlay.close,true)
	check(not host.star_map.focus_orbit_enabled,"Confrontation camera does not accept manual orbit")
	await frame("combat")
	# Interception uses its own fixed framing and keeps all four response choices.
	host.show_system()
	host.state.pending_destination = battle
	host.state.chasedown_index = host.state.encounters.size()
	var entry: Dictionary = host.state.encounters[battle].duplicate()
	entry.merge({"chasedown":true,"response":-1,"completed":false},true)
	host.state.encounters.append(entry)
	host._show_chasedown()
	await settle()
	check(not host.star_map.focus_orbit_enabled,"Pursuit camera remains fixed")
	check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page+1,"Interception actions remain visible")
	await frame("chasedown")
	host.free()
	print("Star-system rendered input: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
