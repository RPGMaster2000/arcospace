extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	current_scene = board
	board.player_hull = 29
	board.enemy_hull = 0
	board._check_winner()
	for repeat in range(5): board.refresh_display()
	check(board.salvage == 10 and board.battles_won == 1, "Destruction counted and awarded once")
	check(board.get_node_or_null("MatchResult/Panel/Repair") == null and board.player_hull == 29 and board.salvage == 10, "Victory has no repair option or automatic spending")
	check(not board.tactical_victory(), "Combat loss of Hull remains relevant to tactical victory")
	board._continue_encounter()
	await process_frame
	board = current_scene
	if board.battle_effects.busy: await board.battle_effects.finished
	await process_frame
	board.battle_effects.enabled = false
	check(board.player_hull == 29 and board.battles_won == 1, "Hull and victories persist")
	board.salvage = 7
	board.ftl.charge = board.ftl.charge_target
	board._warp_out()
	board.refresh_display()
	check(board.salvage == 7 and board.battles_won == 2, "FTL counts victory without salvage award")
	board._continue_encounter()
	await process_frame
	board = current_scene
	if board.battle_effects.busy: await board.battle_effects.finished
	await process_frame
	board.battle_effects.enabled = false
	check(board.salvage == 7 and board.battles_won == 2, "Unspent salvage persists")
	board.player_hull = 0
	board._check_winner()
	board.refresh_display()
	check(board.get_node("MatchResult/Panel/BattlesWon").visible and board.get_node("MatchResult/Panel/BattlesWon").text == "2 BATTLES WON", "Defeat presents run victories")
	board._restart_match()
	await process_frame
	board = current_scene
	check(board.salvage == 0 and board.battles_won == 0, "Restart clears run currency and victories")
	board.queue_free()
	await process_frame
	print("Salvage checks: %d failures" % failures)
	quit(1 if failures else 0)
