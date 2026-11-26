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
	Preferences.set_ui_motion(saved_motion)

	var player_meter: ProgressBar = hud._shield_meters.player
	var enemy_meter: ProgressBar = hud._shield_meters.enemy
	check(player_meter.max_value == Holo.DEFAULT.shield_reference and enemy_meter.max_value == player_meter.max_value,
		"Both sides use the same configured Shield reference")
	hud._refresh_shields("player", 10, false)
	hud._refresh_shields("enemy", 25, false)
	check(is_equal_approx(player_meter.ratio, 0.2) and is_equal_approx(enemy_meter.ratio, 0.5),
		"Ten and twenty-five Shield points fill one fifth and half of the bar")
	hud._refresh_shields("player", 65, false)
	check(player_meter.ratio == 1.0 and board.player_shields_label.text == "Shields 65 ↑",
		"Overflow keeps the exact value with a distinct full meter")
	hud._refresh_shields("player", 0, false)
	check(player_meter.ratio == 0.0 and board.player_shields_label.text == "Shields 0", "Active zero is distinct")
	hud._refresh_shields("enemy", 65, true)
	check(enemy_meter.ratio == 0.0 and board.enemy_shields_label.text == "Shields OFF",
		"Disabled Shields have their own explicit state")
	hud._refresh_shields("enemy", 10, false)
	check(is_equal_approx(enemy_meter.ratio, 0.2), "Overflow cannot increase the scale after Shields return")
	board.player_hull = board.player_hull_capacity + 4
	board.refresh_display()
	check(board.player_hull_label.text.contains(str(board.player_hull)) and
		board.get_node("PlayerHullBar").tooltip_text.contains("Plating"), "Hull telemetry keeps Ablative Plating")

	for viewport in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(686, 384)]:
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
		for side in ["Player", "Enemy"]:
			for index in range(3):
				var family: String = hud.RESERVES[index]
				var production: String = hud.PRODUCTION[index]
				var tile: Control = board.get_node("%sResource%d" % [side, index + 1])
				var badge: Control = tile.get_node("ProductionBadge")
				var badge_text: Label = tile.get_node(production)
				var frame_style: StyleBox = tile.get_child(0, true).get_theme_stylebox("panel")
				check(frame_style.bg_color == Holo.family_surface(family), "Resource surface matches " + family)
				check(Rect2(Vector2.ZERO, tile.size).encloses(badge.get_rect()) and
					badge.get_rect().encloses(badge_text.get_rect()) and badge_text.text.begins_with(hud.PRODUCTION_TAGS[index]),
					"Production fits inside its family panel at " + str(viewport))

	board.queue_free()
	await process_frame
	print("Battle telemetry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
