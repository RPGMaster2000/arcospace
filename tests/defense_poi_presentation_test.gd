extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var checks := 0
var failures := 0
const DIRECTORY = "res://.godot/testlogs/defense-strategic-pois"
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DIRECTORY+"/"+label+"-"+RenderingServer.get_current_rendering_method()+".png") == OK, "Production capture saved")
func fresh() -> Resource:
	var state := State.new()
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	state.start(0,rules,1042)
	return state
func host_for(state: Resource) -> Node:
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state":state,"battle":{}}
	root.add_child(host)
	return host
func run() -> void:
	root.size = Vector2i(1280,720)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	for id in ["mining_operation","research_station","spatial_anomaly"]:
		var state := fresh()
		var index := -1
		for slot in state.encounters.size():
			if state.encounters[slot].kind == "poi":
				index = slot
				break
		check(index >= 0, "Special PoI fixture has a generated anchor")
		if index < 0: continue
		state.encounters[index].poi = load("res://encounters/"+id+".tres")
		state.encounters[index].title = state.encounters[index].poi.title
		state.navigation_origin = index
		var host = host_for(state)
		for frame in range(8): await process_frame
		host.map_destination = index
		host.show_poi(index)
		for frame in range(16): await process_frame
		check(host.approach_buttons.size() == 4, "Special PoI retains four choices in existing interface")
		for button in host.approach_buttons:
			if not button.disabled:
				check(button.details.text.contains("strategic seconds"), "Accessible action displays its time cost")
			check(not button.details.text.contains("% —") and not button.details.text.contains("failure"), "No random failure presentation")
		check(host.return_button.is_visible_in_tree(), "Back remains accessible")
		var focus_deadline := Time.get_ticks_msec() + 8000
		while host.screen.focus_transition and Time.get_ticks_msec() < focus_deadline: await process_frame
		check(not host.screen.focus_transition, "PoI input transition completes")
		var action: Control = host.approach_buttons[0]
		for pressed in [true,false]:
			var touch := InputEventScreenTouch.new()
			touch.index = 0
			touch.position = action.get_global_rect().get_center()
			touch.pressed = pressed
			root.push_input(touch,true)
			await process_frame
		check(host.confirmation.shade.visible, "Touch selects a guaranteed approach using existing confirmation")
		host.confirmation.dismiss()
		await capture(id)
		if id == "mining_operation":
			check(state.resolve_approach(index,2), "Mining choice installs free platform")
			host.show_system()
			for frame in range(8): await process_frame
			var key: String = State.Defense.Installations.FREE_PREFIX + str(index)
			var construction = host.star_map.defense_effects.construction
			check(construction.rings.has(key), "Existing renderer displays the free PoI turret and ring")
			if construction.rings.has(key):
				check(construction.rings[key].global_position == state.defense.anchors[index], "Displayed free turret remains exactly at the PoI anchor")
			await capture("free-mining-turret")
		root.size = Vector2i(960,540)
		for frame in range(8): await process_frame
		if host.view_kind == "poi": check(root.get_visible_rect().encloses(host.screen.sidebar.get_global_rect()), "Small viewport retains a bounded existing PoI sidebar")
		root.size = Vector2i(1280,720)
		host.free()
		await process_frame
	# A real production journey crosses the fuel boundary in one travel command.
	var state := fresh()
	state.poi_effects.fuel = 2
	var profile: Array[Vector2] = state.travel_speed_profile(4)
	check(profile == [Vector2(2,1.5),Vector2(2,1)], "One command plans boosted and normal segments")
	var host = host_for(state)
	for frame in range(8): await process_frame
	var origin: Vector3 = host.star_map.ship.position
	var destination: Vector3 = origin + Vector3.RIGHT * 4
	var pressure: float = state.defense.pressure
	host.star_map.travel_to_position(destination)
	var deadline := Time.get_ticks_msec() + 10000
	while host.star_map.traveling and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not host.star_map.traveling and host.star_map.ship.position.distance_to(destination) < 0.001, "Production journey finishes past fuel exhaustion")
	check(state.poi_effects.fuel == 0, "Actual movement consumes finite fuel and returns to normal speed")
	check(absf(state.defense.pressure-pressure-4*state.defense.tuning.seconds_per_distance) < 0.001, "Faster physical travel does not discount strategic time per distance")
	host.free()
	print("Defense PoI presentation and propulsion: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
