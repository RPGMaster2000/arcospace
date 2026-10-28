extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.player_hull = 27
	board.salvage = 20
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	for name in ["Repair", "RepairMinus", "RepairPlus", "RepairAmount", "RepairPreview"]:
		check(board.get_node_or_null("MatchResult/Panel/" + name) == null, "Victory screen has no repair control: " + name)
	check(board.player_hull == 27 and board.salvage == 30, "Victory preserves damaged Hull and destruction Salvage")
	check(board.get_node("MatchResult/Panel/Continue").visible or board.get_node("MatchResult/Panel/NextEncounter").visible, "Victory continuation remains available")
	board.queue_free()
	await process_frame
	print("Victory repair removal: %d failures" % failures)
	quit(1 if failures else 0)
