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
	root.add_child(board)
	var light = board.engine_light
	var base: float = board.engine_base_energy
	check(light != null and is_equal_approx(base,0.3), "User-authored engine light found")
	board.ftl.disabled_turns = 1
	board.ftl.disabled_turn_started = true
	board._process(0)
	check(is_equal_approx(light.light_energy,base*0.3), "Offline seventy percent weaker")
	board._begin_turn("player")
	check(board.get_node("ModifierDisplay/FTLFlash").text.contains("RESUMING CHARGING"), "Repair transition announces resumed charging")
	board.ftl.charge = board.ftl.charge_target
	board.engine_phase = 0
	board._process(0)
	check(is_equal_approx(light.light_energy,base*1.4), "Charged base forty percent stronger")
	board._process(0.2)
	check(light.light_energy > base*1.4, "Charged light pulsates")
	board.ftl.disabled_turns = 1
	board.ftl.disabled_turn_started = true
	board._begin_turn("player")
	check(board.get_node("ModifierDisplay/FTLFlash").text == "FTL ONLINE", "Fully charged repaired FTL announces online")
	var container = board.get_node("BattleView")
	var viewport = board.get_node("BattleView/Viewport")
	var ship = viewport.get_node("Battlefield/PlayerShip")
	var center = container.position + board.battle_camera.unproject_position(ship.global_position) * container.size / Vector2(viewport.size)
	var hull_y: float = board.player_hull_label.position.y + board.player_hull_label.size.y*0.5
	var panel = board.get_node("FTLPanel")
	check(absf((center.y - panel.position.y-panel.size.y*0.5) - (hull_y-center.y)) < 1, "FTL and Hull mirrored vertically")
	check(board.player_shields_label.get_theme_font_size("font_size") == board.player_hull_label.get_theme_font_size("font_size"), "Matching status font sizes")
	board.queue_free()
	await process_frame
	print("FTL visual checks: %d failures" % failures)
	quit(1 if failures else 0)
