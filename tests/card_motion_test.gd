extends SceneTree
const BoardScene = preload("res://scenes/board.tscn")
const Library = preload("res://scripts/cards/card_library.gd")
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
	check(board.player_energy == 18 and board.enemy_shields == 10, "No resolution before activation")
	var hand_before: Array = board.hand.cards.duplicate()
	board._on_card_pressed(0)
	board._discard_card(1)
	check(board.hand.cards == hand_before, "Repeated play/discard must be blocked during motion")
	# Wait for actual arrival instead of assuming the runner sustains a frame rate.
	await motion.step_finished
	await process_frame
	check(board.resolving_card and board.current_actor == "player", "Activation remains locked after completed card lift")
	check(board.resolving_card and board.current_actor == "player" and board.enemy_timer.is_stopped(), "Turn must wait through activation and impact")
	await board.action_finished
	check(not board.resolving_card and board.current_actor == "enemy" and board.player_energy == 12 and board.enemy_shields == 4, "Damage resolves once at impact before next turn")
	check(view.modulate.a == 1 and view.card_data == board.hand.cards[0], "Replacement must be visible")
	check(not board.enemy_timer.is_stopped(), "AI delay must begin after animation")
	board.enemy_timer.stop()
	# Enemy card presentation uses the same queue and does not touch the player hand.
	board.enemy_hand.cards.assign([Library.CARDS[11]])
	hand_before = board.hand.cards.duplicate()
	board._on_enemy_timeout()
	var enemy_cue: Control = motion.get_child(motion.get_child_count() - 1) as Control
	# Earlier visual-only cards may still exist; the newest child is the current cue.
	check(enemy_cue.position.x > motion.size.x * 0.49 and enemy_cue.position.x < motion.size.x * 0.54 and enemy_cue.position.y >= 150.0, "Enemy card activates in open space below title and left of resources")
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
	# Consecutive player plays share the visual lane without delaying the next action.
	var round_before: int = board.turn_number
	board.hand.cards[0] = preload("res://cards/14_energy_surge.tres")
	board.refresh_display()
	board._on_card_pressed(0)
	await board.action_finished
	check(board.current_actor == "player" and board.turn_number == round_before,
		"Play Again preserves the active player and round while visual cards linger")
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
	# Played-card visuals have independent lifetimes: enemy 1.8s and player 0.48s,
	# followed by a 0.28s directional fade. Allow for the last cue to finish.
	await create_timer(2.3).timeout
	check(motion.get_child_count() == 4, "Temporary animation nodes must be removed after their visual hold")
	board.free()
	await center_path_checks()
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


func center_path_checks() -> void:
	var layout := preload("res://scripts/ui/battle_layout.gd")
	for viewport in [Vector2i(1280, 720), Vector2i(1680, 720), Vector2i(686, 384)]:
		root.size = viewport
		var board := BoardScene.instantiate()
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		await process_frame
		if viewport.x == 686:
			var safe := layout.safe_bounds(board.size, Vector4(64, 14, 12, 24))
			board.hud.fit_combat_controls(safe)
			layout.fit(board, board.settings_button, board.allocation_button, safe)
		var motion: Control = board.get_node("CardMotion")
		var tiles: Array[Rect2] = []
		for path in ["PlayerHullLabel", "PlayerShieldsLabel", "EnemyHullLabel", "EnemyShieldsLabel"]:
			tiles.append(board.get_node(path).get_global_rect())
		for slot in 6:
			var source: Control = board.get_node(board.card_slots[slot])
			var cues := [0]
			var enemy_visual: Control
			var enemy_tail: Tween
			if slot == 0:
				motion.animate_action(Library.CARDS[11], null, "enemy", false, func(): pass)
				enemy_visual = motion.get_child(motion.get_child_count() - 1)
				motion.active_tween.custom_step(1.0)
				enemy_tail = motion.lingering_tweens[enemy_visual]
			motion.animate_action(Library.CARDS[11], source, "player", false, func(): cues[0] += 1)
			var visual: Control = motion.get_child(motion.get_child_count() - 1)
			check(visual.global_position.is_equal_approx(source.global_position) and visual.scale == source.scale,
				"Activation starts at the real hand slot and scale")
			if slot == 0:
				var handoff: Tween = motion.lingering_tweens[enemy_visual]
				check(not enemy_tail.is_valid() and handoff != enemy_tail, "Player play interrupts the decorative enemy tail")
				handoff.custom_step(motion.settings.travel_seconds * 0.2)
				check(enemy_visual.modulate.a > 0.0 and enemy_visual.modulate.a < 1.0,
					"The enemy card fades as the player starts moving")
				handoff.custom_step(1.0)
				check(not motion.lingering_cards.has(enemy_visual), "Enemy card is cleared before centered resolution")
			var tween: Tween = motion.active_tween
			tween.pause()
			var step: float = motion.settings.travel_seconds / 60.0
			for sample in 60:
				tween.custom_step(step)
				if sample == 9:
					check(visual.position.x != source.position.x and visual.position.y < source.position.y,
						"The slide and lift overlap during the same animation")
				check_clear(visual, tiles)
			if tween.is_valid(): tween.custom_step(step)
			check(is_equal_approx(visual.get_global_rect().get_center().x, board.size.x * 0.5)
				and is_equal_approx(visual.position.y, source.position.y - source.size.y * source.scale.y * 0.20)
				and cues[0] == 1, "The card resolves once at the exact center with its 20 percent lift")
			var lift_y := visual.position.y
			var departure: Tween = motion.lingering_tweens[visual]
			departure.pause()
			departure.custom_step(0.48)
			check(is_equal_approx(visual.position.y, lift_y) and visual.modulate.a == 1.0,
				"The usual hold precedes the exit")
			for sample in 20:
				departure.custom_step(0.014)
				check_clear(visual, tiles)
				check(is_equal_approx(visual.get_global_rect().get_center().x, board.size.x * 0.5),
					"The exit remains centered throughout the fade")
			motion.active_tween.custom_step(1.0)
			motion.clear_lingering_cards()
			await process_frame
		board.free()
		await process_frame


func check_clear(visual: Control, tiles: Array[Rect2]) -> void:
	for tile in tiles:
		check(not tile.intersects(visual.get_global_rect()), "Card path clears Hull and Shields")
