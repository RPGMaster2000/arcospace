extends SceneTree
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0
var previous_skip := false


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func wait_until(condition: Callable, message: String) -> void:
	var deadline := Time.get_ticks_msec() + 40000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(condition.call(), message)


func snapshot(state: Resource) -> Dictionary:
	return JSON.parse_string(JSON.stringify(Save.encode(state)))


func fresh() -> Node:
	Preferences.set_skip_cinematics(true)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.game_mode = "defense"
	host.rules.debug_seed = 717
	root.add_child(host)
	host.state.defense.contact = 0
	host.start_battle(0, 707)
	var board: Node = host.battle
	board.enemy_timer.stop()
	board.battle_effects.enabled = false
	board.cinematic_settings = board.cinematic_settings.duplicate(true)
	board.cinematic_director.settings = board.cinematic_settings
	board.cinematic_settings.attack_seconds = .1
	board.cinematic_settings.orbit_seconds = .2
	board.cinematic_settings.boost_seconds = .2
	board.cinematic_settings.fade_seconds = .04
	return host


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/battle-sequencing")
	root.get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/battle-sequencing/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), label]
		)
	)


func stage_capture(board: Node, label: String) -> void:
	await process_frame
	if is_instance_valid(board) and board.cinematic_director.active:
		await capture(label)


func result_ready(board: Node) -> bool:
	return (
		board.get_node("MatchResult").visible
		and not board._presentation_locked()
		and not board.resolving_card
		and not board.battle_effects.busy
	)


func boost_alignment(board: Node) -> void:
	var director = board.cinematic_director
	var forward: Vector3 = director.player.global_basis.x.normalized()
	var departure_pose: Transform3D = director.camera.global_transform
	check(
		forward.dot(director.camera.global_position - director.player.global_position) < 0,
		"Boost camera finishes behind the model's actual forward axis"
	)
	await process_frame
	await process_frame
	check(
		is_instance_valid(board) and director.active,
		"Unskipped boost remains active for its configured duration"
	)
	if is_instance_valid(board) and director.active:
		var body_delta: Vector3 = director.player.get_node("Body").position - director._body_rest
		var shield_delta: Vector3 = (
			director.player.get_node("Shield").position - director._shield_rest
		)
		check(
			body_delta.length() > 0 and body_delta.is_equal_approx(shield_delta),
			"Shield follows the accelerating hull instead of remaining at the battle anchor"
		)
		check(director.camera.global_transform.is_equal_approx(departure_pose), "Departure camera stays fixed through thrust")


func win(board: Node) -> void:
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	await wait_until(
		func(): return result_ready(board), "Committed victory reaches usable result screen"
	)


func finish_upgrades(host: Node) -> void:
	var board: Node = host.battle
	var salvage: int = host.state.salvage
	board._continue_encounter()
	check(
		host.state.active_battle == -1 and host.battle == null,
		"Existing result confirmation removes the completed board once"
	)
	check(
		host.state.pending_choice == "upgrade" and host.card_management.shade.visible,
		"Existing upgrade UI follows result confirmation"
	)
	while host.state.pending_choice == "upgrade" and not host.state.upgrade_candidates().is_empty():
		host._upgrade(host.state.upgrade_candidates()[0].identity_key())
	check(
		host.state.pending_choice.is_empty() and host.state.salvage == salvage,
		"Upgrades complete without duplicate rewards"
	)
	host.show_system()
	await wait_until(
		func(): return host._map_input_allowed(),
		"Existing card-management close finishes before map input"
	)
	check(
		host.phase == host.Phase.OVERVIEW and host.star_map.visible and host._map_input_allowed(),
		"Original final return restores map input without another departure"
	)


