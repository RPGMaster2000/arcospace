extends SceneTree

const BoardScene = preload("res://scenes/board_3d.tscn")
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error(message)


func activate(control: Control, touch: bool) -> void:
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


func run() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "0")
	var board = BoardScene.instantiate()
	board.setup_settings = {"player_ship": 1, "enemy_ship": 0}
	root.add_child(board)
	board.enemy_timer.stop()
	if board.battle_effects.busy: await board.battle_effects.finished
	var hud = board.hud
	var header = hud.header
	check(header.player.text == "Thunderbolt" and not header.player.get_node("Subtitle").text.is_empty(),
		"Player identity includes selected ship and signature")
	check(not header.enemy.text.is_empty() and not header.enemy.get_node("Subtitle").text.is_empty(),
		"Enemy identity includes the enemy profile")
	check(not board.has_node("SalvageLabel"), "Combat header has no permanent Salvage counter")
	for index in range(3):
		var readout: Label = [header.player, header.turn, header.enemy][index]
		var gradient: ColorRect = header._backdrops[readout]
		var material := gradient.material as ShaderMaterial
		check(gradient.show_behind_parent and gradient.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"Header gradients stay behind the text and leave interactions to the foreground")
		check(material.get_shader_parameter("direction") == float(index - 1)
			and is_equal_approx(material.get_shader_parameter("vertical_fade"), Holo.DEFAULT.header_vertical_fade)
			and is_equal_approx(material.get_shader_parameter("shade").a, Holo.DEFAULT.header_opacity),
			"Header gradient uses the configured direction, fade, and opacity")
	var saved_motion := Preferences.ui_motion()
	Preferences.set_ui_motion(1)
	var snapshot: Dictionary = board._display_snapshot()
	snapshot.turn_number = 8
	snapshot.current_actor = "player"
	header.update(snapshot)
	check(header.round_label.text == "ROUND 8" and header.turn.text == "YOUR TURN",
		"Central header displays the existing round and active side")
	snapshot.current_actor = "enemy"
	header.update(snapshot)
	var first_transition: Tween = header.turn.get_meta("holo_panel", null) if header.turn.has_meta("holo_panel") else null
	header.update(snapshot)
	check(header.turn.text == "ENEMY TURN" and (not header.turn.has_meta("holo_panel") if first_transition == null
		else header.turn.get_meta("holo_panel") == first_transition), "Repeated update keeps the current turn transition")
	snapshot.current_actor = "player"
	header.update(snapshot)
	check(first_transition != null and not first_transition.is_valid(), "Next turn interrupts the old transition")
	Preferences.set_ui_motion(0)
	snapshot.current_actor = "enemy"
	header.update(snapshot)
	check(not header.turn.has_meta("holo_panel") and header.turn.modulate.a == 1.0,
		"Minimal motion presents the new turn immediately")

	var player_stack: Control = hud._shield_stacks.player
	var enemy_stack: Control = hud._shield_stacks.enemy
	check(not player_stack is Range and not enemy_stack is Range, "Shield stacks have no maximum or track")
	for amount in [0, 1, 5, 23, 50, 100, 200, 203]:
		for side in ["player", "enemy"]:
			var stack: Control = hud._shield_stacks[side]
			var readout: Label = board.get_node(side.capitalize() + "ShieldsLabel")
			stack.update_shields(amount, false)
			var strip: Dictionary = stack.strip_layout(stack.displayed_points)
			check(readout.text == "Shields %d" % amount and stack.displayed_points == amount,
				"Minimal motion shows the exact %d Shields immediately on %s" % [amount, side])
			check(is_equal_approx(strip.partial, (amount % 5) / 5.0) and strip.width <= stack.size.x,
				"The Shield remainder is fractional and fits the meter space")
			if amount <= 50:
				check(strip.full == floori(amount / 5.0) and strip.multiplier.is_empty(),
					"Ordinary amounts draw individual five-point cells only")
			else:
				check(strip.full == 1 and strip.multiplier == "×%d" % floori(amount / 5.0),
					"High totals group complete cells and keep any partial cell separate")

	board.player_shields = 23
	board.enemy_shields = 200
	board.modifier.configure(3, 11)
	board.modifier.active = true
	board.refresh_display()
	check(player_stack.displayed_points == 0.0 and enemy_stack.displayed_points == 0.0
		and board.player_shields_label.text == "Shields OFF" and board.enemy_shields_label.text == "Shields OFF",
		"Disabled Shields show no segments and a distinct label")
	check(board.player_shields == 23 and board.enemy_shields == 200,
		"Disabled presentation leaves the underlying Shield values intact")
	board.modifier.active = false
	board.refresh_display()
	check(player_stack.displayed_points == 23.0 and enemy_stack.displayed_points == 200.0,
		"Restoring Shields restores the exact segment counts")

	Preferences.set_ui_motion(1)
	player_stack.update_shields(50, false)
	var gain: Tween = player_stack.get_meta("holo_shields")
	check(player_stack.displayed_points == 23.0 and board.player_shields_label.text == "Shields 50",
		"Growth starts from the displayed stack while the number remains exact")
	gain.custom_step(Holo.DEFAULT.meter_seconds * 0.25)
	var eased: float = player_stack.displayed_points
	check(eased > 23.0 and eased < 50.0, "Shield additions ease through partial segments")
	player_stack.update_shields(5, false)
	check(not gain.is_valid() and player_stack.displayed_points == eased,
		"A loss interrupts an in-flight gain from the currently painted amount")
	var loss: Tween = player_stack.get_meta("holo_shields")
	player_stack.update_shields(5, false)
	check(player_stack.get_meta("holo_shields") == loss, "Repeated updates keep the in-flight transition")
	loss.custom_step(Holo.DEFAULT.meter_seconds * 0.25)
	check(player_stack.displayed_points < eased and player_stack.displayed_points > 5.0,
		"Shield removal eases toward the target")
	Preferences.set_ui_motion(0)
	check(not player_stack.has_meta("holo_shields") and player_stack.displayed_points == 5.0
		and board.player_shields_label.self_modulate.a == 1.0, "Switching to Minimal completes the transition")
	Preferences.set_ui_motion(saved_motion)
	board.player_hull = board.player_hull_capacity + 4
	board.refresh_display()
	check(board.player_hull_label.text.contains(str(board.player_hull)) and
		board.get_node("PlayerHullBar").tooltip_text.contains("Plating"), "Hull telemetry keeps Ablative Plating")

	for viewport in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(2560, 1080), Vector2i(686, 384)]:
		root.size = viewport
		for frame in 3: await process_frame
		var left := board.get_node("PlayerIdentity").get_global_rect() as Rect2
		var right := board.get_node("ModeLabel").get_global_rect() as Rect2
		var center: Rect2 = header.turn.get_global_rect()
		if viewport != Vector2i(960, 540):
			await activate(header.player_info, viewport.x == 686)
			check(hud.player_panel.open, "Player identity opens Battle Systems at " + str(viewport))
			hud.close_panels(true)
		check(left.end.x < center.position.x and center.end.x < right.position.x and
			is_equal_approx(center.get_center().x, board.size.x * 0.5), "Headers stay separated and centered at " + str(viewport))
		var compact_strip: Dictionary = player_stack.strip_layout(203.0)
		check(compact_strip.width <= player_stack.size.x and compact_strip.multiplier == "×40",
			"Grouped Shields and a partial segment fit at " + str(viewport))
		check_resource_rows(board, str(viewport))
		if viewport == Vector2i(686, 384):
			var original_size: int = board.player_materials_label.get_theme_font_size("font_size")
			var layout := preload("res://scripts/ui/battle_layout.gd")
			var safe := layout.safe_bounds(board.size, Vector4(0, 32, 0, 64))
			board.hud.fit_combat_controls(safe)
			layout.fit(board, board.settings_button, board.allocation_button, safe)
			await process_frame
			check(board.get_node("PlayerResource1").position.y == board.get_node("PlayerResource3").position.y,
				"Constrained height exercises the horizontal resource fallback")
			check(board.player_materials_label.get_theme_font_size("font_size") == original_size,
				"Reserve type stays the same size in the fallback")
			check_resource_rows(board, "constrained height")

	board.queue_free()
	await process_frame
	print("Battle telemetry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_resource_rows(board: Control, context: String) -> void:
	var hud = board.hud
	for side in ["Player", "Enemy"]:
		for index in range(3):
			var family: String = hud.RESERVES[index]
			var production: String = hud.PRODUCTION[index]
			var tile: Control = board.get_node("%sResource%d" % [side, index + 1])
			var badge: Control = tile.get_node("ProductionBadge")
			var badge_text: Label = tile.get_node(production)
			var family_label: Label = tile.get_node("FamilyLabel")
			var reserve: Label = tile.get_node(family)
			check(family_label.get_rect().end.y < reserve.position.y
				and reserve.get_rect().end.y < badge.position.y,
				"Family, reserve and badge have independent rows on %s at %s" % [tile.name, context])
			check(family_label.size.y >= family_label.get_line_height()
				and reserve.size.y >= reserve.get_line_height()
				and badge_text.size.y >= badge_text.get_line_height(),
				"Every resource row fits its font metrics on %s at %s" % [tile.name, context])
			var backdrop: Control = badge.get_child(0, true)
			check(badge.get_global_rect().encloses(backdrop.get_global_rect()),
				"The badge backdrop stays inside the badge at " + context)
			var frame_style: StyleBox = tile.get_child(0, true).get_theme_stylebox("panel")
			check(frame_style.bg_color == Holo.family_surface(family), "Resource surface matches " + family)
			check(Rect2(Vector2.ZERO, tile.size).encloses(badge.get_rect()) and
				badge.get_rect().encloses(badge_text.get_rect()) and badge_text.text.begins_with(hud.PRODUCTION_TAGS[index]),
				"Production fits inside its family panel at " + context)
