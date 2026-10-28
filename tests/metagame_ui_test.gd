extends SceneTree
# Read-only UI integration across shipping landscape sizes. No reward simulation.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await create_timer(0.3).timeout
	for i in range(4): await process_frame

func capture(label: String, map: Control) -> void:
	if DisplayServer.get_name() == "headless": return
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="): directory = argument.trim_prefix("--capture-dir=")
	if directory.is_empty(): return
	if map.camera.motion and map.camera.motion.is_running(): await map.camera.motion.finished
	for i in range(4): await process_frame
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory.path_join(label + ".png")) == OK, "Rendered capture saved")

func verify_navigation(host: Control) -> void:
	var map: Control = host.star_map
	map.travel_duration = 0.12
	host.state.system_profile = "industrial"
	host.state.navigation_origin = host.state.FREE_DESTINATION
	host.state.chasedown_roll_policy.cooldown_remaining = 0.0
	var old_chance: float = host.rules.chasedown_chance
	var old_increment: float = host.rules.pressure_chasedown_increment
	host.rules.chasedown_chance = 0.000001
	host.rules.pressure_chasedown_increment = 0.0
	var expected := RandomNumberGenerator.new()
	expected.seed = host.state.chasedown_rng.seed
	expected.state = host.state.chasedown_rng.state
	check(expected.randf() > host.state.effective_chasedown_chance(), "Movement fixture uses a non-intercepting probability draw")
	var completed: Array = []
	for entry in host.state.encounters: completed.append(entry.completed)
	var salvage: int = host.state.salvage
	var selection: int = host.selected_encounter
	map.free_move_requested.emit(Vector3(8,0,8))
	check(map.traveling and host.state.navigation.leg_active and host.phase == host.Phase.TRAVELING, "Coordinator starts the existing journey from free-movement intent")
	var final_point := Vector3.ZERO
	for i in range(10):
		final_point = Vector3(9 + i * 0.1,0,8)
		map.free_move_requested.emit(final_point)
	check(host.state.chasedown_rng.state == expected.state, "Ten uninterrupted redirects consume exactly one probability draw")
	check(host.state.navigation.target == [final_point.x,final_point.y,final_point.z], "Last redirect is the authoritative target")
	await create_timer(0.2).timeout
	check(not map.traveling and not host.state.navigation.leg_active and host.state.travel_destination == -1, "Actual arrival stops and completes the leg")
	check(map.ship.position.is_equal_approx(final_point), "Ship reaches the redirected free destination")
	var saved_point: Array = host.state.navigation.position
	check(saved_point.size() == 3 and Vector3(saved_point[0],saved_point[1],saved_point[2]).is_equal_approx(final_point), "Arrival stores the actual ship position")
	await create_timer(0.05).timeout
	check(map.ship.position.is_equal_approx(final_point), "Free arrival remains stationary")
	var after: Array = []
	for entry in host.state.encounters: after.append(entry.completed)
	check(after == completed and host.state.pressure == 0 and host.state.salvage == salvage, "Free movement completes no PoI and grants no pressure or reward")
	check(host.view_kind == "system" and host.selected_encounter == selection, "Free movement does not open a PoI")
	map.free_move_requested.emit(Vector3(11,0,8))
	check(host.state.chasedown_rng.state == expected.state, "Immediate next leg moves normally without a cooldown roll")
	await create_timer(0.2).timeout
	var cooldown: float = host.state.chasedown_roll_policy.cooldown_remaining
	paused = true
	await create_timer(0.08, true).timeout
	paused = false
	check(is_equal_approx(host.state.chasedown_roll_policy.cooldown_remaining, cooldown), "Paused gameplay does not advance Chasedown cooldown")
	host.resource_bar.overlay.show_text("Navigation clock test")
	cooldown = host.state.chasedown_roll_policy.cooldown_remaining
	await create_timer(0.08).timeout
	check(is_equal_approx(host.state.chasedown_roll_policy.cooldown_remaining, cooldown), "Open modal does not advance Chasedown cooldown")
	host.resource_bar.overlay.dismiss()
	var codec = preload("res://scripts/persistence/expedition_save.gd").new()
	var restored = codec.decode(codec.encode(host.state), host.rules)
	check(restored != null and is_equal_approx(restored.chasedown_roll_policy.cooldown_remaining, host.state.chasedown_roll_policy.cooldown_remaining), "Save/resume preserves the remaining shared cooldown")
	host.state.advance_chasedown_cooldown(10.0)
	expected.randf()
	map.free_move_requested.emit(Vector3(12,0,8))
	check(host.state.chasedown_rng.state == expected.state, "Next completed-leg journey permits one new draw after cooldown")
	await create_timer(0.2).timeout
	host.rules.chasedown_chance = old_chance
	host.rules.pressure_chasedown_increment = old_increment

