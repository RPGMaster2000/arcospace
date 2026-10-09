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
	var board = BoardScene.instantiate()
	board.get_node("EnemyHand").starting_hand.assign([Library.CARDS[11]])
	root.add_child(board)
	check(board.player_energy == 18 and board.enemy_energy == 16, "Opening income only belongs to player")
	board.hand.cards[0] = Library.CARDS[13]
	board._on_card_pressed(0)
	check(board.current_actor == "player" and board.player_energy == 19, "Player play-again must not grant income")
	board.hand.cards[0] = Library.CARDS[0]
	board._on_card_pressed(0)
	check(board.current_actor == "enemy" and board.enemy_energy == 18, "Normal play must begin enemy turn with income")
	var hand_before: Array = board.hand.cards.duplicate()
	var before: Dictionary = board._read_state("player")
	board._discard_card(0)
	board._on_card_pressed(1)
	check(board.hand.cards == hand_before and board._read_state("player") == before, "Player input must be blocked during AI turn")
	# Force a single legal enemy choice, then let the actual scene Timer fire.
	board.enemy_hand.cards.assign([Library.CARDS[11]])
	board.enemy_timer.start(0.01)
	await create_timer(0.06).timeout
	check(board.current_actor == "player", "Timer must trigger enemy play and return control")
	check(board.player_shields == 8, "Enemy Laser Burst must damage player shields")
	check(board.enemy_energy == 12 and board.player_energy == 21, "AI pays once; next player turn grants income once")
	check(board.enemy_hand.cards.size() == 1, "AI must replace its used card")
	# Enemy extra action stays on the same turn with no repeated income.
	board._begin_turn("enemy")
	board.enemy_timer.stop()
	board.enemy_hand.cards.assign([Library.CARDS[13]])
	var energy: int = board.enemy_energy
	board._on_enemy_timeout()
	check(board.current_actor == "enemy" and board.enemy_energy == energy + 1, "AI play-again must retain control without income")
	check(not board.enemy_timer.is_stopped(), "AI extra action must schedule a new think delay")
	board.enemy_timer.stop()
	# No affordable cards: discard, with refund only, then return control.
	board.enemy_hand.cards.assign([Library.CARDS[19]])
	board.enemy_materials = 0
	board.enemy_energy = 0
	board.enemy_crew = 0
	var player_before: Dictionary = board._read_state("player")
	board.MatchRules.income(player_before)
	board._on_enemy_timeout()
	check(board.current_actor == "player" and board.enemy_crew == 3, "AI must discard when unable to afford any card")
	check(board._read_state("player") == player_before, "AI discard must not execute Torpedo Salvo")
	# Winning piercing attack must beat an otherwise tempting production upgrade.
	board.player_hull = 5
	board.player_shields = 100
	board.enemy_energy = 20
	board.enemy_materials = 20
	board.enemy_hand.cards.assign([Library.CARDS[3], Library.CARDS[20]])
	board._begin_turn("enemy")
	board.enemy_timer.stop()
	board._on_enemy_timeout()
	check(board.winner == "enemy" and board.player_hull == 0, "AI must select a winning piercing attack")
	check(board.enemy_timer.is_stopped(), "Victory must stop AI scheduling")
	check(board.get_node(board.card_slots[0]).get_node("DiscardButton").disabled, "Victory must disable discard")
	board.free()
	# Resource win from discard, and Hull win from repair.
	for mode in ["resource", "hull"]:
		board = BoardScene.instantiate()
		root.add_child(board)
		if mode == "resource":
			board.player_materials = 99
			board.player_energy = 100
			board.player_crew = 100
			board.hand.cards[0] = Library.CARDS[0]
			board._discard_card(0)
		else:
			board.player_hull = 45
			board.hand.cards[0] = Library.CARDS[2]
			board._on_card_pressed(0)
		check(board.winner == "player" and board.enemy_timer.is_stopped(), "Immediate player win: " + mode)
		board.free()
	print("AI turn checks: %d failures" % failures)
	quit(1 if failures else 0)
