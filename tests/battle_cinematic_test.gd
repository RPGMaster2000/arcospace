extends SceneTree
const Board = preload("res://scenes/board_3d.tscn")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0
var previous_skip := false
var previous_vfx := true


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func wait_until(condition: Callable, label: String, seconds: float = 10) -> void:
	var deadline := (
		Time.get_ticks_msec()
		+ int(seconds * 1000 * (4 if DisplayServer.get_name() != "headless" else 1))
	)
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(condition.call(), label)


func fresh(profile: Resource = null, arena: int = 0) -> Node:
	var state := State.new()
	var rules := Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	state.start(0, rules, 717)
	state.defense.contact = 0
	if profile != null:
		state.encounters[0].enemy_data = profile
	var setup = state.prepare_battle(0)
	setup.battle_seed = 707
	setup.modifier = arena
	var board = Board.instantiate()
	board.expedition = state
	Adapter.configure(board, setup)
	board.cinematic_settings = board.cinematic_settings.duplicate(true)
	board.cinematic_settings.introduction_seconds = (
		Vector3(.08, .08, .12)
		if DisplayServer.get_name() == "headless"
		else Vector3(1.15, 1.05, 1.25)
	)
	board.cinematic_settings.attack_seconds = .16
	if DisplayServer.get_name() == "headless":
		board.cinematic_settings.beam_charge_seconds = .12
		board.cinematic_settings.beam_impact_hold = .12
	board.cinematic_settings.orbit_seconds = .12
	board.cinematic_settings.boost_seconds = .10
	board.cinematic_settings.fade_seconds = .06
	board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate(true)
	board.get_node("CardMotion").settings.enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	return board


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


func shot_capture(board: Node, label: String) -> void:
	await process_frame
	if is_instance_valid(board) and board.cinematic_director.active:
		await capture(label)


func settle_board(board: Node) -> void:
	await wait_until(
		func():
			return (
				not board.cinematic_director.active
				and not board.resolving_card
				and not board.battle_effects.busy
			),
		"Battle input becomes available"
	)
	board.enemy_timer.stop()


func introduction_checks() -> void:
	Preferences.set_skip_cinematics(false)
	for profile in [
		load("res://ships/enemy/scrap_skiff.tres"),
		load("res://ships/enemy/siege_monitor.tres"),
		load("res://ships/enemy/axiom_command_nexus.tres")
	]:
		var board := fresh(profile)
		var director = board.cinematic_director
		var stages: Array = [director.stage]
		var camera_rest: Transform3D = director._camera_rest
		var actor_rest: Transform3D = director.player.transform
		var enemy_rest: Transform3D = director.enemy.transform
		var before := Save.encode(board.expedition)
		check(
			director.active and board._presentation_locked(),
			"Introduction locks real battle actions"
		)
		check(not board._act("player", 0, false), "Card input rejected during introduction")
		director.stage_changed.connect(
			func(stage):
				stages.append(stage)
				shot_capture(board, profile.resource_path.get_file().get_basename() + "-" + stage)
		)
		await shot_capture(board, profile.resource_path.get_file().get_basename() + "-establishing")
		var radius: float = director._bounds[director.enemy].radius
		check(
			(
				director.camera.global_position.distance_to(director._center(director.enemy))
				> radius + director.camera.near
			),
			"Measured hull stays clear of flyby camera"
		)
		await wait_until(func(): return director.stage == "confrontation", "Third shot frames the enemy")
		var forward: Vector3 = director.enemy.global_basis.x.normalized()
		var close: Vector3 = director.camera.global_position - director._center(director.enemy)
		check(close.normalized().dot(forward) > .95 and close.length() > radius, "Third shot starts off the nose at a hull-safe distance")
		await settle_board(board)
		check(
			stages == ["establishing", "flyby", "confrontation"],
			"Three distinct introduction shots in order"
		)
		check(
			(
				director.camera.global_transform == camera_rest
				and is_equal_approx(board.get_node("BattleView").offset_bottom, -325)
			),
			"Default pose and viewport restored"
		)
		check(
			(
				is_equal_approx(director.player.position.x, actor_rest.origin.x)
				and is_equal_approx(director.enemy.position.x, enemy_rest.origin.x)
			),
			"Battle ship anchors never move"
		)
		check(
			Save.encode(board.expedition) == before,
			"Introduction does not commit progression or consume expedition RNG"
		)
		board.free()
		await process_frame
	for arena in range(8):
		var board := fresh(null, arena)
		board.cinematic_director.skip()
		await settle_board(board)
		check(
			board.battle_camera.global_transform == board.cinematic_director._camera_rest,
			"Every arena restores gameplay camera after skip"
		)
		board.free()
		await process_frame
	Preferences.set_skip_cinematics(true)
	var board := fresh()
	check(not board.cinematic_director.active, "Skip Cinematics bypasses camera intro")
	await settle_board(board)
	board.free()
	await process_frame