func _initialize() -> void:
	previous_skip = Preferences.skip_cinematics()
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1280, 720)
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "0")
	var baseline := fresh()
	await win(baseline.battle)
	await finish_upgrades(baseline)
	var expected := snapshot(baseline.state)
	baseline.free()
	await process_frame
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	for skipped_stage in ["", "victory_orbit", "engine_charge", "engine_boost", "fade_to_black", "preference"]:
		var host := fresh()
		var board: Node = host.battle
		var director = board.cinematic_director
		if skipped_stage.is_empty():
			board.cinematic_settings.boost_seconds = .38
		Preferences.set_skip_cinematics(skipped_stage == "preference")
		var events: Array = []
		var committed: Array = [{}]
		var progress := [0]
		host.state.progress_committed.connect(func(): progress[0] += 1)
		var rectangles: Array = []
		for slot in board.card_slots:
			rectangles.append(board.get_node(slot).get_global_rect())
		director.stage_changed.connect(
			func(stage):
				events.append(stage)
				if stage == "engine_boost" and skipped_stage.is_empty():
					boost_alignment(board)
				check(
					(
						not board.get_node("MatchResult").visible
						and not board.get_node("MatchResult").started
					),
					"All camera stages precede Victory screen reveal"
				)
				check(
					snapshot(host.state) == committed[0],
					"Cinematic stages cannot mutate the committed save state"
				)
				board._continue_encounter()
				check(
					host.battle == board and host.state.active_battle == 0,
					"Early/repeated Continue cannot bypass presentation"
				)
				if stage == "victory_orbit":
					check(
						not board.destruction_pending, "Destruction VFX finish before victory orbit"
					)
				if stage == skipped_stage:
					director.skip()
				if skipped_stage.is_empty():
					stage_capture(board, stage)
		)
		board.get_node("MatchResult").visibility_changed.connect(
			func():
				if board.get_node("MatchResult").visible:
					events.append("result")
					check(
						(
							board.victory_transition.curtain.visible
							and board.victory_transition.curtain.color.a >= .999
						),
						"Result is constructed only under completed black fade"
					)
		)
		board.enemy_hull = 0
		board._check_winner()
		committed[0] = snapshot(host.state)
		board.refresh_display()
		if director.kind == "destruction" and director.active:
			check(
				board.get_node("BattleView").offset_bottom == -325,
				"Destruction stays in normal viewport"
			)
			for i in board.card_slots.size():
				check(
					(
						board.get_node(board.card_slots[i]).visible
						and board.get_node(board.card_slots[i]).get_global_rect() == rectangles[i]
					),
					"Destruction preserves card visibility and geometry"
				)
		await wait_until(
			func(): return result_ready(board),
			"Orbit, boost, black fade then interactive Victory screen"
		)
		check(
			board.victory_ready and events[-1] == "result",
			"Victory screen is last, after camera stages"
		)
		check(
			events.count("fade_to_black") == 1 and events.count("result") == 1,
			"Exactly one covered handoff and result reveal"
		)
		check(
			progress[0] == 1 and snapshot(host.state) == committed[0],
			"Victory presentation emits no extra progression or reward commits"
		)
		if skipped_stage.is_empty():
			check(
				(
					events.find("impact_hold") < events.find("victory_orbit")
					and events.find("victory_orbit") < events.find("engine_charge")
					and events.find("engine_charge") < events.find("engine_boost")
					and events.find("fade_to_black") < events.find("result")
				),
				"Destruction, departure and result execute in order"
			)
			await capture("victory-result")
		if skipped_stage == "preference":
			check(
				events == ["fade_to_black", "result"],
				"Skip preference bypasses camera motion but preserves sequence"
			)
		var stage_count := events.size()
		await finish_upgrades(host)
		check(
			events.size() == stage_count, "Upgrades and map return never replay departure or fade"
		)
		check(
			snapshot(host.state) == expected,
			"New presentation order preserves original final save record"
		)
		host.free()
		await process_frame
	# Defeat and ordinary EMP escape never enter the player's departure sequence.
	for outcome in ["defeat", "escape"]:
		var host := fresh()
		var board: Node = host.battle
		await wait_until(
			func(): return not board.resolving_card and not board.battle_effects.busy,
			"Initial turn is ready before legal non-victory action"
		)
		if outcome == "defeat":
			board.player_hull = 0
			board._check_winner()
			board.refresh_display()
		else:
			board.ftl.charge = board.ftl.charge_target
			board._warp_out()
			check(board.escaped_by_ftl, "Fully charged legal EMP escape actually resolves")
		await wait_until(
			func():
				return board.get_node("MatchResult").visible and not board._presentation_locked(),
			"Non-victory retains its existing result flow: " + outcome
		)
		check(
			not board.victory_started and board.cinematic_director.kind != "departure",
			"Defeat and ordinary FTL escape have no victory orbit"
		)
		host.free()
		await process_frame
	Preferences.set_skip_cinematics(previous_skip)
	print("Battle victory departure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
