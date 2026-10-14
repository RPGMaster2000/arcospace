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
	board.player_hull = 27
	board.salvage = 20
	board.winner = "player"
	board.refresh_display()
	check(board.repair_spend == 3, "Default fills missing hull with capacity thirty")
	board._adjust_repair_spend(10)
	check(board.repair_spend == 3, "Cannot overspend missing hull")
	board._adjust_repair_spend(-2)
	check(board.repair_spend == 1, "Minus selects smaller repair")
	board._repair_with_salvage()
	check(board.player_hull == 28 and board.salvage == 19 and board.repair_spend == 2, "Only selected salvage spent; default updates")
	board._repair_with_salvage()
	check(board.player_hull == 30 and board.salvage == 17 and board.repair_spend == 0, "At capacity no further spending")
	board.player_hull_capacity = 35
	board.player_hull = 27
	board.repair_spend = -1
	board.refresh_display()
	check(board.repair_spend == 8, "Original twenty salvage / twenty-seven hull example at thirty-five capacity")
	board.salvage = 2
	board.refresh_display()
	check(board.repair_spend == 2, "Selection bounded by available salvage")
	board.player_hull = 43
	board.refresh_display()
	check(board.player_hull_label.text == "Hull 43/35" and board.player_hull_label.get_theme_color("font_color") == board.get_node("PlayerHullBar").plating_color, "Excess shows total Hull in amber")
	check(not board.get_node("PlayerHullBar").has_node("Plating"), "Redundant plating text removed")
	board.player_hull = 35
	board.refresh_display()
	check(board.player_hull_label.get_theme_color("font_color") == Color.WHITE, "Color resets at capacity")
	board.queue_free()
	await process_frame
	print("Repair selection checks: %d failures" % failures)
	quit(1 if failures else 0)
