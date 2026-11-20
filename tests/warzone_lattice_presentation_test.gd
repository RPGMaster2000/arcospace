extends "res://tests/warzone_presentation_test.gd"


func run() -> void:
	root.size = Vector2i(1280, 720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 19
	host.star_system_settings = host.star_system_settings.duplicate()
	host.star_system_settings.departure_turn_duration = 0.1
	host.star_system_settings.departure_duration = 0.1
	host.star_system_settings.camera_duration = 0.1
	host.star_system_settings.white_fade_duration = 0.05
	root.add_child(host)
	host.state.defense.complete = true
	await host._jump()
	await settle()
	var map = host.star_map
	var hud = host.screen.overview_hud
	var operation: RefCounted = host.state.warzone
	var presentation = map.warzone_presentation
	check(map.visual_data.starless and not map.objects.has(-100) and not map.world.get_node("SunLight").visible
		and map.visual_root.has_node("SectorFill"), "Live Warzone map has sky and fill lighting without a sun")
	check(presentation.influence != null and presentation.influence_target.size() == 12
		and presentation.paths.get_surface_count() == 1, "One influence mesh and one lattice line batch")
	check(hud.war_effort_bar.visible and hud.lattice_button.visible and operation.engagement_count() == 2,
		"War Effort, lattice control and two opening engagements")
	var before_clock: int = operation.clock_ms
	var wall_ms := Time.get_ticks_msec()
	await touch(hud.lattice_button)
	check(presentation.overlay_enabled and operation.clock_ms - before_clock < Time.get_ticks_msec() - wall_ms + 300,
		"Touch toggles route overlay without purchasing additional strategic time")
	check(hud.warzone_counts[0].text == "A %d" % operation.fleet_count("allied") and
		hud.warzone_counts[1].text == "H %d" % operation.fleet_count("hostile"), "Fleet icons carry authoritative counts")
	check(hud.territory_bar.value == operation.controlled(), "Territory strip matches opening control")
	var ally_marker = map.markers[map.WARZONE_ALLY_MARKER_BASE]
	check(ally_marker.fleet_strength == float(operation.fleets[0].strength) / operation.fleets[0].strength_limit,
		"Allied marker strength matches the actual fleet")
	await touch(ally_marker)
	check(host.inspecting and host.view.has_node("AlliedFleetStrength"), "Touch opens allied fleet inspection")
	if host.inspecting:
		host._dismiss_inspection()
		for attempt in 40:
			if host._map_input_allowed(): break
			await create_timer(0.025).timeout
	var interception: int = host.state.warzone_fleet(0).id - operation.ALLIED_GROUPS
	var started_clock: int = operation.clock_ms
	map.travel(interception)
	for attempt in 40:
		if host.view_kind == "preview": break
		await create_timer(0.025).timeout
	check(host.view_kind == "preview" and host.state.can_engage(interception)
		and operation.clock_ms - started_clock < 1000, "Arrival uses committed fleet proximity without a second travel clock")
	host.show_system()
	for attempt in 40:
		if host._map_input_allowed(): break
		await create_timer(0.025).timeout
	await _watch_fleet(host, operation, presentation)
	await capture("lattice-overview")
	host._show_system_details()
	var paused_clock: int = operation.clock_ms
	await create_timer(0.25).timeout
	check(operation.clock_ms == paused_clock, "Reports pause continuous fleet simulation")
	host.screen.system_details_overlay.dismiss()
	check(presentation.fx.emitted_beams > 0, "Opening NPC engagements show beam exchanges")
	var before_influence: PackedVector4Array = presentation.influence_target.duplicate()
	var index: int = operation.HOSTILE_ROOT + operation.HOSTILE_GROUPS
	var point: Vector3 = operation.objectives[operation.HOSTILE_ROOT].position
	host.state.update_navigation_position(host.state.Defense.wire(point))
	host.state.arrive_destination(index)
	host.show_poi(index)
	host._warzone_operation(index, "sabotage")
	await settle()
	check(operation.disrupted.has(operation.HOSTILE_ROOT) and presentation.influence_target != before_influence,
		"Real sabotage updates territory and link presentation")
	check(hud.war_effort_bar.value == minf(operation.effort, operation.tuning.effort_goal)
		and operation.effort > 0 and hud.war_effort_gain.text.begins_with("+"),
		"Operation updates the effort bar and gain indicator")
	check(map.markers[index].objective_value.contains("!"), "Disruption is identifiable without color")
	check(presentation.fx.emitted_impacts > 0, "Strategic volleys produce visible damage feedback")
	host.show_system()
	root.size = Vector2i(960, 540)
	await settle()
	for control in [hud.lattice_button, hud.war_effort_bar, hud.territory_bar, hud.warzone_summary]:
		check(root.get_visible_rect().encloses(control.get_global_rect()), "Warzone HUD fits Android landscape")
	await capture("lattice-cutoff")
	host.free()
	await process_frame
	print("Warzone lattice presentation: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))


func _watch_fleet(host: Node, operation: RefCounted, presentation: Node3D) -> void:
	var fleet: Dictionary = operation.fleets[4]
	# Start a real supplied fleet down an uncontested corridor long enough to
	# detect the old one-second stop/start cycle in the actual moving model.
	var origin: int = operation.HOSTILE_ROOT
	var target: int = operation.Lattice.neighbors(origin, operation.links).back()
	fleet.at = origin
	fleet.destination = target
	var point: Vector3 = operation.objectives[origin].position
	fleet.position = point
	operation.motion_samples.clear()
	var model: Node3D = presentation.models[fleet.id]
	var watched := 0
	for interval in 12:
		var before: Vector3 = model.position
		var before_clock: int = operation.clock_ms
		await create_timer(0.25).timeout
		if interval == 0: continue # Interpolation primes its first two samples.
		var elapsed: float = (operation.clock_ms - before_clock) * 0.001
		var distance := before.distance_to(model.position)
		if elapsed >= 0.20 and absf(distance - elapsed * operation.tuning.fleet_speed) < 0.22:
			watched += 1
	check(watched >= 10, "The rendered fleet advances at the configured speed through successive quarter-second observations")
	check(model == presentation.models[fleet.id] and model.position.distance_to(fleet.position) < 0.25,
		"Rendering remains bound to the same fleet and within the fixed-step interpolation delay")
	check(host.phase == host.Phase.OVERVIEW and presentation.motion.is_empty(), "Live lattice movement never enters the legacy playback queue")
