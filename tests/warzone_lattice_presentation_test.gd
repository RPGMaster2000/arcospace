extends "res://tests/warzone_presentation_test.gd"


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
	check(map.visual_data.starless and not map.objects.has(-100) and not map.world.get_node("SunLight").visible
		and map.visual_root.has_node("SectorFill"), "Live Warzone map has sky and fill lighting without a sun")
	check(presentation.influence != null and presentation.influence_target.size() == 12
		and presentation.paths.get_surface_count() == 1, "One influence mesh and one lattice line batch")
	check(hud.war_effort_bar.visible and hud.lattice_button.visible and operation.engagement_count() == 2,
		"War Effort, lattice control and two opening engagements")
	var before_clock: int = operation.clock_ms
	await touch(hud.lattice_button)
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
	var depot := 5
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
	await capture("lattice-cutoff")
	await _watch_aftermath(host, operation, presentation)
	host.free()
	await process_frame
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
	allies.position = operation.objectives[operation.ALLIED_ROOT].position
	hostile.strength = 4
	hostile.position = Vector3(17, 0, -8)
	hostile.at = 8
	hostile.destination = 8
	operation.final_command = 6
	operation.player_intervened = true
	operation.disrupted.clear()
	operation._award("aftermath:1", 40, "Final offensive fixture")
	operation._award("aftermath:2", 25, "Final offensive fixture")
	for site in [3, 4, 5, 6, 7]:
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
	var origin: int = operation.HOSTILE_ROOT
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
	host.star_map.travel_to_position(player + Vector3(0, 0, 30))
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
