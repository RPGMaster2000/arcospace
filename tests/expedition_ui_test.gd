extends SceneTree
# Run with a rendering driver to also save PNGs; headless mode still checks geometry.
var host: Control
var failures: int = 0

func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for n in range(4): await process_frame

func snapshot(label: String) -> void:
	await settle()
	var logical_size: Vector2 = root.get_visible_rect().size
	check(host.ui.size.x <= logical_size.x and host.ui.size.y <= logical_size.y, "UI fits scaled viewport " + label)
	for child in host.view.get_children():
		check(child.size.x <= host.view.size.x + 1, "Text/button width fits scroll area " + label)
		if child is Button:
			check(child.size.y >= 48, "Touch target height " + label)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/expedition-" + label + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 456
	root.add_child(host)
	current_scene = host
	host._remove_battle()
	host.state.active_battle = -1
	host.state.hull = 20
	host.state.salvage = 15
	host.show_system()
	await snapshot("system")
	for index in range(host.rules.pois.size()):
		host.state.encounters[0] = {"kind":"poi", "poi":host.rules.pois[index], "title":host.rules.pois[index].title, "completed":false}
		host.show_poi(0)
		await snapshot("poi-%d" % index)
		check(host.return_button.visible and host.jump_button.disabled == (not host.state.can_jump()), "Return and drive state shown")
		host.return_button.pressed.emit()
		check(host.view_kind == "system" and not host.state.encounters[0].completed, "Return does not consume encounter")
	host.state.service = {"kind":"service", "poi":host.rules.trading_outpost, "title":"Trading Outpost", "completed":false}
	host.show_poi(host.state.SERVICE_INDEX)
	check(host.approach_note.text.contains("No pressure"), "Service identified separately")
	host._approach(host.state.SERVICE_INDEX, 2)
	check(host.state.pending_choice == "card", "Card selection visible after reward")
	await snapshot("cards")
	var before: int = host.state.acquired_cards.size()
	host.card_gallery.grid.get_child(1).pressed.emit()
	check(host.state.acquired_cards.size() == before, "Preview requires confirmation")
	host.card_management.confirm_button.pressed.emit()
	check(host.state.acquired_cards.size() == before + 1 and host.state.pending_choice.is_empty(), "Real selection button grants exactly one card")
	check(host.view_kind == "poi" and host.selected_encounter == host.state.SERVICE_INDEX, "Card purchase returns directly to station")
	await snapshot("outcome")
	host.state.start_upgrade_event(1)
	host.show_outcome()
	await snapshot("upgrades")
	host._upgrade(host.state.upgrade_candidates()[0].identity_key())
	host.show_system()
	root.size = Vector2i(1560, 720)
	await snapshot("wide")
	root.size = Vector2i(960, 540)
	await snapshot("small")
	host._exit()
	await process_frame
	check(current_scene.scene_file_path.ends_with("battle_setup.tscn"), "Return to ship selection")
	current_scene.showcase.skip_cinematics = true
	current_scene.showcase._stop_tween()
	current_scene.showcase._finish_intro()
	current_scene.showcase.logo.modulate.a = 0.0
	current_scene.showcase.phase = current_scene.showcase.Phase.SHIP_SELECTION
	current_scene._selection_ready()
	current_scene.white_fade_duration = 0.001
	current_scene.map_reveal_duration = 0.001
	current_scene._start()
	for frame in range(8): await process_frame
	host = current_scene
	check(host.scene_file_path.ends_with("expedition.tscn") and host.view_kind == "system", "Ship selection starts expedition without mandatory battle")
	host.free()
	await process_frame
	print("Expedition UI checks: %d failures" % failures)
	quit(1 if failures else 0)

