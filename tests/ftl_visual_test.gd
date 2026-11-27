extends SceneTree
const SkinTheme = preload("res://scripts/ui/holographic/skin.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
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
	board.ftl.disabled_turns = 2
	board.ftl.disabled_turn_started = true
	board._begin_turn("player")
	check(board.get_node("ModifierDisplay/FTLFlash").text.is_empty(), "Unchanged offline state never repeats flash")
	board.ftl.disabled_turns = 1
	board.ftl.disabled_turn_started = true
	board._process(0)
	check(is_equal_approx(light.light_energy,base*0.3), "Offline seventy percent weaker")
	board._begin_turn("player")
	check(board.get_node("ModifierDisplay/FTLFlash").text.contains("RESUMING CHARGING"), "Repair transition announces resumed charging")
	var panel: Control = board.get_node("FTLPanel")
	var jump: Button = panel.get_node("WarpButton")
	var tab: Button = panel.activation_tab
	var charge_preview: Dictionary = board._display_snapshot()
	charge_preview.emp.charge = 0
	charge_preview.emp.can_warp = false
	var previous_motion := Preferences.ui_motion()
	Preferences.set_ui_motion(0)
	for charge in [0, floori(board.ftl.charge_target * 0.5), board.ftl.charge_target - 1]:
		board.ftl.charge = charge
		board.refresh_display()
		check(is_equal_approx(panel.fill, float(charge) / board.ftl.charge_target),
			"Idle strip displays the exact vertical fill")
		check(panel.state == ("near" if charge == board.ftl.charge_target - 1 else "charging") and not jump.visible and not tab.visible,
			"Uncharged EMP stays passive")
	Preferences.set_ui_motion(1)
	board.ftl.charge = board.ftl.charge_target
	board.refresh_display()
	check(jump.visible and not jump.disabled and panel.get_node("Charge").text == "RDY",
		"Full EMP retains vertical telemetry and enables the action")
	check(jump.position == Vector2.ZERO and jump.size.is_equal_approx(panel.size),
		"EMP button has the complete telemetry tile as a touch target")
	var expansion: Tween = panel.get_meta("holo_activation")
	expansion.custom_step(0.08)
	check(tab.visible and not tab.disabled and tab.scale.x > 0.18 and tab.scale.x < 1.0,
		"The top action tab expands only on readiness")
	board.refresh_display()
	check(panel.get_meta("holo_activation") == expansion, "Repeated refresh does not restart tab expansion")
	expansion.custom_step(1.0)
	check(tab.get_global_rect().size.is_equal_approx(Vector2(48, 48))
		and tab.get_global_rect().position.is_equal_approx(panel.activation_bounds().position),
		"Top tab settles with a full-size touch target")
	var ready: Tween = panel.get_meta("holo_charge")
	ready.custom_step(SkinTheme.DEFAULT.emp_ready_seconds * 0.5)
	check(panel.sweep > 0.0 and panel.sweep < 1.0, "Ready shimmer sweeps upward once")
	board.refresh_display()
	check(panel.get_meta("holo_charge") == ready, "Repeated refresh keeps the current ready animation")
	ready.custom_step(1.0)
	check(panel.sweep == 1.0 and panel.fill == 1.0 and not panel.has_meta("holo_charge"),
		"Ready state settles without a looping pulse")
	check(board._display_snapshot().enemy_modifier.is_empty(), "Neutral battles have no enemy environment section")
	board.modifier.configure(1, 17)
	board.refresh_display()
	check(board.hud._modifier.text.begins_with("Asteroid Belt"), "The player panel holds the legacy modifier")
	board.modifier.configure(0, 17)
	board.refresh_display()
	check(board.get_node("ModifierDisplay").get_index() < board.get_node("FTLPanel").get_index() and board.get_node("ModifierDisplay").get_index() < board.get_node("MatchResult").get_index(), "Modifier sits behind EMP and victory controls")
	board.ftl.disabled_turns = 2
	board.refresh_display()
	check(jump.visible and jump.disabled and panel.state == "offline" and panel.get_node("Charge").text == "OFF",
		"Charged offline EMP remains visible and disabled")
	check(tab.disabled, "Offline EMP disables the activation tab immediately")
	var retraction: Tween = panel.get_meta("holo_activation")
	retraction.custom_step(1.0)
	check(not tab.visible, "Offline EMP retracts the top tab")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/jump-offline.png")
	board._warp_out()
	check(board.winner.is_empty(), "Offline Jump cannot escape")
	board.ftl.disabled_turns = 0
	board.refresh_display()
	check(not jump.disabled and panel.state == "ready", "Online EMP restores the ready state")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/jump-ready.png")
	board.engine_phase = 0
	board._process(0)
	check(is_equal_approx(light.light_energy,base*1.4), "Charged base forty percent stronger")
	board._process(0.2)
	check(light.light_energy > base*1.4, "Charged light pulsates")
	board.ftl.disabled_turns = 1
	board.ftl.disabled_turn_started = true
	board._begin_turn("player")
	check(board.get_node("ModifierDisplay/FTLFlash").text == "EMP PULSE ONLINE", "Fully charged repaired FTL announces online")
	board._fit_ftl() # Refit after screenshot frames have advanced the ship's idle motion.
	var resources: Rect2 = board.get_node("PlayerResource1").get_rect().merge(board.get_node("PlayerResource3").get_rect())
	check(is_equal_approx(panel.size.x, 0.24 * board.get_node("PlayerResource1").size.x)
		and is_equal_approx(panel.size.y, resources.size.y)
		and panel.position.is_equal_approx(Vector2(resources.end.x + SkinTheme.DEFAULT.related_gap, resources.position.y)),
		"The EMP is a thin extension of the player resource rail")
	for tile in [board.player_hull_label, board.player_shields_label, board.get_node("PlayerResource3"), board.allocation_button]:
		check(not panel.get_global_rect().intersects(tile.get_global_rect()), "EMP keeps clear of other combat controls")
	check(jump.get_global_rect().end.y < board.get_node(board.card_slots[0]).position.y, "Charged EMP button clears card hand")
	check(board.player_shields_label.get_theme_font_size("font_size") == board.player_hull_label.get_theme_font_size("font_size"), "Matching status font sizes")
	board.hud.enemy_panel.handle.pressed.emit()
	panel._settle_activation_tab()
	# Use the new visible action, not the board method or old strip target.
	tab.pressed.emit()
	check(board.escaped_by_ftl and not board.hud.enemy_panel.drawer.visible, "Using EMP closes the enemy drawer")
	check(panel.state == "used" and not jump.visible and tab.disabled, "Successful activation exits the ready state")
	var discharge: Tween = panel.get_meta("holo_charge")
	discharge.custom_step(SkinTheme.DEFAULT.emp_discharge_seconds * 0.5)
	check(panel.fill < 1.0 and panel.fill > 0.0 and panel.sweep < 1.0, "EMP visibly drains during its discharge")
	discharge.custom_step(1.0)
	check(panel.fill == 0.0 and panel.sweep == 1.0, "Discharge settles on an empty used strip")
	panel.present(charge_preview)
	check(panel.state == "charging", "Next charge cycle resets the discharge")
	Preferences.set_ui_motion(0)
	charge_preview.emp.charge = charge_preview.emp.charge_target
	charge_preview.emp.can_warp = true
	panel.present(charge_preview)
	check(panel.state == "ready" and panel.fill == 1.0 and tab.visible and tab.scale == Vector2.ONE
		and not panel.has_meta("holo_activation") and not panel.has_meta("holo_charge"),
		"Minimal motion presents readiness immediately")
	panel.discharge()
	check(panel.state == "used" and panel.fill == 0.0 and panel.sweep == 1.0 and not tab.visible,
		"Minimal motion snaps the used state and retracts the tab")
	Preferences.set_ui_motion(previous_motion)
	board.queue_free()
	await process_frame
	print("FTL visual checks: %d failures" % failures)
	quit(1 if failures else 0)

