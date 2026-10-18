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
	check(board.repair_preview.bar.preview_hull == 28 and board.repair_preview.cost_text.text.contains("20 → 18"), "Preview links one Hull to two Salvage without spending")
	board._repair_with_salvage()
	check(board.player_hull == 28 and board.salvage == 18 and board.repair_spend == 2, "One selected Hull costs two Salvage; default updates")
	board._repair_with_salvage()
	check(board.player_hull == 30 and board.salvage == 14 and board.repair_spend == 0, "At capacity no further spending")
	board.player_hull_capacity = 35
	board.player_hull = 27
	board.repair_spend = -1
	board.refresh_display()
	check(board.repair_spend == 7, "Fourteen remaining Salvage affords seven Hull")
	board.salvage = 1
	board.refresh_display()
	check(board.repair_spend == 0 and board.get_node("MatchResult/Panel/Repair").disabled, "Odd insufficient Salvage cannot repair")
	board.salvage = 2
	board.repair_spend = -1
	board.refresh_display()
	check(board.repair_spend == 1, "Selection bounded by floor(Salvage / 2)")
	board.player_hull = 43
	board.refresh_display()
	check(board.player_hull_label.text == "Hull 43/35" and board.player_hull_label.get_theme_color("font_color") == board.get_node("PlayerHullBar").plating_color, "Excess shows total Hull in amber")
	check(not board.get_node("PlayerHullBar").has_node("Plating"), "Redundant plating text removed")
	board.player_hull = 35
	board.refresh_display()
	check(board.player_hull_label.get_theme_color("font_color") == Color(0.82,0.84,0.87), "Color resets at capacity")
	for dimensions in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(686,384)]:
		root.size = dimensions
		board.player_hull = 21
		board.salvage = 12
		board.repair_spend = 4
		board.refresh_display()
		for frame in range(10): await process_frame
		check(board.repair_preview.bar.preview_hull == 25 and board.repair_preview.cost_text.text.contains("12 → 4"), "Result preview shows exact Hull/cost at landscape sizes")
		check(not board.repair_preview.get_rect().intersects(board.get_node("MatchResult/Panel/Repair").get_rect()), "Preview avoids confirmation controls")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
			root.get_texture().get_image().save_png("res://.godot/testlogs/result-repair-"+str(dimensions.x)+".png")
	board.queue_free()
	await process_frame
	print("Repair selection checks: %d failures" % failures)
	quit(1 if failures else 0)
