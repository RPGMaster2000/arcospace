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
	board.get_node("CardMotion").settings.enabled = false
	root.add_child(board)
	var display = board.get_node("ModifierDisplay")
	display.warning_seconds = 0.06
	display.result_seconds = 0.06
	display.flash_seconds = 0.08
	for kind in [1, 2, 3]:
		board.modifier.configure(kind)
		board.modifier.next_round = board.turn_number
		var before = board._both_states()
		board._begin_turn("player")
		check(board.resolving_card, "Warning must lock input")
		check(board._both_states() == before, "Warning must precede gameplay effects")
		check(not await board._act("player", 0, true), "Cannot discard during warning")
		await create_timer(0.075).timeout
		check(board.resolving_card and display.get_node("ScreenFlash").modulate.a > 0, "Result flashes while input remains locked")
		await create_timer(0.15).timeout
		check(not board.resolving_card, "Input unlocks after result")
	board.refresh_display()
	var panel = board.get_node("FTLPanel")
	check(panel.position.y < board.get_node("PlayerHullLabel").position.y, "FTL sits above ship status")
	display.ftl_offline()
	check(display.get_node("FTLTint").color.a > 0, "Offline FTL flashes screen")
	var original = root.canvas_transform
	display.impact(1, true)
	await create_timer(0.03).timeout
	check(root.canvas_transform != original, "Player impact shakes entire viewport")
	await create_timer(0.12).timeout
	check(root.canvas_transform == original, "Shake restores exact viewport transform")
	board.modifier.configure(2)
	board.modifier.active = true
	var blue = load("res://scripts/cards/card_data.gd").new()
	blue.family = "energy"
	blue.cost = 0
	blue.effects = {"energy":4}
	board.hand.cards[0] = blue
	board.modifier.ion_factor = 2.0
	board.refresh_display()
	var card_button = board.get_node(board.card_slots[0])
	check(card_button.card_data.description.contains("+8 Energy") and card_button.get_theme_stylebox("normal").shadow_size > 0, "Ion cards preview doubled values with blue glow")
	var energy: int = board.player_energy
	board._act("player", 0, false)
	check(board.resolving_card and board.player_energy == energy, "Ion card warning precedes resolution")
	await create_timer(0.075).timeout
	check(display.get_node("Flash").text.begins_with("ION STORM") and display.get_node("ScreenFlash").color.b == 1.0, "Ion result shows multiplier with blue flash")
	await create_timer(0.15).timeout
	board.enemy_timer.stop()
	board.queue_free()
	await process_frame
	print("Modifier cinematic checks: %d failures" % failures)
	quit(1 if failures else 0)
