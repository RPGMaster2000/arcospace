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
	check(not board.victory_description().contains("Tactical") and not board.victory_description().contains("Strategic"), "Unearned bonuses omitted")
	board.player_hull += 1
	check(board.victory_description().contains("Tactical") and not board.victory_description().contains("Strategic"), "Only tactical shown when earned")
	board.player_hull -= 1
	board.player_reactor += 1
	check(not board.victory_description().contains("Tactical") and board.victory_description().contains("Strategic"), "Only strategic shown when earned")
	board.player_reactor -= 1
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
	check(board.get_node("MatchResult/Panel/Details").text.contains("Turn 7") and board.get_node("MatchResult/Panel/Details").text.contains("Damage taken: 4"), "Compact details retain damage despite healing")
	check(board.victory_description().contains("Tactical") and board.victory_description().contains("Strategic") and board.victory_description().split("\n").size() == 3, "Both earned bonuses fit three concise lines")
	board._continue_encounter()
	await process_frame
	board = current_scene
	check(board.player_hull == 30 and board.starting_player_hull == 30, "Carried hull becomes new baseline")
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
	if board.battle_effects.busy: await board.battle_effects.finished
	board.get_node("BattleEffects").enabled = false
	var expedition = preload("res://scripts/expedition_state.gd").new()
	expedition.start(0, preload("res://encounters/expedition_rules.tres"), 4201)
	expedition.encounters[0] = {"kind":"battle","enemy":0,"enemy_data":load("res://ships/enemy/marauder_vanguard.tres"),"completed":false}
	expedition.active_battle = 0
	board.expedition = expedition
	board.winner = "player"
	board.enemy_hull = 0
	board.result_recorded = true
	board.result_hull = board.player_hull
	board.earned_tactical = true
	board.earned_strategic = true
	var description: String = board.victory_description()
	check(description.contains("+40 Salvage") and description.contains("Elite:") and description.contains("Tactical:") and description.contains("Strategic:"), "Compact expedition summary keeps all earned rewards")
	check(description.split("\n").size() == 5 and not description.contains("Not earned"), "Maximum reward summary fits five lines")
	var bonuses_before: Dictionary = expedition.pending_bonuses.duplicate()
	board.refresh_display()
	check(expedition.pending_bonuses == bonuses_before, "Rendering summary does not grant rewards")
	check(not board.get_node("MatchResult/Panel/NextEncounter").visible, "Star System button needs no repeated instructions")
	check(not board.get_node("MatchResult/Panel/PlayAgain").visible and board.get_node("MatchResult/Panel/Configure").text == "Select Ship", "Victory has one Select Ship destination")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/compact-victory.png")
	board.winner = "enemy"
	check(board.victory_description().is_empty(), "Defeat has no unearned bonus list")
	board.queue_free()
	await process_frame
	print("Victory reward checks: %d failures" % failures)
	quit(1 if failures else 0)