func input_and_parity_checks() -> void:
	# Exercise the actual overlay button, rather than calling skip directly.
	Preferences.set_skip_cinematics(false)
	for viewport_size in [
		Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1280, 573)
	]:
		root.size = viewport_size
		var board := fresh()
		await process_frame
		var button: Button = board.cinematic_director.skip_button
		var point := button.get_global_rect().get_center()
		var touch := InputEventScreenTouch.new()
		touch.position = point
		touch.pressed = true
		root.push_input(touch, true)
		touch = touch.duplicate()
		touch.pressed = false
		root.push_input(touch, true)
		await process_frame
		check(
			not board.cinematic_director.active,
			"Touch input invokes the actual Skip button handler"
		)
		await settle_board(board)
		check(
			not board.cinematic_director.active,
			"Real touchscreen Skip restores battle at %s" % viewport_size
		)
		board.cinematic_director.skip()
		board.cinematic_director.skip()
		check(not board._presentation_locked(), "Repeated skip is harmless")
		board.free()
		await process_frame
	root.size = Vector2i(1280, 720)
	var expected: Dictionary = {}
	for enabled in [false, true]:
		OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1" if enabled else "0")
		var board := fresh()
		await settle_board(board)
		var record := {
			"state": board._both_states(),
			"save": Save.encode(board.expedition),
			"draw_rng": board.hand.rng.state,
			"enemy_draw_rng": board.enemy_hand.rng.state,
			"ai_rng": board.enemy_ai.rng.state,
			"ftl_rng": board.ftl.rng.state
		}
		if not enabled:
			expected = record
		else:
			check(
				record == expected,
				"Camera intro leaves combat resources, all RNG streams and save records identical"
			)
		board.free()
		await process_frame
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	Preferences.set_skip_cinematics(true)
	var board := fresh()
	await settle_board(board)
	Preferences.set_skip_cinematics(false)
	# Description words are not weapon metadata; resource effects never start a beam shot.
	var card = load("res://cards/27_missile_barrage.tres").duplicate(true)
	card.description = "Beam laser damage"
	card.effects = {"energy": 3}
	board.hand.cards[0] = card
	board.player_crew = 99
	await board._resolve_after_activation("player", 0, false, card)
	check(
		not board.cinematic_director.active,
		"Unrelated effect cannot select a camera from card prose"
	)
	board.free()
	await process_frame


func track_destruction_hud(board: Node) -> Dictionary:
	var controls: Array = [
		board.player_hull_label,
		board.enemy_hull_label,
		board.player_shields_label,
		board.enemy_shields_label,
		board.player_materials_label,
		board.player_energy_label,
		board.player_crew_label,
		board.enemy_materials_label,
		board.enemy_energy_label,
		board.enemy_crew_label,
		board.allocation_button
	]
	for slot in board.card_slots:
		controls.append(board.get_node(slot))
	var rectangles: Array = []
	for control in controls:
		rectangles.append(control.get_global_rect())
	var audit := {"intact": true, "frames": 0}
	var observe := func():
		if not is_instance_valid(board) or not board.destruction_pending:
			return
		audit.frames += 1
		audit.intact = audit.intact and board.get_node("BattleView").offset_bottom == -325
		for i in controls.size():
			audit.intact = (
				audit.intact
				and controls[i].is_visible_in_tree()
				and controls[i].get_global_rect() == rectangles[i]
				and controls[i].modulate.a == 1.0
			)
	process_frame.connect(observe)
	audit["observe"] = observe
	return audit


