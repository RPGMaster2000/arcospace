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
	hand.rng.seed = 12345
	for multiplier in [1.0, 2.0]:
		hand.drop_multiplier = multiplier
		var count: int = 0
		for draw in range(20000):
			if hand.draw_card().tier == 2:
				count += 1
		check(absf(count / 20000.0 - 0.15 * multiplier) < 0.015, "Tier 2 rate matches configured chance")
		hand.tier_two_chance = 1.0
		for attempt in range(100):
			hand.deal(6)
			for slot in range(6):
				hand.replace_card(slot)
				var uncommon: int = 0
				for card in hand.cards:
					if card.tier == 2: uncommon += 1
				check(uncommon <= 1, "Replacement never exceeds one Tier 2 per hand")
		hand.cards.clear()
		hand.tier_two_chance = 0.15
	var counts = {"materials":0, "energy":0, "crew":0}
	for card in hand.CardLibrary.CARDS:
		if card.tier != 2: continue
		counts[card.family] += 1
		var actor = {"hull":30,"shields":10,"materials":100,"energy":100,"crew":100,"synthesizer":3,"reactor":3,"quarters":3}
		var target = actor.duplicate()
		Effects.play(card, actor, target)
		check(target.hull < 30 or actor.hull > 30 or actor.shields > 10 or actor.materials > 100 or actor.energy > 100 or actor.crew > 100, "Tier 2 actually damages or restores")
	check(counts == {"materials":2,"energy":3,"crew":3}, "Eight Tier 2 cards including new Crew and Energy cards")
	hand.free()
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {"modifier":5}
	root.add_child(board)
	check(board.hand.drop_multiplier == 2 and board.enemy_hand.drop_multiplier == 2, "Rift applies to both hands before dealing")
	check(board.get_node("BattleView/Viewport/Battlefield").scene_file_path.ends_with("battlefield_temporal_rift.tscn"), "Rift uses independent arena")
	board.queue_free()
	await process_frame
	print("Card tier checks: %d failures" % failures)
	quit(1 if failures else 0)
