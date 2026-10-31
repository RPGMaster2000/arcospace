extends SceneTree
var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var guide = preload("res://scripts/ui/game_reference.gd")
	var chapters: Dictionary = guide.sections(ThemeDB.fallback_font)
	var beginner: String = guide.text(ThemeDB.fallback_font)
	check(beginner.find("1. Choose your ship") < beginner.find("2. Explore the star system"), "Beginner reference follows expedition order")
	check(beginner.find("2. Explore the star system") < beginner.find("3. Take turns playing cards"), "Map comes before battle explanation")
	check(beginner.find("3. Take turns playing cards") < beginner.find("7. Improve your ship and move on"), "Core loop finishes with rewards and travel")
	check(beginner.contains("Synthesizer") and beginner.contains("Reactor") and beginner.contains("Quarters"), "Reference explains all three production systems")
	check(beginner.contains("Shields") and beginner.contains("Hull") and beginner.contains("Salvage"), "Reference explains protection and persistent currency")
	check(beginner.contains("[url=emp]") and beginner.contains("[url=preview]"), "Existing contextual help sections remain reachable")
	check(chapters.has("modifiers") and chapters.has("icons"), "Battlefield help and icon legend retained")
	for dimensions in [Vector2i(1280,720), Vector2i(960,540)]:
		root.size = dimensions
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		await process_frame
		var reference = board.settings_button.information
		var state: String = str(board._both_states())
		var charge = board.get_node("FTLPanel/Charge")
		var event := InputEventScreenTouch.new()
		event.position = charge.get_global_rect().get_center()
		event.pressed = true
		root.push_input(event, true)
		await create_timer(0.1).timeout
		check(reference.shade.visible and reference.body.text.contains("EMP Pulse"), "EMP label opens shared reference")
		check(str(board._both_states()) == state and board.winner.is_empty(), "Help tap performs no combat action")
		for key in preload("res://scripts/ui/game_reference.gd").sections(ThemeDB.fallback_font):
			reference.show_reference(key)
			await create_timer(0.05).timeout
			check(reference.body.text.contains("GAME REFERENCE") and reference.body.text.contains("Icon Legend"), "Every section retains complete reference and legend")
		check(root.get_visible_rect().encloses(reference.panel.get_global_rect()), "Reference panel fits landscape viewport")
		var scroll = reference.body.get_parent()
		await create_timer(0.1).timeout
		check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Long reference scrolls")
		scroll.scroll_vertical = 100
		check(scroll.scroll_vertical > 0, "Reference accepts scrolling")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/testlogs/game-reference-%d.png" % dimensions.x)
		reference.dismiss()
		board.queue_free()
		await process_frame
	print("Game reference: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
