extends "res://tests/warzone_presentation_test.gd"

const Save = preload("res://scripts/persistence/expedition_save.gd")


func run() -> void:
	Preferences.set_strategic_time_overview(false)
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
	var saved := Save.encode(host.state)
	var sector: Dictionary = saved.warzone
	var allied_order: Dictionary = sector.fleets[0]
	sector.fleets[allied_order.engaged].engaged = -1
	allied_order.engaged = -1
	check(map.visual_data.starless and not map.objects.has(-100) and not map.world.get_node("SunLight").visible
		and map.visual_root.has_node("SectorFill"), "Live Warzone map has sky and fill lighting without a sun")
	check(hud.lattice_button.button_pressed and presentation.influence_field.visible
		and presentation.paths.get_surface_count() == 1 and presentation.order_paths.get_surface_count() == 1
		and presentation._order_colors.has(Color("cf5365")) and operation.clock_ms == 0,
		"On entry, Lattice and hostile routes are visible before strategic time advances")
	check(hud.wait_button.visible and hud.wait_button.text == "Hold to Wait",
		"The universal Hold to Wait control is available")
	check(hud.war_effort_bar.visible and hud.lattice_button.visible and operation.engagement_count() == 2,
		"War Effort, lattice control and two opening engagements")
	# Mission emphasis uses real objective roles, without changing the simulation.
	var strategic_site: int = operation.site("forward_command")
	var final_site: int = operation.site("hostile_command")
	var strategic_marker = map.markers[operation.HOSTILE_GROUPS + strategic_site]
	var final_marker = map.markers[operation.HOSTILE_GROUPS + final_site]
	check(strategic_marker.warzone_importance == 1 and final_marker.warzone_importance == 1
		and hud.warzone_mission.visible and hud.warzone_mission.text.contains("Effort remaining")
		and not hud.warzone_hold_bar.visible, "Before the final offensive, command stations are strategic but not final objectives")
	var previous_effort: int = operation.effort
	var previous_intervention: bool = operation.player_intervened
	var previous_owner: String = operation.objectives[final_site].owner
	var previous_supply: Array = operation.supplied.allied.duplicate()
	operation.effort = operation.tuning.effort_goal
	operation.player_intervened = true
	operation.final_command = final_site
	map.sync_warzone(operation)
	hud.set_warzone_status(host.state)
	check(final_marker.warzone_importance == 2 and strategic_marker.warzone_importance == 1
		and final_marker.planet_name.text == "FINAL · Hostile Command"
		and final_marker.tooltip_text.contains("FINAL OBJECTIVE")
		and hud.warzone_mission.text.contains("Secure Hostile Command"),
		"Active final objective gains a unique marker, permanent mission name and HUD instruction")
	await capture("final-target")
	operation.objectives[final_site].owner = "allied"
	if final_site not in operation.supplied.allied: operation.supplied.allied.append(final_site)
	operation.consolidation = 7
	map.sync_warzone(operation)
	hud.set_warzone_status(host.state)
	check(final_marker.warzone_consolidation > 0.0
		and is_equal_approx(final_marker.warzone_consolidation, 7.0 / operation.tuning.consolidation_seconds)
		and final_marker.tooltip_text.contains("Consolidation")
		and hud.warzone_hold_bar.visible and hud.warzone_hold_bar.value == 7
		and hud.warzone_mission.text.contains("Hold Hostile Command"),
		"Secured final target displays authoritative consolidation time on marker and HUD")
	await capture("final-consolidation")
	operation.objectives[final_site].owner = previous_owner
	operation.supplied.allied = previous_supply
	operation.effort = previous_effort
	operation.player_intervened = previous_intervention
	operation.final_command = -1
	operation.consolidation = 0
	map.sync_warzone(operation)
	hud.set_warzone_status(host.state)
	check(final_marker.warzone_importance == 1 and final_marker.warzone_consolidation < 0.0
		and not final_marker.planet_name.text.begins_with("FINAL")
		and not hud.warzone_hold_bar.visible and operation.clock_ms == 0,
		"Returning to normal map state clears final highlighting without spending strategic time")
	var before_clock: int = operation.clock_ms
	for fleet in operation.fleets:
		var mount: Node3D = presentation.models[fleet.id]
		var profile: Resource = mount.get_meta("ship_profile")
		var hull := mount.find_child("Body", true, false)
		check(profile != null and hull != null and hull.find_child("Hull", true, false) != null,
			"Strategic fleet uses a real spacecraft scene")
		var solid := hull.find_child("Hull", true, false) as MeshInstance3D
		check(solid.material_override.next_pass == null and solid.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"Map hulls avoid battle material passes and shadows")
		if fleet.side == "hostile":
			var contact: Dictionary = host.state.encounters[operation.encounter_for_fleet(fleet)]
			check(contact.enemy_data.resource_path.get_file().begins_with("axiom") \
				and profile.model_scene == contact.enemy_data.model_scene and profile.ship_name == contact.enemy_data.ship_name,
				"Hostile visuals match the AXIOM contact")
	await touch(hud.lattice_button)
	check(not presentation.influence_field.visible and presentation.paths.get_surface_count() == 0
		and presentation.order_paths.get_surface_count() == 0, "Lattice OFF hides all tactical projections")
	host.show_system()
	check(not hud.lattice_button.button_pressed and not presentation.influence_field.visible,
		"Returning to the same map preserves the manual overlay choice")
	await capture("fleets-lattice-off")
	await touch(hud.lattice_button)
	check(presentation.influence_field.visible and presentation.paths.get_surface_count() == 1,
		"Lattice ON draws one influence mesh and one lattice line batch")
	var discovery: int = int(host.state.encounter_positions.keys().front())
	check(map.markers.has(discovery) and not map.markers[discovery].lattice_tag \
		and map.markers[discovery].tooltip_text == "Independent discovery",
		"Discoveries use neutral map markers instead of territorial controls")
	check(presentation.overlay_enabled and operation.clock_ms == before_clock,
		"Touch toggles the overlay while strategic time stays paused")
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
	var routes: ImmediateMesh = presentation.order_paths
	check(presentation.CONNECTION_WIDTH > presentation.ORDER_WIDTH, "Permanent links are wider than movement routes")
	var moving: Dictionary = operation.fleets[4]
	var original := moving.duplicate()
	moving.engaged = -1
	moving.destination = operation.root("hostile")
	moving.position = operation.objectives[moving.destination].position + Vector3(3.0, 0.0, 0.0)
	presentation.models[moving.id].position = moving.position
	presentation._update_orders()
	check(routes.get_surface_count() == 1 and presentation._order_endpoints.has(moving.position),
		"Hostile routes start at their displayed ship positions")
	var tip: Vector3 = operation.objectives[moving.destination].position
	check(presentation._order_endpoints.has(tip), "Hostile route ends at its actual destination")
	moving.destination = operation.site("shipyard")
	presentation._update_orders()
	check(presentation._order_endpoints.has(operation.objectives[moving.destination].position),
		"Hostile route follows reassigned orders")
	moving.position = operation.objectives[moving.destination].position
	presentation._update_orders()
	check(not presentation._order_endpoints.has(presentation.models[moving.id].position),
		"The route disappears at arrival")
	moving.merge(original, true)

	var forecast: Dictionary = map.markers[0].forecast
	check(not forecast.is_empty() and forecast.seconds > 0
		and is_equal_approx(forecast.allied_share, operation.engagement_predictions()[2].allied_share),
		"The map shows the simulated engagement estimate and allied share")
	await capture("lattice-overview")
	host._show_system_details()
	var paused_clock: int = operation.clock_ms
	await create_timer(0.25).timeout
	check(operation.clock_ms == paused_clock, "Reports pause continuous fleet simulation")
	host.screen.system_details_overlay.dismiss()
	check(presentation.fx.emitted_beams > 0, "Opening NPC engagements show beam exchanges")
	var before_influence: PackedVector4Array = presentation.influence_target.duplicate()
	var depot: int = operation.site("depot")
	var index: int = depot + operation.HOSTILE_GROUPS
	var point: Vector3 = operation.objectives[depot].position
	host.state.update_navigation_position(host.state.Defense.wire(point))
	host.state.arrive_destination(index)
	host.show_poi(index)
	root.size = Vector2i(960, 540)
	await settle()
	var titles: Array[String] = []
	for control in host.view.get_children():
		if control is Label: titles.append(control.text)
	check("Territorial Control" in titles and "Facility Operation" in titles,
		"Territory and the signature operation have separate sections")
	await capture("facility-operation")
	host._warzone_operation(index, "sabotage")
	await settle()
	check(operation.disrupted.has(depot) and presentation.influence_target != before_influence,
		"Real sabotage updates territory and link presentation")
	check(hud.war_effort_bar.value == minf(operation.effort, operation.tuning.effort_goal)
		and operation.effort > 0 and hud.war_effort_gain.text.begins_with("+"),
		"Operation updates the effort bar and gain indicator")
	check(map.markers[index].objective_value.contains("!"), "Disruption is identifiable without color")
	host.show_system()
	for attempt in 40:
		if host._map_input_allowed() and hud.lattice_button.is_visible_in_tree(): break
		await create_timer(0.025).timeout
	await settle()
	hud.lattice_button.button_pressed = false
	check(not map.markers[index].objective_value.contains("!") and not presentation.influence_field.visible
		and presentation.paths.get_surface_count() == 0, "Lattice OFF hides link disruption cues")
	hud.lattice_button.button_pressed = true
	check(map.markers[index].recharge_ratio >= 0.0, "The facility marker shows its own recharge ring")
	check(presentation.fx.emitted_impacts > 0, "Strategic volleys produce visible damage feedback")
	host.show_system()
	root.size = Vector2i(960, 540)
	await settle()
	for control in [hud.lattice_button, hud.war_effort_bar, hud.territory_bar, hud.warzone_summary]:
		check(root.get_visible_rect().encloses(control.get_global_rect()), "Warzone HUD fits Android landscape")
	for marker in map.markers.values():
		if not marker.lattice_show_name or not marker.planet_name.is_visible_in_tree() or marker.highlighted():
			continue
		var name_rect: Rect2 = marker.planet_name.get_global_rect()
		var overlaps: bool = map.markers.values().any(func(other):
			return (other != marker and other.is_visible_in_tree() and other.get_global_rect().intersects(name_rect)))
		check(not overlaps, "Station names leave moving map controls unobstructed")
	var allied_site: int = operation.HOSTILE_GROUPS + operation.root("allied")
	host.show_poi(allied_site)
	check(not _has_hold(host) and host.view.find_children("*", "Button", true, false).any(
		func(button): return button.text == "Activate Operation"),
		"Allied stations omit Hold Position and retain their special operation")
	var services: Array[Node] = host.view.find_children("WarzoneService", "Button", true, false)
	check(services.size() == 3 and services.any(
		func(button): return button.text.contains("Reactor") and button.text.contains("12 Salvage")), "Command station keeps Scramble alongside three production choices")
	await capture("command-preparation")
	var hostile_site: int = operation.HOSTILE_GROUPS + operation.root("hostile")
	host.show_poi(hostile_site)
	check(not _has_hold(host), "Out-of-range hostile stations do not offer automated capture")
	host.show_system()
	await settle()
	await capture("lattice-cutoff")
	var allied: Dictionary = operation.fleets[0]
	var old_allied := allied.duplicate()
	allied.position = Vector3(0, 0, 2)
	allied.engaged = -1
	allied.intercept = moving.id
	allied.assignment = "Intercepting"
	map.sync_warzone(operation)
	presentation._update_orders()
	check(presentation._order_colors.has(Color("4da7d6"))
		and presentation._order_endpoints.has(operation.fleet_target_position(allied)),
		"Allied dashed route marks the actual interception point")
	hud.lattice_button.button_pressed = false
	check(routes.get_surface_count() == 0, "Lattice OFF clears both sides' route mesh")
	hud.lattice_button.button_pressed = true
	allied.erase("intercept")
	allied.erase("assignment")
	allied.merge(old_allied, true)
	var command: int = operation.root("allied")
	operation.deploy_allied(command)
	map.sync_warzone(operation)
	await process_frame
	var inbound: Dictionary = operation.fleets.back()
	check(inbound.arriving and presentation.models[inbound.id].visible,
		"An appended reserve gets a ship model while earlier motion samples are still present")
	operation.scramble(command)
	map.sync_warzone(operation)
	await capture("allied-reinforcement")
	await _watch_aftermath(host, operation, presentation)
	root.size = Vector2i(1344, 576)
	await settle()
	for offset in operation.objectives.size():
		var anchor: Vector3 = operation.objectives[offset].position
		check(map.get_rect().size.x > 0 and root.get_visible_rect().has_point(map.camera.unproject_position(anchor)),
			"The ultrawide overview frames the generated objectives")

	var rules: Resource = host.rules
	host.free()
	await process_frame
	var restored := Save.new().decode(saved, rules)
	check(restored != null, "Saved moving fleets decode")
	if restored != null:
		var resumed = load("res://scenes/expedition.tscn").instantiate()
		resumed.resume_data = {"state": restored}
		resumed.persistence_enabled = false
		resumed.play_system_intro = false
		root.add_child(resumed)
		var resumed_map = resumed.star_map.warzone_presentation
		check(resumed_map.order_paths.get_surface_count() == 1 and resumed_map._order_colors.has(Color("4da7d6"))
			and resumed_map._order_colors.has(Color("cf5365")) and restored.warzone.clock_ms == 0
			and restored.warzone.fleets[0].position == Vector3(allied_order.position[0], allied_order.position[1], allied_order.position[2]),
			"A resumed map draws saved allied and hostile orders before time or positions change")
		resumed.free()
		await process_frame
	if DisplayServer.get_name() != "headless":
		await _check_projected_width()
	print("Warzone lattice presentation: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))


func _watch_aftermath(host: Node, operation: RefCounted, presentation: Node3D) -> void:
	Preferences.set_skip_cinematics(false)
	var allies: Dictionary = operation.fleets[0]
	var hostile: Dictionary = operation.fleets[4]
	for fleet in operation.fleets:
		fleet.strength = 0
		fleet.engaged = -1
		fleet.destination = fleet.at
	allies.strength = 1
	allies.position = operation.objectives[operation.root("allied")].position
	hostile.strength = 4
	hostile.position = Vector3(17, 0, -8)
	hostile.at = operation.site("shipyard")
	hostile.destination = hostile.at
	operation.final_command = operation.site("forward_command")
	operation.player_intervened = true
	operation.disrupted.clear()
	operation._award("aftermath:1", 40, "Final offensive fixture")
	operation._award("aftermath:2", 25, "Final offensive fixture")
	for site in operation.objectives.size():
		operation.objectives[site].owner = "allied"
	operation._refresh_supply()
	operation.consolidation = operation.tuning.consolidation_seconds - 1
	var salvage_before: int = host.state.salvage
	host.state._commit_activity_time(1)
	check(operation.complete and host.state.warzone_outcome.grade == "Pyrrhic Victory"
		and host.state.salvage == salvage_before + host.state.warzone_outcome.salvage,
		"The simulation commits pyrrhic victory and rewards before presentation")
	for attempt in 20:
		if host.warzone_victory_banner.active: break
		await process_frame
	check(host.warzone_victory_banner.active and host.screen.jump_button.disabled,
		"A skippable aftermath temporarily holds the FTL control")
	var ledger: Dictionary = operation.snapshot()
	var hostile_model: Node3D = presentation.models[hostile.id]
	var allied_model: Node3D = presentation.models[allies.id]
	var retreat: Vector3 = hostile_model.position
	var regroup: Vector3 = allied_model.position
	for frame in 8:
		presentation.animate_movement(0.1)
	check(hostile_model.visible and hostile_model.position.distance_to(retreat) > 0.1,
		"The hostile formation visibly withdraws before leaving the scene")
	check(allied_model.position.distance_to(regroup) > 0.05, "Allied ships visibly regroup")
	await capture("pyrrhic-aftermath")
	await touch(host.warzone_victory_banner._skip)
	check(not hostile_model.visible and not host.warzone_victory_banner.active and not host.screen.jump_button.disabled,
		"Skipping completes withdrawal and releases FTL")
	check(operation.snapshot() == ledger and host.state.salvage == salvage_before + host.state.warzone_outcome.salvage,
		"The aftermath never advances strategic time or pays the reward twice")


func _watch_fleet(host: Node, operation: RefCounted, presentation: Node3D) -> void:
	var fleet: Dictionary = operation.fleets[4]
	# Start a real supplied fleet down an uncontested corridor long enough to
	# detect the old one-second stop/start cycle in the actual moving model.
	var origin: int = operation.root("hostile")
	var target: int = operation.Lattice.neighbors(origin, operation.links).back()
	fleet.at = origin
	fleet.destination = target
	var point: Vector3 = operation.objectives[origin].position
	fleet.position = point
	operation.motion_samples.clear()
	var model: Node3D = presentation.models[fleet.id]
	var idle := model.position
	var idle_clock: int = operation.clock_ms
	await create_timer(0.3).timeout
	check(model.position == idle and operation.clock_ms == idle_clock, "Idle maps hold the fleet and clock")
	var player: Vector3 = host.star_map.ship.position
	# Keep real travel active through 12 samples even if a software-rendered
	# frame overruns a quarter-second timer.
	var bounds: Rect2 = host.State.SystemLayout.bounds(host.state.layout_expansion).grow(-1.0)
	var destination := player
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.y, bounds.end.y]:
			var corner := Vector3(x, 0, z)
			if player.distance_squared_to(corner) > player.distance_squared_to(destination):
				destination = corner
	host.star_map.travel_to_position(destination)
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
	check(host.phase == host.Phase.TRAVELING and presentation.motion.is_empty(), "Live lattice movement never enters the legacy playback queue")
	host.star_map.apply_navigation_position(host.State.Defense.point(host.state.navigation.position))
	host.state.cancel_travel()
	host.show_system()
	var stopped_clock: int = operation.clock_ms
	await create_timer(0.3).timeout
	check(operation.clock_ms == stopped_clock, "Stopping the player's ship also stops the lattice clock")


