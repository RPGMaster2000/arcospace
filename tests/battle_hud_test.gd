extends SceneTree
# Verify the presentation boundary on both scene variants, including terminal results.
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	for scene in ["board", "board_3d"]:
		var board = load("res://scenes/" + scene + ".tscn").instantiate()
		root.add_child(board)
		board.enemy_timer.stop()
		var before: Dictionary = board._both_states()
		var shown: Dictionary = board._display_snapshot()
		shown.player.hull = 7
		check(board.player_hull == before.player.hull, scene + ": snapshot isolates scalar state")
		seed(2701)
		var expected_random: int = randi()
		seed(2701)
		board.hud.refresh(shown)
		check(randi() == expected_random, scene + ": HUD does not consume encounter randomness")
		check(
			board.player_hull_label.text == "Hull 7/%d" % board.player_hull_capacity,
			scene + ": HUD uses the supplied display snapshot"
		)
		check(board._both_states() == before, scene + ": HUD does not mutate combat state")
		check(shown.player.hull == 7, scene + ": HUD does not rewrite its snapshot")
		board.refresh_display()
		for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
			root.size = dimensions
			await process_frame
			board._fit_board_lines()
			var first: Control = board.get_node(board.card_slots[0])
			var last: Control = board.get_node(board.card_slots[-1])
			check(
				(
					first.position.x >= 0
					and last.position.x + last.size.x * last.scale.x <= board.size.x
				),
				scene + ": hand fits after resize"
			)
		board.winner = "player"
		board.enemy_hull = 0
		board.resolving_card = true
		board.refresh_display()
		check(not board.get_node("MatchResult").visible, scene + ": result waits for presentation")
		var salvage: int = board.salvage
		var wins: int = board.battles_won
		var next_modifier: int = board.next_modifier
		for n in range(3):
			board.hud.refresh(board._display_snapshot())
		check(
			board.salvage == salvage and board.battles_won == wins,
			scene + ": repeated rendering cannot duplicate rewards"
		)
		check(
			board.next_modifier == next_modifier,
			scene + ": repeated rendering cannot reroll travel"
		)
		board.resolving_card = false
		board.battle_effects.busy = false
		board.refresh_display()
		check(board.get_node("MatchResult").visible, scene + ": resolved result is revealed")
		check(
			board.get_node("MatchResult/Panel/Continue").visible,
			scene + ": victory continuation remains available"
		)
		board.free()
		await process_frame
	print("Battle HUD: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