func run() -> void:
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	await verify_navigation(host)
	var battle := -1
	var poi := -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind == "battle": battle = i
		elif host.state.encounters[i].get("objective_role", "").is_empty(): poi = i
	check(battle >= 0 and poi >= 0, "Generated system has both preview categories")
	var hud = host.screen.overview_hud
	var rng: int = host.state.rng.state
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1680,720), Vector2i(1560,720)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		host.state.pressure = 10
		host.show_system()
		await settle()
		check(hud.metagame.text.contains("PRESSURE 10 / 12") and hud.metagame.text.contains(host.state.profile_name()), "Profile and pressure show authoritative facts")
		check(hud.metagame.text.contains(host.state.ftl_status()), "FTL state persists in ship status")
		check(host.jump_button.get_node_or_null("Charge") == null, "Retired interstellar charge bar absent")
		check(hud.panels[0].size.y < 65, "Economy remains horizontal")
		check(root.get_visible_rect().encloses(hud.panels[2].get_global_rect()), "Pressure and ship status fit viewport")
		await capture("overview-%d" % dimensions.x, host.star_map)
		host.state.ftl_access = true
		host.show_system()
		await settle()
		check(host.jump_button.text == "FTL READY" and not host.jump_button.disabled, "FTL objective completion enables Jump")
		if dimensions.x == 960: await capture("ftl-ready-960", host.star_map)
		host.map_destination = poi
		host.show_poi(poi)
		await settle()
		check(hud.focused and hud.metagame.is_visible_in_tree(), "Pressure remains visible in PoI focus")
		check(not hud.panels[3].is_visible_in_tree() and not hud.panels[4].is_visible_in_tree(), "Focus hides exploration controls")
		check(not hud.panels[2].get_global_rect().intersects(host.screen.sidebar.get_global_rect()), "Persistent ship panel clears PoI choices")
		if dimensions.x == 960: await capture("poi-960", host.star_map)
		host.map_destination = battle
		host.show_battle_preview(battle)
		await settle()
		var notice = host.view.find_child("PressureModifier", true, false)
		check(notice != null and notice.visible and notice.text == host.state.Pressure.description(host.state.pressure), "Tactical briefing discloses actual high-pressure scaling")
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Pressure tactical panel fits without scrolling")
		check(not hud.panels[2].get_global_rect().intersects(host.screen.sidebar.get_global_rect()), "Persistent ship panel clears combat briefing")
		if dimensions.x == 960: await capture("combat-960", host.star_map)
	# The four response choices share the same fixed-height tactical panel.
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1680,720)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		host.show_system()
		host.state.pending_bonuses = {"materials":3,"energy":5,"crew":2,"shields":4,"emp_pulse_charge":3}
		host.state.pending_penalties = {"energy":-3,"shields":-4,"emp_pulse_offline":2}
		var interception: Dictionary = host.state.encounters[battle].duplicate()
		interception.chasedown = true
		interception.response = -1
		interception.completed = false
		host.state.chasedown_index = host.state.encounters.size()
		host.state.encounters.append(interception)
		host._show_chasedown()
		await settle()
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Pursuit pressure and full entry effects fit without scrolling")
		check(host.grid.get_child_count() == 4, "All four Chasedown responses stay available")
		check(not host.star_map.focus_orbit_enabled, "Pursuit keeps fixed cinematic camera")
		if dimensions.x == 960: await capture("chasedown-960", host.star_map)
		host.state.encounters.pop_back()
		host.state.chasedown_index = -1
		host.state.pending_destination = -1
	check(host.state.rng.state == rng, "UI changes consume no gameplay RNG")
	host.free()
	print("Metagame UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
