extends SceneTree
const Hand = preload("res://scripts/card_hand.gd")
const Effects = preload("res://scripts/card_effects.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var hand = Hand.new()
	hand.tier_two_chance = 1.0
	hand.drop_multiplier = 2.0
	hand.starting_hand.append(load("res://cards/30_siege_driver.tres"))
	for round_number in range(1,3):
		hand.current_round = round_number
		hand.deal(6)
		for attempt in range(30):
			hand.replace_card(attempt % 6)
			for held in hand.cards:
				check(held != null and held.tier == 1, "No Tier 2 through round two, even in fixed hands or Rift")
	hand.current_round = 3
	hand.cards.clear()
	check(hand.draw_card().tier == 2, "Tier 2 unlocks at round three")
	hand.free()
	var cell = load("res://cards/08_energy_cell.tres")
	var actor = {"hull":30,"shields":10,"materials":0,"energy":0,"crew":0,"synthesizer":2,"reactor":2,"quarters":2}
	var target = actor.duplicate()
	check(Effects.play(cell,actor,target), "Energy Cell works without resources")
	check(actor.materials == 1 and actor.energy == 1 and actor.crew == 1 and target.energy == 0, "Free cell grants one of each resource")
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {"modifier":5}
	root.add_child(board)
	board.get_node("BattleEffects").enabled = false
	board.turn_number = 2
	board._begin_turn("enemy")
	board.enemy_timer.stop()
	check(board.hand.current_round == 2 and board.enemy_hand.current_round == 2, "Both ships use full-round count")
	board.turn_number = 3
	board._begin_turn("player")
	check(board.hand.current_round == 3 and board.enemy_hand.current_round == 3, "Both ships unlock together at three")
	board.queue_free()
	await process_frame
	print("Opening balance checks: %d failures" % failures)
	quit(1 if failures else 0)
