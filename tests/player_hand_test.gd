extends SceneTree

# Run: godot --headless --path . --script res://tests/player_hand_test.gd
const Library = preload("res://scripts/card_library.gd")
const BoardScene = preload("res://scenes/board.tscn")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board = BoardScene.instantiate()
	var hand = board.get_node("CardHand")
	hand.starting_hand.assign([Library.CARDS[11], Library.CARDS[0], Library.CARDS[3],
		Library.CARDS[7], Library.CARDS[17], Library.CARDS[19]])
	# A controlled pool makes the Laser Burst replacement unambiguous.
	hand.card_pool.assign([Library.CARDS[0], Library.CARDS[1], Library.CARDS[2]])
	root.add_child(board)
	check(hand.cards.size() == 6, "Opening hand must have six cards")
	var previous: Array = hand.cards.duplicate()
	board.get_node(board.card_slots[0]).pressed.emit()
	check(board.player_energy == 12, "Laser must cost six after opening income")
	check(board.enemy_shields == 4 and board.enemy_hull == 30, "Laser must resolve before replacement")
	check(hand.cards[0] != previous[0], "Played card must be replaced from the configured pool")
	for slot in range(1, 6):
		check(hand.cards[slot] == previous[slot], "Other slots must remain unchanged")
	check(board.get_node(board.card_slots[0]).card_data == hand.cards[0], "View must show replacement")
	# Isolate subsequent player-input checks from the pending AI action.
	board.enemy_timer.stop()
	board.current_actor = "player"
	board.player_materials = 0
	board.refresh_display()
	previous = hand.cards.duplicate()
	var shields: int = board.player_shields
	board._on_card_pressed(1)
	check(hand.cards == previous and board.player_shields == shields, "Unaffordable play must not draw or resolve")
	check(board.get_node(board.card_slots[1]).disabled, "Unaffordable card must be disabled")
	# Random opening hands and repeated replacement enforce the two-copy rule.
	hand.card_pool.clear()
	hand.starting_hand.clear()
	hand.rng.seed = 12345
	for game in range(30):
		hand.deal(6)
		for step in range(100):
			hand.replace_card(step % 6)
			check(hand.cards.size() == 6, "Replacement must preserve hand size")
			for card in hand.cards:
				check(card != null and hand.cards.count(card) <= 2, "No more than two copies")
	# Energy Surge retains its metadata, pays 4 and grants 5 only.
	hand.cards[0] = Library.CARDS[13]
	board.player_energy = 16
	board._on_card_pressed(0)
	check(board.player_energy == 17 and board.extra_action_requested, "Play-again must not grant income")
	# Card resource edits propagate to the scene preview/view.
	var view = board.get_node(board.card_slots[0])
	var editable: Resource = Library.CARDS[0].duplicate(true)
	view.card_data = editable
	editable.card_name = "Preview test"
	check(view.get_node("TitleLabel").text == "PREVIEW TEST", "Resource edits must update card labels")
	board.enemy_hull = 0
	previous = hand.cards.duplicate()
	board._on_card_pressed(0)
	check(hand.cards == previous, "Defeated enemy must block further plays")
	board.free()
	print("Player hand checks: %d failures" % failures)
	quit(1 if failures else 0)