func finish_destruction_hud(audit: Dictionary) -> void:
	process_frame.disconnect(audit.observe)
	audit.erase("observe") # Break the observer closure/dictionary cycle.
	check(
		audit.intact and audit.frames > 1,
		"Every destruction VFX frame preserves the complete HUD, hand geometry and normal viewport"
	)


func defeat_hud_checks() -> void:
	Preferences.set_skip_cinematics(true)
	var board := fresh()
	await settle_board(board)
	Preferences.set_skip_cinematics(false)
	board.current_actor = "enemy"
	board.enemy_hand.cards[0] = load("res://cards/27_missile_barrage.tres")
	board.enemy_crew = 99
	board.player_shields = 0
	board.player_hull = 3
	board.refresh_display()
	var audit := track_destruction_hud(board)
	board._act("enemy", 0, false)
	await wait_until(
		func(): return board.destruction_pending, "Enemy attack starts real player destruction VFX"
	)
	await shot_capture(board, "player-destruction-hud")
	await wait_until(
		func():
			return (
				not board.destruction_pending
				and not board._presentation_locked()
				and board.get_node("MatchResult").visible
			),
		"Player destruction finishes at the existing defeat result"
	)
	finish_destruction_hud(audit)
	check(
		board.winner == "enemy" and not board.victory_started,
		"Confirmed player destruction cannot trigger a victory departure"
	)
	board.free()
	await process_frame


