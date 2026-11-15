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
	var deadline := (
		Time.get_ticks_msec() + (40000 if DisplayServer.get_name() != "headless" else 10000)
	)
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
	host.battle.enemy_timer.stop()
	host.battle.battle_effects.enabled = false
	host.battle.cinematic_settings = host.battle.cinematic_settings.duplicate(true)
	host.battle.cinematic_director.settings = host.battle.cinematic_settings
	host.battle.cinematic_settings.orbit_seconds = .2
	host.battle.cinematic_settings.boost_seconds = .12
	host.battle.cinematic_settings.fade_seconds = .06
	return host


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/battle-camera")
	root.get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/battle-camera/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), label]
		)
	)


func stage_capture(board: Node, label: String) -> void:
	await process_frame
	if is_instance_valid(board) and board.cinematic_director.active:
		await capture(label)


func boost_alignment(board: Node) -> void:
	var director = board.cinematic_director
	var forward: Vector3 = director.player.global_basis.x.normalized()
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


func win_and_upgrade(host: Node) -> void:
	var source: Node = host.battle
	source.enemy_hull = 0
	source._check_winner()
	source.refresh_display()
	await wait_until(
		func(): return not source.resolving_card and not source.battle_effects.busy,
		"Winning resolution ready"
	)
	var committed_salvage: int = host.state.salvage
	source._continue_encounter()
	check(host.state.active_battle == -1, "Original continuation boundary clears active battle")
	check(
		host.state.pending_choice == "upgrade" and host.card_management.shade.visible,
		"Upgrade UI precedes departure"
	)
	while host.state.pending_choice == "upgrade" and not host.state.upgrade_candidates().is_empty():
		host._upgrade(host.state.upgrade_candidates()[0].identity_key())
	check(host.state.pending_choice.is_empty(), "Existing upgrade workflow completes")
	check(
		host.state.salvage == committed_salvage, "Upgrade/continuation does not duplicate rewards"
	)


func _initialize() -> void:
	previous_skip = Preferences.skip_cinematics()
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1280, 720)
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "0")
	var baseline := fresh()
	await win_and_upgrade(baseline)
	baseline.show_system()
	var expected := snapshot(baseline.state)
	baseline.free()
	await process_frame
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	for skipped_stage in ["", "victory_orbit", "engine_boost", "fade_to_black", "preference"]:
		var host := fresh()
		var source: Node = host.battle
		await win_and_upgrade(host)
		check(
			host.battle == null and host.battle_session.returning == source and not source.visible,
			"Original board retained hidden, not duplicated"
		)
		check(
			(
				source.get_node("BattleView/Viewport").render_target_update_mode
				== SubViewport.UPDATE_DISABLED
			),
			"Hidden battle viewport stops rendering during upgrades"
		)
		check(not host.battle_session.return_in_progress, "No orbit before the final return action")
		if skipped_stage.is_empty():
			source.cinematic_settings.boost_seconds = .85
		Preferences.set_skip_cinematics(skipped_stage == "preference")
		var stages: Array = []
		var before := snapshot(host.state)
		var notifications := [0]
		host.state.progress_committed.connect(func(): notifications[0] += 1)
		source.cinematic_director.stage_changed.connect(
			func(label):
				stages.append(label)
				if label == "engine_boost" and skipped_stage.is_empty():
					boost_alignment(source)
				check(snapshot(host.state) == before, "Camera stages cannot mutate committed state")
				if label == skipped_stage:
					source.cinematic_director.skip()
				if skipped_stage.is_empty():
					stage_capture(source, label)
		)
		var covered := [false]
		source.tree_exiting.connect(
			func():
				covered[0] = (
					host.battle_return_transition.curtain.visible
					and host.battle_return_transition.curtain.color.a >= .999
				)
				check(not source.cinematic_director.active, "Camera released before board removal")
		)
		host.show_system()
		host.show_system()  # Repeated confirmation must not create another departure.
		await wait_until(
			func():
				return (
					not host.battle_session.return_in_progress
					and not host.battle_return_transition.curtain.visible
				),
			"Orbit/boost/fade returns to system"
		)
		check(covered[0], "Board replaced only under opaque black curtain")
		check(
			(
				host.phase == host.Phase.OVERVIEW
				and host.star_map.visible
				and host._map_input_allowed()
			),
			"Map camera/input and UI restored"
		)
		check(
			snapshot(host.state) == expected and notifications[0] == 0,
			"Cinematic return equals original save state without additional progression events"
		)
		if skipped_stage.is_empty():
			check(
				stages == ["victory_orbit", "engine_boost", "fade_to_black"],
				"Victory stages execute once and in order"
			)
		if skipped_stage == "preference":
			check(
				stages == ["fade_to_black"], "Skip Cinematics retains mandatory covered transition"
			)
		host.free()
		await process_frame
	# Ordinary EMP escape takes the existing immediate continuation path.
	var host := fresh()
	var source: Node = host.battle
	source.ftl.charge = source.ftl.charge_target
	source._warp_out()
	source._continue_encounter()
	check(
		not is_instance_valid(host.battle_session.returning),
		"Ordinary EMP escape has no victory departure"
	)
	host.free()
	await process_frame
	Preferences.set_skip_cinematics(previous_skip)
	print("Battle victory departure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
