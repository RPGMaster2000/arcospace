extends SceneTree
# Integration contract: navigation, tactical drawers and unobstructed battle geometry.
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
	await tap(control.get_global_rect().get_center(), touch)


func tap(point: Vector2, touch: bool = false) -> void:
	for pressed in [true, false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
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
		board.setup_settings = {"player_ship": 0, "enemy_data": preload("res://ships/enemy/siege_monitor.tres"), "seed": 2026}
		root.add_child(board)
		board.enemy_timer.stop()
		await settle()
		board._fit_board_lines()
		await settle()
		var menu = board.settings_button
		var player_panel: Control = board.hud.player_panel
		var enemy_panel: Control = board.hud.enemy_panel
		var hand: Control = board.get_node(board.card_slots[0])
		var crew: Control = board.get_node("PlayerResource3")
		check(
			menu.get_global_rect().end.x < board.get_node("PlayerIdentity").position.x,
			"Menu sits to left of player information"
		)
		check(
			board.allocation_button.position.y >= crew.position.y + crew.size.y,
			"Allocation sits below Crew"
		)
		check(board.allocation_button.size.y >= 38 and menu.size.y >= 48, "Touch-friendly access")
		check(board.allocation_button.size.x == 64, "Allocation matches 64 px resource icon")
		var heading: Label = board.get_node("ModeLabel")
		var subtitle: Label = heading.get_node("Subtitle")
		var skin := preload("res://resources/presentation/holographic_skin.tres")
		check(is_equal_approx(board.size.x - heading.get_rect().end.x, skin.section_gap + skin.compact_padding), "Enemy header keeps a safe edge and inner padding")
		check(heading.position.y == board.get_node("PlayerIdentity").position.y, "Ship identities align")
		check(subtitle.global_position.y == board.get_node("PlayerIdentity/Subtitle").global_position.y, "Header subtitles align")
		check(is_equal_approx(board.get_node("TurnLabel").get_rect().get_center().x, board.size.x * 0.5), "Round readout is centered")
		for resource_index in range(1, 4):
			check(board.get_node("PlayerResource%d" % resource_index).position.y == board.get_node("EnemyResource%d" % resource_index).position.y, "Resource rows mirror")
		check(not player_panel.drawer.visible and not enemy_panel.drawer.visible, "Drawers start closed")
		for panel in [player_panel, enemy_panel]:
			check(panel.drawer.get_global_rect().end.y < hand.position.y, "Drawer clears the card hand")
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
		var touch: bool = dimensions.x == 1560
		await activate(crew, touch)
		check(player_panel.open and not enemy_panel.open, "Resource tile opens the player drawer")
		check(board.hud._boons.text == "No active boons", "Empty boons have an explicit state")
		check(board.hud._system.text == "Standalone battle", "Standalone battle has no system pressure")
		for kind in range(board.modifier.NAMES.size()):
			board.modifier.configure(kind)
			board.modifier.next_round = 7
			board.modifier.ends_round = 8
			board.modifier.miss_rate = 30
			board.turn_number = 4
			var rng_state: int = board.modifier.rng.state
			var before: Dictionary = board._both_states()
			board.refresh_display()
			var text: String = board.hud._modifier.text
			check(text.contains(board.modifier.description(kind)), "Player drawer has canonical modifier rules")
			check((kind == 0 and board.hud._enemy_modifier.text.is_empty()) or
				(kind != 0 and board.hud._enemy_modifier.text == text), "Enemy drawer shows applicable shared effects")
			if kind in [1, 2, 3, 6, 7]:
				check(text.contains("3 rounds"), "Inactive countdown reads actual state")
				board.turn_number = 5
				board.refresh_display()
				check(board.hud._modifier.text.contains("2 rounds"), "Countdown advances with round")
			if kind in [2, 3, 6, 7]:
				board.modifier.active = true
				board.turn_number = 6
				board.refresh_display()
				text = board.hud._modifier.text
				check(text.contains("2 rounds left"), "Active duration reads actual state")
				check(text.contains("Shields disabled" if kind == 3 else "effects doubled"), "Active effect is explicit")
			if kind == 4:
				check(text.contains("Targeting accuracy: 70%"), "Nebula displays hit probability")
			if kind == 5:
				check(text.contains("Uncommon card chance doubled"), "Rift displays actual draw multiplier")
			check(
				board._both_states() == before and board.modifier.rng.state == rng_state,
				"HUD cannot change combat state or random sequence"
			)
		await create_timer(0.25).timeout
		var behind := Button.new()
		behind.position = player_panel.drawer.position + Vector2(20, 8)
		behind.size = Vector2(80, 28)
		board.add_child(behind)
		board.move_child(behind, player_panel.get_index())
		behind.pressed.connect(func(): check(false, "Drawer leaked an input to the battlefield"))
		await activate(behind, touch)
		check(player_panel.open, "Tapping the panel background keeps it open")
		behind.free()
		await capture("%d-player-tactics" % dimensions.x)
		await activate(board.get_node("EnemyResource2"), touch)
		check(enemy_panel.open and not player_panel.drawer.visible, "Enemy resource tap switches drawers")
		check(board.hud._identity.text.contains(board.enemy_ship_data.summary), "Enemy drawer explains the vessel's tactics")
		check(board.hud._abilities.text.contains("Counter Volley"), "Enemy drawer describes its special card")
		await create_timer(0.25).timeout
		await capture("%d-enemy-tactics" % dimensions.x)
		await activate(enemy_panel.handle, touch)
		check(not enemy_panel.open, "Tapping again closes the enemy drawer")
		await activate(player_panel.handle, touch)
		board.cinematic_director._begin("heavy_beam", false)
		check(not player_panel.drawer.visible and enemy_panel.handle.disabled, "Cinematic closes and locks both drawers")
		board.cinematic_director.cancel()
		board.modifier.configure(0)
		board.refresh_display()
		await activate(player_panel.handle, touch)
		await board._finish_turn("enemy")
		check(not player_panel.open, "Ending a turn closes the drawer")
		for resource in ["materials", "energy", "crew"]:
			board.set("player_" + resource, 100)
		board.refresh_display()
		await activate(player_panel.handle, touch)
		var playable: int = -1
		for slot in range(board.hand.cards.size()):
			if board._can_play_card(board.hand.cards[slot], false, "player"):
				playable = slot
				break
		check(playable >= 0, "Fixture has a playable card")
		if playable >= 0:
			await activate(board.get_node(board.card_slots[playable]), touch)
			check(not player_panel.open, "Playing a card closes the player drawer")
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
