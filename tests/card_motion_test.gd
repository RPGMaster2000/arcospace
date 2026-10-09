extends SceneTree
const BoardScene = preload("res://scenes/board.tscn")
const Library = preload("res://scripts/card_library.gd")
var failures: int = 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board = BoardScene.instantiate()
	board.get_node("BattleEffects").enabled = false
	var motion = board.get_node("CardMotion")
	motion.settings.travel_seconds = 0.08
	motion.settings.hold_seconds = 0.12
	motion.settings.exit_seconds = 0.05
	motion.settings.refill_seconds = 0.04
	motion.settings.discard_seconds = 0.08
	root.add_child(board)
	board.enemy_timer.wait_time = 10.0
	board.hand.cards[0] = Library.CARDS[11]
	board.hand.card_pool.assign([Library.CARDS[0], Library.CARDS[1], Library.CARDS[2]])
	board.refresh_display()
	var view = board.get_node(board.card_slots[0])
	board._on_card_pressed(0)
	check(board.resolving_card and view.modulate.a == 0, "Played card must hide and lock immediately")
	check(board.player_energy == 18 and board.enemy_shields == 10, "No resolution before centre arrival")
	var hand_before: Array = board.hand.cards.duplicate()
	board._on_card_pressed(0)
	board._discard_card(1)
	check(board.hand.cards == hand_before, "Repeated play/discard must be blocked during motion")
	await create_timer(0.11).timeout
	check(board.player_energy == 12 and board.enemy_shields == 4, "Arrival must resolve the effect exactly once")
	check(board.resolving_card and board.current_actor == "player" and board.enemy_timer.is_stopped(), "Turn must wait through the centre hold")
	await board.action_finished
	check(not board.resolving_card and board.current_actor == "enemy", "Turn must advance only after exit/refill")
	check(view.modulate.a == 1 and view.card_data == board.hand.cards[0], "Replacement must be visible")
	check(not board.enemy_timer.is_stopped(), "AI delay must begin after animation")
	board.enemy_timer.stop()
	# Enemy card presentation uses the same queue and does not touch the player hand.
	board.enemy_hand.cards.assign([Library.CARDS[11]])
	hand_before = board.hand.cards.duplicate()
	board._on_enemy_timeout()
	check(board.resolving_card and board.player_shields == 10, "Enemy effect must wait for its animation")
	await board.action_finished
	check(board.current_actor == "player" and board.player_shields == 4, "Enemy animation must resolve then return control")
	check(board.hand.cards == hand_before, "Enemy animation must not alter player slots")
	# Discard resolves after its scanner completes, then fades the replacement in.
	board.hand.cards[0] = Library.CARDS[19]
	board.player_crew = 0
	board.refresh_display()
	board._discard_card(0)
	check(board.resolving_card and board.player_crew == 0, "Discard refund must wait for dissolve")
	check(motion.get_node("Scanner").visible, "Discard must show its scanner")
	await board.action_finished
	check(board.player_crew == 3 and not motion.get_node("Scanner").visible, "Discard must refund once and hide scanner")
	check(view.modulate.a == 1, "Discard replacement must be restored")
	board.enemy_timer.stop()
	# Animate an AI discard too; this has no source hand slot.
	board.enemy_hand.cards.assign([Library.CARDS[19]])
	board.enemy_crew = 0
	board.enemy_energy = 0
	board.enemy_materials = 0
	board._on_enemy_timeout()
	await board.action_finished
	check(board.current_actor == "player" and board.enemy_crew == 3, "AI discard must finish and return control")
	# Winning motion must finish its cleanup without scheduling another AI turn.
	board.hand.cards[0] = Library.CARDS[20]
	board.player_energy = 20
	board.enemy_hull = 5
	board.enemy_shields = 100
	board._on_card_pressed(0)
	await board.action_finished
	check(board.winner == "player" and board.enemy_timer.is_stopped(), "Winning animation must not schedule another turn")
	check(not board.resolving_card and view.modulate.a == 1, "Winning animation must clean up")
	await process_frame
	check(motion.get_child_count() == 4, "Temporary animation nodes must be removed")
	board.free()
	# Closing/restarting during motion must safely destroy its running tween.
	board = BoardScene.instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.hand.cards[0] = Library.CARDS[11]
	board._on_card_pressed(0)
	board.queue_free()
	await process_frame
	await process_frame
	print("Card motion checks: %d failures" % failures)
	quit(1 if failures else 0)
