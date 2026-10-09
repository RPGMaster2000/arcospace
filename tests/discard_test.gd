extends SceneTree
const Library = preload("res://scripts/card_library.gd")
const BoardScene = preload("res://scenes/board.tscn")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var board = BoardScene.instantiate()
	root.add_child(board)
	var hand = board.get_node("CardHand")
	for card in Library.CARDS:
		board.current_actor = "player"
		hand.cards[0] = card
		board.player_materials = 0
		board.player_energy = 0
		board.player_crew = 0
		var before: Dictionary = board._read_state("player")
		var enemy_before: Dictionary = board._read_state("enemy")
		board.MatchRules.income(enemy_before)
		var previous: Array = hand.cards.duplicate()
		before[card.family] += int(floor(card.cost / 3.0))
		board.extra_action_requested = true
		board._discard_card(0)
		check(board._read_state("player") == before, "Incorrect refund or unwanted effect: " + card.card_name)
		check(board._read_state("enemy") == enemy_before, "Only next-turn income may affect enemy")
		check(not board.extra_action_requested, "Discard must not grant play-again")
		check(hand.cards.size() == 6 and hand.cards[0] != null, "Discard must refill slot")
		for slot in range(1, 6):
			check(hand.cards[slot] == previous[slot], "Discard changed another slot")
		for held in hand.cards:
			check(hand.cards.count(held) <= 2, "Discard broke copy limit")
	board.enemy_timer.stop()
	board.current_actor = "player"
	# Real GUI right-click on an unaffordable, disabled Button.
	hand.cards[0] = Library.CARDS[19] # Cost 10 Crew -> refund 3.
	hand.card_pool.assign([Library.CARDS[0], Library.CARDS[1], Library.CARDS[2]])
	board.player_crew = 0
	board.refresh_display()
	var button = board.get_node(board.card_slots[0])
	check(button.disabled, "Setup must use an unaffordable button")
	await process_frame
	await process_frame
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	root.push_input(event, true)
	check(board.player_crew == 3 and hand.cards[0] != Library.CARDS[19], "Right-click must discard unaffordable card")
	event.pressed = false
	root.push_input(event, true)
	check(board.player_crew == 3, "Mouse release must not discard twice")
	board.enemy_timer.stop()
	board.current_actor = "player"
	# Click the actual footer on an unaffordable card; the parent must not play.
	hand.cards[0] = Library.CARDS[13] # Energy Surge: no effect, refund 1.
	board.player_energy = 0
	board.refresh_display()
	var footer = button.get_node("DiscardButton")
	check(button.disabled and not footer.disabled, "Unaffordable play must still allow footer discard")
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = footer.get_global_rect().get_center()
	event.global_position = event.position
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	check(board.player_energy == 1, "Footer must refund only, without playing the card")
	check(footer.text.begins_with("Discard +"), "Footer must show the replacement refund")
	board.enemy_hull = 0
	var stopped: Array = hand.cards.duplicate()
	var stopped_state: Dictionary = board._read_state("player")
	board._discard_card(0)
	check(hand.cards == stopped and board._read_state("player") == stopped_state, "No discard after Hull reaches zero")
	board.free()
	print("Discard checks: %d failures" % failures)
	quit(1 if failures else 0)
