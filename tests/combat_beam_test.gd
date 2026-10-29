extends SceneTree
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Execution = preload("res://scripts/combat/combat_execution.gd")
const State = preload("res://scripts/combat/ship_combat_state.gd")
const Card = preload("res://scripts/cards/card_data.gd")
const Lens = preload("res://scripts/presentation/star_system/sun_lens_effects.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func card(effects: Dictionary) -> Resource:
	var value = Card.new()
	value.family = "materials"
	value.effects = effects
	return value

func make_board() -> Node:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	board.modifier.configure(0)
	root.get_node("Music").player.stop()
	root.get_node("Music").player.stream = null
	board.battle_effects.enabled = true
	return board

func initial() -> Dictionary:
	var value = State.new().snapshot()
	value.shields = 40
	for key in State.RESOURCES: value[key] = 100
	return value

func reset(board: Node) -> void:
	board.apply_ship_snapshot("player", initial())
	board.apply_ship_snapshot("enemy", initial())
	board.winner = ""
	board.resolving_card = false
	board.refresh_display()

func finish(board: Node) -> void:
	if board.battle_effects.busy: await board.battle_effects.finished
	await process_frame

func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer is active")
	var existed := FileAccess.file_exists(Preferences.PATH)
	var original := FileAccess.get_file_as_bytes(Preferences.PATH) if existed else PackedByteArray()
	var lens_before: bool = Lens.requested
	check(Preferences.set_battle_vfx(true) == OK, "Enable preference")
	var board = make_board()
	await process_frame
	var direct = card({"damage": 4})
	var conditional = card({"conditional": {"target": "enemy", "attribute": "shields", "comparison": "above", "threshold": 10, "then": {"damage": 5}, "else": {"energy": 1}}})
	var upgraded = load("res://cards/28_breach_charge.tres").with_upgrade(1)
	for side in ["player", "enemy"]:
		for attack in [direct, conditional, upgraded, load("res://cards/16_missile_team.tres")]:
			reset(board)
			var actor := initial()
			var target := initial()
			var expected = Execution.resolve(attack, false, actor, target)
			board._resolve_card(side, 0, false, attack)
			var beam = board.battle_effects.active_beam
			check(is_instance_valid(beam) and not beam.is_queued_for_deletion(), "Resolved opposing damage creates one beam")
			var other: String = "enemy" if side == "player" else "player"
			check(board.ship_snapshot(side) == actor and board.ship_snapshot(other) == target, "VFX leaves resolved state unchanged")
			check(expected.direct_damage > 0, "Actual shield absorption qualifies")
			if is_instance_valid(beam):
				var source_ship = board.get_node(board.battle_effects.player_ship_path if side == "player" else board.battle_effects.enemy_ship_path)
				var target_ship = board.get_node(board.battle_effects.enemy_ship_path if side == "player" else board.battle_effects.player_ship_path)
				var origin: Vector3 = source_ship.get_node("Body/Hull").global_position
				var endpoint: Vector3 = target_ship.get_node("Body/Hull").global_position
				check(beam.global_position.is_equal_approx(origin), "Beam starts on acting ship: " + side)
				var pivot = beam.get_node("BeamPivot")
				var length: float = beam.get_node("BeamPivot/BeamScalor").scale.z
				check((beam.global_position - pivot.global_basis.z * length).distance_to(endpoint) < 0.001, "Beam ends on opposing ship: " + side)
				for particle in beam.find_children("*", "GPUParticles3D", true, false):
					check(not particle.emitting and not particle.visible, "Beam particles disabled")
				for sound in beam.find_children("*", "AudioStreamPlayer3D", true, false):
					check(sound.stream == null, "Vendor audio disabled")
			if DisplayServer.get_name() != "headless" and attack == direct:
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
				root.get_texture().get_image().save_png("res://.godot/testlogs/beam-" + side + "-" + RenderingServer.get_current_rendering_method() + ".png")
			await finish(board)
			check(not is_instance_valid(beam) and board.battle_effects.imported_nodes.is_empty(), "Beam and imported nodes cleaned up")
	for action in [[direct, true], [card({"self_damage": 2}), false], [card({"break_shields": 3}), false], [card({"hull": 2}), false], [card({"energy": 2}), false], [card({"conditional": {"target": "enemy", "attribute": "shields", "comparison": "below", "threshold": 10, "then": {"damage": 5}}}), false]]:
		reset(board)
		board._resolve_card("player", 0, action[1], action[0])
		check(not is_instance_valid(board.battle_effects.active_beam), "Discard/non-damage/false conditional creates no beam")
		await finish(board)
	reset(board)
	board.modifier.configure(4)
	board.modifier.miss_rate = 100.0
	board._resolve_card("player", 0, false, direct)
	check(not is_instance_valid(board.battle_effects.active_beam), "Resolved miss creates no beam")
	await finish(board)
	board.modifier.configure(0)
	reset(board)
	board._resolve_card("player", 0, false, direct)
	var live = board.battle_effects.active_beam
	var jobs: int = board.battle_effects.jobs
	var settings = preload("res://scripts/ui/settings_menu.gd").new()
	board.add_child(settings)
	settings.present()
	check(settings.battle_vfx_toggle.button_pressed, "Settings defaults on and is accessible in battle")
	settings.battle_vfx_toggle.button_pressed = false
	check(not Preferences.battle_vfx() and not live.visible, "Toggle applies immediately even while paused")
	check(board.battle_effects.jobs == jobs, "Toggle preserves running timeline")
	settings.dismiss()
	await finish(board)
	var cfg := ConfigFile.new()
	cfg.load(Preferences.PATH)
	check(cfg.get_value("presentation", "battle_vfx", true) == false, "Preference persisted")
	var normal_settings = preload("res://scripts/ui/settings_menu.gd").new()
	normal_settings.is_main_menu = true
	root.add_child(normal_settings)
	check(not normal_settings.battle_vfx_toggle.button_pressed, "Normal Settings shares persisted battle preference")
	normal_settings.free()
	var second = make_board()
	reset(second)
	second.player_shields = 0
	second.enemy_shields = 0
	second._resolve_card("player", 0, false, direct)
	check(second.battle_effects.imported_nodes.is_empty(), "Subsequent battle suppresses beam and hull impact")
	check(second.enemy_hull == 26, "Disabled VFX preserves damage")
	await finish(second)
	check(Lens.requested == lens_before, "Battle setting does not affect star-map lens")
	Preferences.set_battle_vfx(true)
	reset(second)
	second._resolve_card("enemy", 0, false, direct)
	live = second.battle_effects.active_beam
	second.battle_effects.play_direct_damage("enemy")
	check(second.battle_effects.imported_nodes.size() == 1, "Repeated presentation bounds active beams to one")
	live = second.battle_effects.active_beam
	second.free()
	await process_frame
	check(not is_instance_valid(live), "Scene exit cancels beam")
	board.free()
	root.get_node("Sfx").stop_all()
	await create_timer(0.1).timeout
	if existed:
		var file := FileAccess.open(Preferences.PATH, FileAccess.WRITE)
		file.store_buffer(original)
		file.close()
	else: DirAccess.remove_absolute(Preferences.PATH)
	print("Combat beam: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