func _has_hold(host: Node) -> bool:
	return host.screen.find_children("*", "Button", true, false).any(
		func(button): return button.is_visible_in_tree() and button.text == "Hold Until Captured")


func _check_projected_width() -> void:
	var sample := SubViewport.new()
	sample.size = Vector2i(320, 240)
	sample.own_world_3d = true
	sample.transparent_bg = true
	sample.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sample)
	var camera := Camera3D.new()
	sample.add_child(camera)
	camera.make_current()
	var presentation := preload("res://scripts/presentation/star_system/warzone_presentation.gd").new()
	sample.add_child(presentation)
	var mesh: ImmediateMesh = presentation.paths
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var line := Vector3(4, 0, 0)
	presentation._ribbon(mesh, -line, line, Color.WHITE, 0.0)
	mesh.surface_end()
	var center := Vector3.DOWN * 0.12
	var widths: Array[int] = []
	for offset in [Vector3(0, 11, 7), Vector3(3, 20, 16), Vector3(5, 6, 6)]:
		camera.position = center + offset
		camera.look_at(center)
		await RenderingServer.frame_post_draw
		var capture := sample.get_texture().get_image()
		var pixel := camera.unproject_position(center)
		var tangent := pixel.direction_to(camera.unproject_position(center + line))
		var across := Vector2(-tangent.y, tangent.x)
		var thick := 0
		for step in range(-6, 7):
			var at := Vector2i((pixel + across * float(step)).floor())
			if capture.get_pixelv(at).a > 0.35: thick += 1
		widths.append(thick)
	check(widths.min() >= 3 and widths.max() <= 5 and widths.max() - widths.min() <= 1,
		"Rendered connection width stays within one pixel across tilt, rotation and zoom · %s" % [widths])
	sample.free()
