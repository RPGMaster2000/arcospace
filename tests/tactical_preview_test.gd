extends SceneTree
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func pointer(point: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.pressed = pressed
	event.button_index = button
	root.push_input(event, true)
func wait_motion() -> void: await create_timer(0.4).timeout
func run() -> void:
	for dimensions in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = dimensions
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {"player_ship":0, "enemy_ship":0, "modifier":0}
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		board.get_node("ModifierDisplay").cinematic_enabled = false
		await process_frame
		var preview = board.hud.tactical
		var card = board.get_node(board.card_slots[0])
		var other = board.get_node(board.card_slots[1])
		var origin: Vector2 = card.position
		var neighbor: Vector2 = other.position
		var state: String = str(board._both_states())
		var rng_state: int = board.modifier.rng.state
		var point: Vector2 = card.get_global_rect().get_center()
		pointer(point, true)
		await create_timer(0.55).timeout
		pointer(point, false)
		await wait_motion()
		check(preview.source == card, "Hold persists after release")
		check(is_equal_approx(origin.y - card.position.y, card.size.y * card.scale.y * 0.3), "Raises by displayed card height")
		check(other.position == neighbor and card.z_index > other.z_index, "Neighbors stay still; selected card draws above them")
		check(str(board._both_states()) == state and board.modifier.rng.state == rng_state, "Hold/release changes neither state nor RNG")
		check(preview.inspect.visible and root.get_visible_rect().encloses(preview.inspect.get_global_rect()), "Inspect touch target fits viewport")
		preview.open_inspection()
		await wait_motion()
		var full = root.get_node("CardInspection")
		check(full.is_open() and full.current_card == card.card_data, "Reuses full card inspector")
		full.dismiss(true)
		await wait_motion()
		check(preview.source == card and preview.inspect.visible, "Inspection returns to preview")
		point = other.get_global_rect().get_center()
		pointer(point, true)
		await create_timer(0.55).timeout
		pointer(point, false)
		await wait_motion()
		check(preview.source == other and card.position == origin, "Another hold switches directly and lowers previous card")
		pointer(Vector2(640, 30), true)
		pointer(Vector2(640, 30), false)
		await wait_motion()
		check(preview.source == null and str(board._both_states()) == state, "Outside tap dismisses without action")
		other.hold_input._hold()
		board.current_actor = "enemy"
		board.refresh_display()
		await wait_motion()
		check(preview.source == null, "Turn change cancels preview")
		board.queue_free()
		await process_frame
	print("Tactical preview: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
