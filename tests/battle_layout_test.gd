extends SceneTree
# Integration contract: navigation, authoritative modifier facts and unobstructed battle geometry.
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in range(6):
		await process_frame


func activate(control: Control, touch: bool = false) -> void:
	for pressed in [true, false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func capture(caption: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png(
		"res://.godot/testlogs/battle-layout-" + caption + ".png"
	)


func run() -> void:
	var insets: Vector4 = preload("res://scripts/ui/battle_layout.gd").scaled_insets(
		Rect2i(90, 20, 2160, 1040), Vector2i(2340, 1080), Vector2(1560, 720)
	)
	check(
		insets.is_equal_approx(Vector4(60, 40.0 / 3.0, 60, 40.0 / 3.0)),
		"Android cutout insets convert to logical HUD coordinates"
	)
	for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1680, 720)]:
		root.size = dimensions
		var board = load("res://scenes/board_3d.tscn").instantiate()
		root.add_child(board)
		board.enemy_timer.stop()
		await settle()
		board._fit_board_lines()
		await settle()
		var menu = board.settings_button
		var panel: Control = board.get_node("ModifierDisplay/Meter")
		var hand: Control = board.get_node(board.card_slots[0])
		var crew: Control = board.get_node("PlayerResource3")
		check(
			menu.get_global_rect().end.x < board.get_node("TurnLabel").position.x,
			"Menu sits to left of player information"
		)
		check(
			board.allocation_button.position.y >= crew.position.y + crew.size.y,
			"Allocation sits below Crew"
		)
		check(board.allocation_button.size.y >= 48 and menu.size.y >= 48, "Touch-friendly access")
		check(panel.get_global_rect().end.y < hand.position.y, "Modifier clears card hand")
		for path in [
			"PlayerHullBar",
			"EnemyHullBar",
			"PlayerHullLabel",
			"EnemyHullLabel",
			"PlayerShieldsLabel",
			"EnemyShieldsLabel"
		]:
			check(
				not panel.get_global_rect().intersects(board.get_node(path).get_global_rect()),
				"Modifier clears " + path
			)
		var poses: Array = []
		for path in board.card_slots:
			var card: Control = board.get_node(path)
			poses.append([card.position, card.size, card.scale])
			check(
				card.size == Vector2(198, 294) and card.scale == Vector2.ONE,
				"Six original readable cards"
			)
		await activate(menu, dimensions.x == 1560)
		check(menu.popup.visible, "Battle Menu opens")
		for index in range(1, 4):
			check(
				not menu.panel.get_global_rect().intersects(
					board.get_node("PlayerResource%d" % index).get_global_rect()
				),
				"Open navigation clears resources"
			)
		await capture("menu-%d" % dimensions.x)
		await activate(menu.close_button)
		check(not menu.popup.visible, "Close dismisses Battle Menu")
		await activate(menu)
		await activate(menu.settings_option)
		check(
			not menu.popup.visible and menu.menu.shade.visible and paused,
			"Settings option closes navigation and opens existing settings"
		)
		menu.menu.dismiss()
		check(not paused, "Settings releases its pause")
		await activate(menu)
		await activate(menu.info_option)
		check(
			not menu.popup.visible and menu.information.shade.visible,
			"Existing legend opens from Game Information"
		)
		menu.information.dismiss()
		await activate(menu)
		for pressed in [true, false]:
			var outside := InputEventMouseButton.new()
			outside.button_index = MOUSE_BUTTON_LEFT
			outside.position = Vector2(board.size.x - 12, 200)
			outside.pressed = pressed
			root.push_input(outside, true)
			await process_frame
		await settle()
		check(not menu.popup.visible, "Outside tap dismisses navigation")
		await activate(board.allocation_button, true)
		check(board.allocation_popup.shade.visible, "Relocated allocation opens")
		check(
			board.allocation_popup.panel.get_global_rect().end.y < hand.position.y,
			"Allocation choices clear cards"
		)
		await capture("allocation-%d" % dimensions.x)
		await activate(board.allocation_popup.choices[1], true)
		check(
			board.hand.allocation_mode == "offense" and not board.allocation_popup.shade.visible,
			"Existing allocation selection works"
		)
		var display = board.get_node("ModifierDisplay")
		for kind in range(6):
			board.modifier.configure(kind)
			board.modifier.next_round = 7
			board.modifier.ends_round = 8
			board.modifier.miss_rate = 30
			var rng_state: int = board.modifier.rng.state
			var before: Dictionary = board._both_states()
			display.refresh(board.modifier, 4)
			var text: String = display.get_node("Meter/Text").text
			if kind in [1, 2, 3]:
				check(text.contains("3 rounds"), "Inactive countdown reads actual state")
				display.refresh(board.modifier, 5)
				check(
					display.get_node("Meter/Text").text.contains("2 rounds"),
					"Countdown advances with round"
				)
			else:
				check(not text.contains("rounds"), "Permanent modifier has no countdown")
			if kind == 4:
				check(text.contains("Targeting accuracy: 70%"), "Nebula displays hit probability")
			if kind == 5:
				check(
					text.contains("Uncommon card chance doubled"),
					"Rift displays actual draw multiplier"
				)
			if kind in [2, 3]:
				board.modifier.active = true
				board.modifier.ion_factor = 2.0
				display.refresh(board.modifier, 6)
				check(
					display.get_node("Meter/Text").text.contains("2 rounds left"),
					"Active duration reads actual state"
				)
				check(
					display.get_node("Meter/Text").text.contains(
						"doubled" if kind == 2 else "Shields disabled"
					),
					"Active effect is explicit"
				)
				if kind == 2:
					board.modifier.ion_factor = 0.5
					display.refresh(board.modifier, 6)
					check(
						display.get_node("Meter/Text").text.contains("halved"),
						"Ion HUD follows announced half multiplier"
					)
			await activate(panel, true)
			check(
				(
					panel.details.shade.visible
					and panel.details.body.text.contains(board.modifier.description(kind))
				),
				"Expanded modifier shows original full rules"
			)
			panel.details.dismiss()
			check(
				board._both_states() == before and board.modifier.rng.state == rng_state,
				"HUD cannot change combat state or random sequence"
			)
			await capture("%d-modifier-%d" % [dimensions.x, kind])
		for index in range(6):
			var card: Control = board.get_node(board.card_slots[index])
			check(
				[card.position, card.size, card.scale] == poses[index],
				"Utility panels preserve hand geometry"
			)
		board.free()
		await process_frame
	print("Battle layout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
