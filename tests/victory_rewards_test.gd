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
	check(board.starting_player_hull == 30, "Initial hull snapshotted before combat")
	board.player_hull = 30
	board.winner = "player"
	check(not board.tactical_victory() and not board.strategic_victory(), "Ties never earn bonuses")
	board.winner = ""
	var warhead = load("res://cards/42_overloaded_warhead.tres")
	board._resolve_card("player",0,false,warhead)
	check(board.player_hull_damage_taken == 4, "Self damage counts as real hull loss")
	board.player_hull = 40
	board.player_reactor = 3
	board.turn_number = 7
	board.escaped_by_ftl = true
	board.winner = "player"
	board.refresh_display()
	check(board.tactical_victory() and board.strategic_victory(), "FTL earns both rewards with qualifying state")
	check(board.get_node("MatchResult/Panel/Details").text.contains("7 turns") and board.get_node("MatchResult/Panel/Details").text.contains("damage taken: 4"), "Details retain damage despite healing")
	board._continue_encounter()
	await process_frame
	board = current_scene
	check(board.player_hull == 35 and board.starting_player_hull == 35, "Carried hull becomes new baseline")
	check(board.player_materials == 23 and board.player_energy == 23 and board.player_crew == 23, "Tactical adds five each before normal income")
	check(board.player_shields == 20, "Strategic adds ten reset shields")
	check(board.player_hull_damage_taken == 0, "Damage resets per encounter")
	if board.battle_effects.busy:
		await board.battle_effects.finished
	await process_frame
	board.get_node("BattleEffects").enabled = false
	board.winner = "player"
	board.refresh_display()
	check(not board.tactical_victory() and not board.strategic_victory(), "Bonuses require fresh qualification")
	board._continue_encounter()
	await process_frame
	board = current_scene
	check(board.player_shields == 10 and board.player_materials == 18, "Rewards do not stack permanently into setup")
	board.queue_free()
	await process_frame
	print("Victory reward checks: %d failures" % failures)
	quit(1 if failures else 0)
