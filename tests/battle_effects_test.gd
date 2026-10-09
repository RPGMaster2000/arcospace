extends SceneTree
const BoardScene = preload("res://scenes/board.tscn")
const Library = preload("res://scripts/card_library.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var board = BoardScene.instantiate()
	board.get_node("CardMotion").settings.enabled = false
	root.add_child(board)
	var fx = board.get_node("BattleEffects")
	board.enemy_timer.wait_time = 10
	if fx.busy:
		await fx.finished
	await process_frame
	# Every intermediate number must be visible, and refresh must not jump ahead.
	board.player_materials = 12
	var before: Dictionary = board._both_states()
	board.player_materials = 16
	fx.play_changes(before, board._both_states())
	board.refresh_display()
	check(board.player_materials_label.text == "12", "Counter must begin at the old value")
	var observed: Array[String] = []
	while fx.busy:
		var value: String = board.player_materials_label.text
		if not observed.has(value):
			observed.append(value)
		board.refresh_display()
		await process_frame
	observed.append(board.player_materials_label.text)
	for value in ["12", "13", "14", "15", "16"]:
		check(observed.has(value), "Missing resource count step " + value)
	# Damage absorbed by shields: front hit/pulse, no red hull flash.
	var ship = board.get_node("EnemyShip")
	var hull = ship.get_node("HullPlaceholder")
	var color: Color = hull.color
	var origin: Vector2 = ship.position
	before = board._both_states()
	board.enemy_shields -= 3
	fx.play_changes(before, board._both_states(), "", "", 0, true)
	await create_timer(0.1).timeout
	check(hull.color == color, "Shield-only damage must not flash hull red")
	check(not fx.temporary_nodes.is_empty(), "Shield hit must create a frontal arc")
	await fx.finished
	check(ship.position == origin and ship.get_node("ShieldPlaceholder").scale == Vector2.ONE, "Hit must restore transforms")
	# Hull damage: one red flash and shake, restored afterward.
	before = board._both_states()
	board.enemy_hull -= 2
	fx.play_changes(before, board._both_states(), "", "", 0, true)
	await create_timer(0.1).timeout
	check(hull.color != color, "Hull damage must flash red")
	await fx.finished
	check(hull.color == color and ship.position == origin, "Hull flash/shake must restore")
	# Repair and shield gain create shader overlays that clean up afterward.
	before = board._both_states()
	board.player_hull += 3
	board.player_shields += 4
	fx.play_changes(before, board._both_states())
	check(fx.temporary_nodes.size() == 2, "Repair and shield gain need separate overlays")
	await fx.finished
	check(fx.temporary_nodes.is_empty(), "Shader overlays must be removed")
	# Production growth and hostile draining restore icon scale and pivot.
	var icon = board.get_node("PlayerResource1")
	var pivot: Vector2 = icon.pivot_offset
	before = board._both_states()
	board.player_synthesizer += 1
	fx.play_changes(before, board._both_states())
	await create_timer(0.07).timeout
	check(icon.scale.x > 1, "Production increase should subtly expand")
	await fx.finished
	check(icon.scale == Vector2.ONE and icon.pivot_offset == pivot, "Production pulse must restore")
	before = board._both_states()
	board.player_materials -= 4
	fx.play_changes(before, board._both_states())
	await create_timer(0.07).timeout
	check(icon.scale.x < 1, "Drain should subtly contract")
	await fx.finished
	check(board.player_materials_label.text == str(board.player_materials), "Drain must count down to actual value")
	# Card resolution waits for a slower repair before advancing to the AI.
	board.hand.cards[0] = Library.CARDS[2]
	board._on_card_pressed(0)
	check(board.resolving_card and board.current_actor == "player" and board.enemy_timer.is_stopped(), "Turn must wait for stat effects")
	await board.action_finished
	check(board.current_actor == "enemy" and not board.resolving_card and not fx.busy, "Effects must finish before next AI action")
	board.queue_free()
	await process_frame
	# Cancel while the initial resource count is waiting.
	board = BoardScene.instantiate()
	root.add_child(board)
	board.queue_free()
	await process_frame
	await process_frame
	print("Battle effect checks: %d failures" % failures)
	quit(1 if failures else 0)
