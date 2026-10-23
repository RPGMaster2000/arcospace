extends SceneTree
const Scene = preload("res://scenes/board_3d.tscn")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var board = Scene.instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	current_scene = board
	var ship = board.get_node("BattleView/Viewport/Battlefield/PlayerShip")
	for hull in [15, 14, 5, 4, 20]:
		board.player_hull = hull
		board._record_result()
		board.refresh_display()
		var expected: float = 0.0 if hull >= 15 else (1.0 if hull < 5 else 0.45)
		check(is_equal_approx(ship.damage_material.get_shader_parameter("damage"), expected), "Hull threshold or repair restoration failed")
	var start: Vector3 = ship.position
	await create_timer(0.12).timeout
	check(ship.position != start, "Hover should move the ship")
	board.battle_effects.enabled = true
	var before = board._both_states()
	board.player_shields += 2
	board.player_materials += 2
	board.player_reactor += 1
	board.battle_effects.play_changes(before, board._both_states())
	board._record_result()
	board.refresh_display()
	await create_timer(0.1).timeout
	check(ship.shield_material.get_shader_parameter("keep_shell"), "Online shield gain must retain the bubble")
	check(board.battle_effects.temporary_nodes.size() == 2, "Resource and production gains need separate bursts")
	await board.battle_effects.finished
	check(board.battle_effects.temporary_nodes.is_empty(), "Bursts must clean up")
	board.battle_effects.enabled = false
	for result in ["player", "enemy"]:
		board.winner = ""
		board.player_hull = 30 if result == "player" else 0
		board.enemy_hull = 0 if result == "player" else 30
		check(board._check_winner() and board.winner == result, "Hull destruction must select the correct winner")
		board._record_result()
		board.refresh_display()
		check(board.get_node("MatchResult").visible, "Match result should be visible")
		check(not board._act("player", 0, false), "Finished match must block cards")
	board.get_node("MatchResult/Panel/Configure").pressed.emit()
	await process_frame
	var fresh = current_scene
	check(fresh.scene_file_path.ends_with("battle_setup.tscn"), "Select Ship returns to initial selection")
	check(fresh.get("state") == null, "Selecting a ship is required before a new expedition")
	fresh.showcase.skip_cinematics = true
	fresh.showcase._stop_tween()
	fresh.showcase._finish_intro()
	fresh.showcase.logo.modulate.a = 0.0
	fresh.showcase.phase = fresh.showcase.Phase.SHIP_SELECTION
	fresh._selection_ready()
	fresh.white_fade_duration = 0.001
	fresh.map_reveal_duration = 0.001
	fresh._start()
	for frame in range(8): await process_frame
	fresh = current_scene
	check(fresh.state != null and fresh.state.hull == fresh.state.ship().hull_capacity, "Confirming ship starts a fresh expedition")
	fresh.queue_free()
	await process_frame
	print("Status presentation checks: %d failures" % failures)
	quit(1 if failures else 0)

