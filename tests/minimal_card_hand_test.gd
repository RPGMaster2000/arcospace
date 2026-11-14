extends SceneTree
## Real production battle, unchanged six-slot layout, native input and captures.
const Cards = preload("res://scripts/cards/card_library.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
var checks := 0
var failures := 0
var discards := 0
var plays := 0
var board: Control


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in range(8):
		await process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := (
		"res://.godot/testlogs/minimal-cards/" + RenderingServer.get_current_rendering_method()
	)
	DirAccess.make_dir_recursive_absolute(directory)
	root.get_texture().get_image().save_webp(directory + "/" + label + ".webp", false, 0.90)


func mouse(point: Vector2, button: int) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = button
		event.pressed = down
		root.push_input(event, true)


func touch(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.position = point
	event.index = 1
	event.pressed = down
	root.push_input(event, true)


func run() -> void:
	seed(7331)  # Reproducible production arena and presentation captures.
	board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardHand").rng.seed = 1042
	board.get_node("EnemyHand").rng.seed = 1043
	root.add_child(board)
	current_scene = board
	board.enemy_timer.stop()
	board.enemy_timer.wait_time = 60
	if board.battle_effects.busy:
		await board.battle_effects.finished
	var names := [
		"Boarding Operations",
		"Reactive Armor",
		"Energy Surge",
		"Emergency Power Cell",
		"Command Infiltration",
		"Fabrication Strike"
	]
	set_hand(names, false)
	board.hand.cards[4] = board.hand.cards[4].with_upgrade(2)
	board.player_materials = 0
	board.player_energy = 0
	board.player_crew = 0
	board.refresh_display()
	await settle()
	var snapshot := JSON.stringify(board._both_states())
	var rng_before: Array = [
		board.hand.rng.state,
		board.enemy_hand.rng.state,
		board.enemy_ai.rng.state,
		Effects.combat_rng.state
	]
	for dimensions in [
		Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1280, 573)
	]:
		root.size = dimensions
		await settle()
		var width: float = board.size.x
		var scale_factor := minf(1, (width - 82) / (198 * 6))
		var hand_width := 198 * scale_factor * 6 + 50
		check(board.card_slots.size() == 6, "Exactly six existing hand slots")
		for slot in range(6):
			var view: Button = board.get_node(board.card_slots[slot])
			var expected := Vector2(
				(width - hand_width) / 2 + slot * (198 * scale_factor + 10),
				board.size.y - 12 - 294 * scale_factor
			)
			check(
				(
					view.size == Vector2(198, 294)
					and view.scale.is_equal_approx(Vector2.ONE * scale_factor)
				),
				"Original base size and hand scale %s/%d" % [dimensions, slot]
			)
			check(
				view.position.is_equal_approx(expected),
				"Original hand positioning and spacing %s/%d" % [dimensions, slot]
			)
			check(
				(
					view.disabled == (view.card_data.cost > 0)
					and not view.get_node("DiscardButton").disabled
				),
				"Paid cards unaffordable; zero-cost cards playable; both discardable"
			)
			check(
				is_equal_approx(view.get_node("DiscardButton").size.y * scale_factor, 44),
				"Existing 44px touch target"
			)
			check(
				(
					view.get_node("DescriptionLabel").modulate.a == 1
					and view.self_modulate == Color.WHITE
				),
				"Unaffordable rules stay readable"
			)
		for slot in range(5):
			var left: Control = board.get_node(board.card_slots[slot])
			var right: Control = board.get_node(board.card_slots[slot + 1])
			var gap: float = right.position.x - (left.position.x + left.size.x * left.scale.x)
			var left_glow: float = left.get_theme_stylebox("pressed").shadow_size * left.scale.x
			var right_glow: float = right.get_theme_stylebox("pressed").shadow_size * right.scale.x
			check(gap > left_glow + right_glow, "Largest two card glows cannot reach each other")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var pixels := root.get_texture().get_image()
			var pixel_scale := Vector2(
				pixels.get_width() / board.size.x, pixels.get_height() / board.size.y
			)
			for path in board.card_slots:
				var card: Control = board.get_node(path)
				var local_point := (
					card.position + Vector2(card.size.x * 0.5, card.size.y - 1) * card.scale
				)
				var sample := local_point * pixel_scale
				var ink := pixels.get_pixel(floori(sample.x), floori(sample.y))
				check(
					maxf(ink.r, maxf(ink.g, ink.b)) > 0.4,
					"Rendered lower border remains visible beneath footer"
				)
		await capture("hand-%dx%d" % [dimensions.x, dimensions.y])
	check(
		JSON.stringify(board._both_states()) == snapshot,
		"Layout/refresh never changes combat state"
	)
	check(
		(
			[
				board.hand.rng.state,
				board.enemy_hand.rng.state,
				board.enemy_ai.rng.state,
				Effects.combat_rng.state
			]
			== rng_before
		),
		"Layout/refresh never consumes any gameplay RNG"
	)
	var original_cards: Array = board.hand.cards.duplicate()
	root.size = Vector2i(960, 540)
	set_hand(
		[
			"Missile Team",
			"Reactor Synchronization",
			"Shield Collapse",
			"Sabotage Operation",
			"Feedback Loop",
			"Scientific Breakthrough"
		],
		true
	)
	board.refresh_display()
	await settle()
	await capture("complex-upgrades-960x540")
	board.hand.cards.assign(original_cards)
	root.size = Vector2i(1280, 573)
	board.refresh_display()
	await settle()
	var view: Button = board.get_node(board.card_slots[4])
	var original_rect := view.get_global_rect()
	view.set_interaction_emphasis(true, true)
	await create_timer(0.25).timeout
	check(view.get_global_rect() == original_rect, "Selected card keeps exact hand geometry")
	var art_rect: Rect2 = view.get_node("ArtPlaceholder").get_global_rect()
	check(
		(
			art_rect.position.x >= original_rect.position.x + 3 * view.scale.x
			and art_rect.end.x <= original_rect.end.x - 3 * view.scale.x
		),
		"Existing selected artwork zoom clears the unchanged card frame"
	)
	check(
		(
			art_rect.position.y > original_rect.position.y + 57 * view.scale.y
			and (
				art_rect.end.y
				<= view.get_node("DescriptionLabel").get_global_rect().position.y - 3 * view.scale.y
			)
		),
		"Selected artwork remains separated from divider and effects"
	)
	await capture("selected-conditional")
	var point := view.get_global_rect().get_center()
	touch(point, true)
	await create_timer(0.48).timeout
	touch(point, false)
	await settle()
	check(board.hud.tactical.source == view, "Native Android hold reaches existing preview")
	check(
		view.preview_selected and view.get_theme_stylebox("normal").border_width_top == 3,
		"Actual held card receives selected resource theme"
	)
	check(
		view.position.y < original_rect.position.y and view.z_index == 190,
		"Existing preview raises selection above neighboring cards"
	)
	await capture("held-selection")
	board.hud.tactical.open_inspection()
	await create_timer(0.25).timeout
	var overlay := root.get_node_or_null("CardInspection")
	check(overlay != null and overlay.is_open(), "Existing complete inspection opens")
	if overlay != null:
		check(
			overlay.current_card == view.card_data, "Inspection retains exact upgraded definition"
		)
		await capture("inspected-upgrade")
		overlay.dismiss(true)
	board.hud.tactical.dismiss(true)
	check(not view.preview_selected, "Dismissal clears resource selection highlight")
	await create_timer(0.25).timeout
	# Existing keyboard/controller inspection path remains on the original footer focus.
	for use_controller in [false, true]:
		view.get_node("DiscardButton").grab_focus()
		var event: InputEvent
		if use_controller:
			event = InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_Y
		else:
			event = InputEventKey.new()
			event.keycode = KEY_I
		event.pressed = true
		root.push_input(event, true)
		await settle()
		check(board.hud.tactical.source == view, "Existing keyboard/controller preview path")
		board.hud.tactical.dismiss(true)
		event.pressed = false
		root.push_input(event, true)
		await settle()
	# Mouse and native touch use the original footer's invisible upper hit area.
	for native_touch in [false, true]:
		board.current_actor = "player"
		board.enemy_timer.stop()
		board.refresh_display()
		await settle()
		view = board.get_node(board.card_slots[0])
		view.discard_requested.connect(func(): discards += 1, CONNECT_ONE_SHOT)
		var before: int = board.get("player_" + view.card_data.family)
		var family: String = view.card_data.family
		var refund := floori(view.card_data.cost / 3.0)
		var target: Rect2 = view.get_node("DiscardButton").get_global_rect()
		point = Vector2(target.get_center().x, target.position.y + 4)
		if native_touch:
			touch(point, true)
			touch(point, false)
		else:
			mouse(point, MOUSE_BUTTON_LEFT)
		await settle()
		check(discards == (2 if native_touch else 1), "Real footer input emits exactly once")
		var deadline := Time.get_ticks_msec() + 8000
		while board.resolving_card and Time.get_ticks_msec() < deadline:
			await process_frame
		board.enemy_timer.stop()
		check(not board.resolving_card, "Existing discard animation/turn flow completes")
		check(
			board.get("player_" + family) == before + refund,
			"Existing authoritative discard applies exact refund"
		)
	# Real mouse/native-touch play, using the authoritative zero-cost replay card.
	var surge: Resource
	for definition in Cards.CARDS:
		if definition.card_name == "Energy Surge":
			surge = definition
	check(
		surge != null and surge.cost == 0 and surge.effects.energy == 3,
		"Actual Energy Surge definition"
	)
	for native_touch in [false, true]:
		board.enemy_timer.stop()
		board.current_actor = "player"
		board.player_energy = 0
		board.hand.cards[2] = surge
		board.refresh_display()
		await settle()
		view = board.get_node(board.card_slots[2])
		view.pressed.connect(func(): plays += 1, CONNECT_ONE_SHOT)
		point = view.get_global_rect().get_center()
		if native_touch:
			touch(point, true)
			touch(point, false)
		else:
			mouse(point, MOUSE_BUTTON_LEFT)
		await settle()
		var deadline := Time.get_ticks_msec() + 8000
		while board.resolving_card and Time.get_ticks_msec() < deadline:
			await process_frame
		check(plays == (2 if native_touch else 1), "Actual card play handler fires once")
		check(
			board.player_energy == 3 and board.current_actor == "player",
			"Actual play applies existing gain and extra action exactly once"
		)
		await create_timer(1.1).timeout  # Existing replacement reveal, never bypassed.
	board.free()
	await settle()
	print("Minimal card hand: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func set_hand(names: Array, upgraded: bool) -> void:
	for slot in range(6):
		for definition in Cards.CARDS:
			if definition.card_name == names[slot]:
				board.hand.cards[slot] = definition.with_upgrade(2 if upgraded else 0)
