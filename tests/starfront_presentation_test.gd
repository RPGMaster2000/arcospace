extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 42042
	root.add_child(host)
	await process_frame
	await process_frame
	var map = host.star_map
	if DisplayServer.get_name() != "headless":
		for size in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1680,720)]:
			root.size = size
			await create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
			root.get_texture().get_image().save_png("res://.godot/testlogs/starfront-%s-%d.png" % [RenderingServer.get_current_rendering_method(), size.x])
		root.size = Vector2i(1280,720)
	check(host.state.is_defense() and map.planet_nodes.size() == 1, "Playable defense homeworld rendered")
	check(not map.objects[2].visible and map.objects[0].visible and map.objects[1].visible, "Hidden mothership and two visible attackers")
	check(map.ship.position.distance_to(host.state.defense.start) < 0.001, "Ship begins at authoritative home deployment")
	map.travel_to_position(map.ship.position + Vector3(5,0,0))
	await create_timer(0.15).timeout
	var enemy: Vector3 = host.state.defense.units[0].position
	check(host.phase == host.Phase.TRAVELING, "Free travel starts")
	host.settings_button.menu.shade.show()
	await process_frame
	var stopped: Vector3 = map.ship.position
	await create_timer(0.15).timeout
	check(map.ship.position == stopped, "Menu pauses actual ship travel")
	check(host.state.defense.units[0].position == enemy, "Menu freezes enemies")
	host.settings_button.menu.shade.hide()
	await create_timer(0.6).timeout
	check(host.phase == host.Phase.OVERVIEW, "Arrival ends physical travel")
	check(host.state.defense.units[0].position != enemy, "Moving ship advances rendered enemy")
	enemy = host.state.defense.units[0].position
	await create_timer(0.1).timeout
	check(host.state.defense.units[0].position == enemy, "Idle overview freezes strategic movement")
	check(map.defense_effects.histories[-999].size() > 1, "Player history records actual travel")
	await create_timer(1.0).timeout
	var chosen: int = 0 if map.markers[0].visible else 1
	check(map.markers[chosen].visible, "At least one attacker has a visible touch target")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = map.markers[chosen].get_global_rect().get_center()
	var camera_before: Vector3 = map.camera.position
	touch.pressed = true
	root.push_input(touch, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = touch.position + Vector2(25, 10)
	drag.relative = Vector2(25, 10)
	root.push_input(drag, true)
	touch.position = drag.position
	touch.pressed = false
	root.push_input(touch, true)
	check(host.state.travel_destination == -1 and map.camera.position != camera_before, "Dragging over a hostile pans without selecting it")
	await create_timer(0.25).timeout
	touch.position = map.markers[chosen].get_global_rect().get_center()
	touch.pressed = true
	root.push_input(touch, true)
	await process_frame
	touch.pressed = false
	root.push_input(touch, true)
	await process_frame
	check(host.state.travel_destination == chosen, "Touch selects a moving hostile target")
	for frame in range(400):
		await create_timer(0.02).timeout
		if host.state.defense.contact >= 0: break
	check(host.state.defense.contact >= 0 and host.phase == host.Phase.DESTINATION, "Moving attacker triggers existing battle preview")
	check(not map.traveling and not host.state.navigation.leg_active and host.state.travel_destination == -1, "Interception cancels journey permanently")
	if host.state.defense.contact >= 0:
		var index: int = host.state.defense.contact
		host.start_battle(index, 123)
		await process_frame
		await process_frame
		check(is_instance_valid(host.battle), "Existing card battle starts from moving contact")
		var board = host.battle
		var normal_threshold: int = board.ftl.charge_target
		var battle_positions: Dictionary = host.state.defense.snapshot()
		check(normal_threshold == host.state.ship().ftl_turns, "Ordinary encounter retains authored EMP threshold")
		await create_timer(0.6).timeout
		check(host.state.defense.snapshot() == battle_positions, "Card battle freezes every strategic unit")
		board.ftl.disabled_turns = 0
		board.ftl.charge = board.ftl.charge_target
		board.current_actor = "player"
		board._warp_out()
		check(board.result_recorded and host.state.defense.revealed and host.state.salvage == 0, "Actual EMP combat result neutralizes attacker without destruction Salvage")
		board._continue_encounter()
		await create_timer(1.4).timeout
		check(map.objects[2].visible and not host.state.defense.reveal_pending and host.phase == host.Phase.OVERVIEW, "Post-combat mothership reveal completes once")
		map.travel(2)
		for frame in range(400):
			await create_timer(0.02).timeout
			if host.state.defense.contact == 2: break
		# A surviving attacker may cross the chosen route. Resolve that valid
		# interception, then continue manually toward the stationary mothership.
		if host.state.defense.contact >= 0 and host.state.defense.contact != 2:
			host.start_battle(host.state.defense.contact, 125)
			await create_timer(0.6).timeout
			board = host.battle
			board.ftl.disabled_turns = 0
			board.ftl.charge = board.ftl.charge_target
			board.current_actor = "player"
			board._warp_out()
			board._continue_encounter()
			await process_frame
			map.travel(2)
			for frame in range(400):
				await create_timer(0.02).timeout
				if host.state.defense.contact == 2: break
		check(host.state.defense.contact == 2, "Revealed mothership can be intercepted")
		host.start_battle(2, 124)
		await process_frame
		board = host.battle
		check(is_instance_valid(board), "Mothership existing card battle starts")
		if is_instance_valid(board):
			check(board.ftl.charge_target == normal_threshold + 2, "Actual mothership combat enforces flat EMP resistance")
			board.refresh_display()
			check(board.get_node("FTLPanel/Charge").tooltip_text.contains("/ %d" % board.ftl.charge_target), "Combat HUD displays adjusted EMP requirement")
			board.ftl.charge = normal_threshold
			check(not board.ftl.can_warp(), "Normal threshold cannot neutralize mothership")
			await create_timer(0.6).timeout
			board.ftl.disabled_turns = 0
			board.ftl.charge = board.ftl.charge_target
			board.current_actor = "player"
			board._warp_out()
			board._continue_encounter()
			await process_frame
			check(host.state.can_jump() and host.state.defense.complete and not host.jump_button.disabled, "Mothership EMP unlocks voluntary FTL in actual HUD")
			var departure_origin: Vector3 = map.ship.position
			host._jump()
			await create_timer(2.4).timeout
			check(map.ship.position.distance_to(departure_origin) > 0.1, "FTL presentation animates departure without advancing defense")
			for frame in range(500):
				await create_timer(0.02).timeout
				if host.state.system_number == 2 and host.phase == host.Phase.OVERVIEW: break
			check(host.state.system_number == 2 and host.state.defense.integrity == 100 and not host.state.defense.revealed and host.state.defense.units[0].status == "active", "FTL cinematic generates next playable defense loop")
	host.queue_free()
	await process_frame
	await process_frame
	var defeated = preload("res://scenes/expedition.tscn").instantiate()
	defeated.persistence_enabled = false
	defeated.play_system_intro = false
	defeated.use_star_map = false
	defeated.use_3d_star_map = false
	root.add_child(defeated)
	await process_frame
	check(defeated.star_map.has_method("sync_defense"), "Defense uses its physical 3D map even when legacy fallback is selected")
	defeated.state.defense.units[0].position = defeated.state.defense.home
	defeated.state.defense.units[1].position = defeated.state.defense.home
	defeated.state.navigation.checkpoint_position([0,100,0])
	defeated.state.begin_free_travel([1,100,0])
	defeated.phase = defeated.Phase.TRAVELING
	defeated.state.navigation.report_movement([1,100,0])
	check(defeated.state.run_ended and not defeated.star_map.visible, "Failed objective opens expedition defeat rather than a locked map")
	var labels: Array = defeated.view.find_children("*", "Label", true, false)
	check(labels.any(func(label): return label.text.contains("all attackers reached")), "Defeat explains why the mothership is unreachable")
	defeated.queue_free()
	await process_frame
	var exploring = preload("res://scenes/expedition.tscn").instantiate()
	exploring.persistence_enabled = false
	exploring.play_system_intro = false
	exploring.rules = exploring.rules.duplicate(true)
	exploring.rules.debug_seed = 42042
	root.add_child(exploring)
	await create_timer(1.0).timeout
	var poi_index: int = -1
	var nearest: float = INF
	for i in range(3, exploring.state.encounters.size()):
		if exploring.star_map.markers[i].visible:
			var distance: float = exploring.state.defense.anchors[i].distance_to(exploring.star_map.ship.position)
			if distance < nearest:
				nearest = distance
				poi_index = i
	check(poi_index >= 0, "Ordinary PoI has a visible touch target")
	if poi_index >= 0:
		var poi_touch := InputEventScreenTouch.new()
		poi_touch.index = 0
		poi_touch.position = exploring.star_map.markers[poi_index].get_global_rect().get_center()
		poi_touch.pressed = true
		root.push_input(poi_touch, true)
		await process_frame
		poi_touch.pressed = false
		root.push_input(poi_touch, true)
		await process_frame
		check(exploring.state.travel_destination == poi_index, "Touch selects an ordinary PoI")
		for frame in range(300):
			await create_timer(0.02).timeout
			if exploring.phase == exploring.Phase.DESTINATION: break
		check(exploring.selected_encounter == poi_index, "Physical PoI arrival opens its existing interaction")
		var paused_units: Dictionary = exploring.state.defense.snapshot()
		await create_timer(0.3).timeout
		check(exploring.state.defense.snapshot() == paused_units, "PoI interaction freezes strategic movement")
	exploring.queue_free()
	await process_frame
	print("Starfront presentation: %d failures" % failures)
	quit(1 if failures else 0)
