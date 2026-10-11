extends SceneTree
const Drive = preload("res://scripts/ftl_drive.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var drive = Drive.new()
	root.add_child(drive)
	for turn in range(8):
		drive.begin_player_turn()
		check(drive.charge == turn + 1, "Charge once per player turn")
	check(drive.can_warp(), "Ready at eight")
	check(not drive.take_hull_damage(0, 0.0), "Shield-only hits cannot disrupt")
	check(not drive.take_hull_damage(100, 0.2), "20 percent threshold is flat")
	check(drive.take_hull_damage(1, 0.199), "Even one hull damage can disrupt")
	for turn in range(5):
		drive.begin_player_turn()
		check(not drive.can_warp() and drive.charge == 8, "Five full turns blocked, charge retained")
		check(not drive.take_hull_damage(1, 0.0), "Further hits must not extend outage")
	drive.begin_player_turn()
	check(drive.can_warp(), "Ready on sixth turn after outage")
	drive.charge = 3
	drive.take_hull_damage(2, 0.0)
	for turn in range(5):
		drive.begin_player_turn()
		check(drive.charge == 3, "No charging while disabled")
	drive.begin_player_turn()
	check(drive.charge == 4, "Charging resumes")
	drive.queue_free()
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	check(board.ftl.charge == 1, "Opening turn counts")
	board._begin_turn("enemy")
	board.enemy_timer.stop()
	check(board.ftl.charge == 1, "Enemy turn never charges")
	board.ftl.charge = 8
	board._warp_out()
	check(board.winner.is_empty(), "Cannot warp during enemy turn")
	board.current_actor = "player"
	board.resolving_card = true
	board._warp_out()
	check(board.winner.is_empty(), "Cannot warp mid animation")
	board.resolving_card = false
	board._warp_out()
	check(board.winner == "player" and board.get_node("MatchResult").visible, "Manual warp wins")
	check(board.enemy_timer.is_stopped(), "Warp stops AI")
	current_scene = board
	board._restart_match()
	await process_frame
	check(current_scene.ftl.charge == 1 and current_scene.ftl.disabled_turns == 0, "Restart resets FTL")
	current_scene.queue_free()
	await process_frame
	print("FTL checks: %d failures" % failures)
	quit(1 if failures else 0)