func attack_checks() -> void:
	for side in ["player", "enemy"]:
		for damage in [6, 16]:
			Preferences.set_skip_cinematics(true)
			var board := fresh()
			await settle_board(board)
			Preferences.set_skip_cinematics(false)
			var director = board.cinematic_director
			var seen: Array = []
			director.stage_changed.connect(func(stage): seen.append(stage))
			var card = load("res://cards/27_missile_barrage.tres").duplicate(true)
			card.effects = {"damage": damage}
			var hand = board.hand if side == "player" else board.enemy_hand
			hand.cards[0] = card
			board.set(side + "_crew", 99)
			var target := "enemy" if side == "player" else "player"
			board.set(target + "_shields", 0)
			board.set(target + "_hull", 100)
			var beams := [0]
			director.stage_changed.connect(func(stage):
				if stage == "beam_charge":
					var rect := Rect2(Vector2.ZERO, director.camera.get_viewport().get_visible_rect().size)
					for ship in [director.player, director.enemy]:
						check(rect.has_point(director.camera.unproject_position(director._center(ship))), "Side-on frame establishes both ships")
					check(board.get(target + "_hull") == 100 and beams[0] == 0, "Charge precedes damage and weapon launch")
				if stage == "impact_hold":
					check(board.get(target + "_hull") == 100 and beams[0] == 1, "Victim pose established before authoritative impact")
					check(director.camera.global_transform.is_equal_approx(director._beam_victim_pose), "Impact uses victim-focused camera")
			)
			board.battle_effects.weapon_presented.connect(func(_side, _kind):
				beams[0] += 1
				if damage >= director.settings.heavy_beam_threshold:
					check(director.stage == "beam_turn" and is_instance_valid(board.battle_effects.active_beam), "Pan begins on the visible beam launch event")
			)
			await board._resolve_after_activation(side, 0, false, card)
			check(
				board.get(target + "_hull") == 100 - damage and beams[0] == 1,
				"Actual beam damage committed once"
			)
			check(
				director.active == (damage >= director.settings.heavy_beam_threshold),
				"Only actual high-damage beam starts a shot"
			)
			if director.active:
				check(seen == ["beam_charge", "beam_turn", "impact_hold"], "Heavy beam camera follows the weapon timeline")
				check(director.kind == "heavy_beam", "Nonlethal shot has heavy-beam identity")
				await shot_capture(board, "heavy-" + side)
				# A resize updates the eventual default FOV, never the owned shot.
				var shot_fov: float = director.camera.fov
				root.size = Vector2i(960, 540)
				board._fit_backdrop()
				check(director.camera.fov == shot_fov, "Resize cannot fight an active camera tween")
				director.skip()
				check(
					(
						not director.active
						and is_equal_approx(director.camera.fov, director.default_fov)
					),
					"Skip safely restores resized gameplay framing"
				)
			board.free()
			await process_frame
	Preferences.set_skip_cinematics(true)
	var board := fresh()
	await settle_board(board)
	Preferences.set_skip_cinematics(false)
	var stages: Array = []
	board.cinematic_director.stage_changed.connect(func(stage): stages.append(stage))
	var card = load("res://cards/27_missile_barrage.tres")
	board.hand.cards[0] = card
	board.player_crew = 99
	board.enemy_shields = 0
	board.enemy_hull = 3
	board.refresh_display()
	var audit := track_destruction_hud(board)
	board._act("player", 0, false)
	await wait_until(
		func(): return board.result_recorded, "Actual card action reaches confirmed lethal outcome"
	)
	check(
		board.winner == "player" and board.result_recorded,
		"Confirmed lethal outcome commits before cinematic completion"
	)
	check(
		board.cinematic_director.kind == "destruction" and stages.count("beam_charge") == 1,
		"Destruction replaces heavy-beam shot"
	)
	await wait_until(
		func(): return board.destruction_pending, "Existing destruction animation begins"
	)
	await shot_capture(board, "destruction")
	check(
		not board.get_node("MatchResult").visible,
		"Result waits for corresponding destruction presentation"
	)
	await wait_until(
		func(): return not board.destruction_pending and not board._presentation_locked(),
		"Existing destruction VFX and camera complete"
	)
	check(stages.count("beam_turn") == 1 and not "attacker" in stages, "No second cinematic for the same lethal event")
	finish_destruction_hud(audit)
	board.free()
	await process_frame


func skip_beam_checks() -> void:
	for requested in ["beam_charge", "beam_turn", "impact_hold"]:
		Preferences.set_skip_cinematics(true)
		var board := fresh()
		await settle_board(board)
		Preferences.set_skip_cinematics(false)
		var director = board.cinematic_director
		var camera_rest: Transform3D = director.camera.global_transform
		var seen: Array[String] = []
		var beams := [0]
		director.stage_changed.connect(func(stage):
			seen.append(stage)
			if stage == requested: director.skip())
		board.battle_effects.weapon_presented.connect(func(_side, _kind): beams[0] += 1)
		board.hand.cards[0] = load("res://cards/27_missile_barrage.tres")
		board.player_crew = 99
		board.enemy_shields = 0
		board.enemy_hull = 100
		await board._act("player", 0, false)
		board.enemy_timer.stop()
		check(requested in seen and beams[0] == 1 and board.enemy_hull == 84,
			"Skipping %s preserves the single beam and damage commit" % requested)
		check(not board._presentation_locked() and director._charge_glow == null
			and director.camera.global_transform.is_equal_approx(camera_rest), "Skipping restores camera, input and the muzzle effect")
		board.free()
		await process_frame


func _initialize() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	previous_skip = Preferences.skip_cinematics()
	previous_vfx = Preferences.battle_vfx()
	Preferences.set_battle_vfx(true)
	call_deferred("run")


func run() -> void:
	root.size = Vector2i(1280, 720)
	await introduction_checks()
	await input_and_parity_checks()
	await attack_checks()
	await skip_beam_checks()
	await defeat_hud_checks()
	Preferences.set_skip_cinematics(previous_skip)
	Preferences.set_battle_vfx(previous_vfx)
	print("Battle cinematic cameras: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
