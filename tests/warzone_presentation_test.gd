extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in 6: await process_frame


func touch(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func capture(tag: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_webp("res://.godot/testlogs/warzone-%s-%s.webp" % [
		tag, RenderingServer.get_current_rendering_method()])


func run() -> void:
	root.size = Vector2i(1280, 720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate()
	host.rules.warzone_lattice_enabled = false
	host.play_system_intro = false
	host.star_system_settings = host.star_system_settings.duplicate(true)
	host.star_system_settings.departure_turn_duration = 0.1
	host.star_system_settings.departure_duration = 0.1
	host.star_system_settings.camera_duration = 0.1
	host.star_system_settings.white_fade_duration = 0.05
	host.star_system_settings.introduction_duration = 0.15
	root.add_child(host)
	host.state.defense.complete = true
	await host._jump()
	check(host.state.is_warzone() and host.state.system_number == 2 and not host.transitioning,
		"The live Homeworld FTL transition lands in an interactive Warzone")
	await settle()
	var hud = host.screen.overview_hud
	var map = host.star_map
	check(hud.metagame.text.contains("OBJECTIVES 1 / 2") and hud.wait_button.visible, "The map mounts the Warzone progress and wait controls")
	check(not hud.pressure_bar.visible, "Warzone uses an objective HUD")
	check(map.warzone_presentation.allies.size() == 2 and map.warzone_presentation.paths.get_surface_count() > 0,
		"The map presents allied groups and fleet routes")
	check(map.markers[5].objective_value == "Allied" and map.markers[6].objective_value == "Contested"
		and map.markers[7].objective_value == "Hostile",
		"Ownership is readable without color")
	check(not host.state.can_jump(), "The initial operation keeps FTL locked")
	var presentation = map.warzone_presentation
	check(presentation.fx.emitted_beams >= 4 and presentation.fx.emitted_impacts == 0,
		"The two opening battles show beams without advancing attrition")
	check(presentation.formations[0].size() == 2 and presentation.formations[2].size() == 2,
		"Both sides have bounded, lightweight formation escorts")
	presentation.idle_countdown = 0
	presentation.animate_engagements(0)
	await capture("frontline")
	host._inspect_marker(0)
	check(host.view_kind == "preview" and host.view.find_children("*", "Label", true, false).any(
		func(label): return label.text.contains("In range to intervene")),
		"Inspecting the opening battle identifies an accessible intervention")
	host._dismiss_inspection()
	for attempt in 40:
		if host._map_input_allowed(): break
		await create_timer(0.025).timeout
	await settle()
	var before: int = host.state.warzone.clock_ms
	await touch(hud.details_button)
	check(host.screen.system_details_overlay.shade.visible and host.state.warzone.clock_ms == before,
		"Opening the Warzone reports by touch consumes no strategic time")
	host.screen.system_details_overlay.dismiss()
	check(map.point_is_reserved(hud.wait_button.get_global_rect().get_center()), "The wait button reserves its hit area")
	var reinforcement: Node3D = presentation.models[3]
	var origin := reinforcement.position
	var before_shots: int = presentation.fx.emitted_beams
	# Emit the real button action and inspect the tween before the first frame.
	hud.wait_button.pressed.emit()
	var goal: Vector3 = host.state.warzone.fleets[3].position
	check(reinforcement.position == origin and goal != origin,
		"The authoritative move commits before visible interpolation")
	var waypoints: Array = presentation.motion.get(3, [])
	check(waypoints.size() > 1, "A batch wait preserves intermediate committed positions")
	presentation.animate_movement(0.24)
	check(reinforcement.position != origin and not reinforcement.position.is_equal_approx(goal),
		"The rendered group passes through intermediate positions")
	var midflight := reinforcement.position
	map.sync_warzone(host.state.warzone)
	check(reinforcement.position == midflight, "Refreshing the map does not restart movement")
	presentation.animate_movement(5.0)
	check(reinforcement.position.is_equal_approx(goal), "The model converges on the strategic position without drift")
	check(presentation.fx.emitted_beams > before_shots and presentation.fx.emitted_impacts > 0,
		"Committed exchanges emit beams and reflect real casualties with impacts")
	before = host.state.warzone.clock_ms
	await touch(hud.wait_button)
	check(host.state.warzone.clock_ms == before + host.state.warzone.tuning.wait_seconds * 1000,
		"An explicit touch wait advances the timeline")
	before = host.state.warzone.clock_ms
	map.travel(5)
	for attempt in 60:
		if host.view_kind == "poi": break
		await create_timer(0.05).timeout
	check(host.view_kind == "poi" and host.state.navigation_origin == 5,
		"Travel to the relay opens the objective panel through the normal map path")
	check(host.state.warzone.clock_ms > before, "Committed ship movement advances autonomous fleets")
	host.show_system()
	await settle()
	check(map.markers.has(host.state.SERVICE_INDEX) and map.markers[host.state.SERVICE_INDEX].visible
		and map.markers[host.state.SERVICE_INDEX].planet_name.text == "Trading Outpost",
		"The map displays a distinct allied Trading Outpost")
	map.travel(host.state.SERVICE_INDEX)
	for attempt in 85:
		if is_instance_valid(host.outpost_screen): break
		await create_timer(0.05).timeout
	check(is_instance_valid(host.outpost_screen) and host.state.navigation_origin == host.state.SERVICE_INDEX,
		"Normal flight opens the existing Trading Outpost UI")
	if is_instance_valid(host.outpost_screen):
		host.state.hull -= 1
		var hull: int = host.state.hull
		var salvage: int = host.state.salvage
		var cost: int = host.state.service_cost(0, 1)
		host._purchase_outpost_service(0, 1, host.state.service_revision, -1, host.outpost_screen)
		check(host.state.hull == hull + 1 and host.state.salvage == salvage - cost and not host.state.service.completed,
			"Outpost repairs use the existing price and preserve the station")
	host.show_system()
	root.size = Vector2i(960, 540)
	await settle()
	check(root.get_visible_rect().encloses(hud.panels[1].get_global_rect()) and root.get_visible_rect().encloses(hud.panels[2].get_global_rect()),
		"Warzone controls fit a compact landscape viewport")
	await capture("overview")
	host.free()
	await process_frame
	print("Warzone presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
