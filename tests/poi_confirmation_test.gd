extends SceneTree
var host: Control
var checks = 0
var failures = 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for n in range(16): await process_frame
func click(position: Vector2) -> void:
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
func screenshot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/confirmation-" + name + ".png")
func header_rects() -> Array:
	return [host.title.get_global_rect(), host.legend.get_global_rect(), host.resource_bar.get_global_rect()]
func run() -> void:
	host = load("res://scenes/expedition.tscn").instantiate()
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 789
	host.rules.log_rolls = false
	root.add_child(host)
	current_scene = host
	for resolution in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(2400,1080), Vector2i(686,384)]:
		root.size = resolution
		host.start_expedition()
		await settle()
		var rectangles = header_rects()
		var title: String = host.title.text
		var enemy_index = -1
		for i in range(host.state.encounters.size()):
			if host.state.encounters[i].kind == "battle": enemy_index = i
		if enemy_index >= 0:
			host.show_battle_preview(enemy_index)
			await settle()
			check(header_rects() == rectangles and host.title.text == title, "Enemy preview preserves exploration header")
		var poi = load("res://encounters/mining_operation.tres")
		host.state.encounters[0] = {"kind":"poi", "poi":poi, "title":poi.title, "completed":false}
		host.show_poi(0)
		await settle()
		check(header_rects() == rectangles and host.title.text == title, "PoI preserves title, Legend and resource bar positions")
		check(not host.footer.is_visible_in_tree() and not host.confirmation.shade.visible, "No permanent confirmation footer")
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Ordinary PoI fits without scrolling")
		check(not host.approach_buttons[1].details.get_parsed_text().to_lower().contains("next battle"), "Compact outcome text")
		check(host.approach_buttons[1].details.text.contains("[b]75%[/b]") and host.approach_buttons[1].details.text.contains("color=f49b97"), "Readable bold chance and colored penalty")
		await screenshot("choices-%d" % resolution.x)
		var salvage: int = host.state.salvage
		var hull: int = host.state.hull
		var ftl: int = host.state.ftl_charge
		var rng_state: int = host.state.rng.state
		host.approach_buttons[1].pressed.emit()
		check(host.confirmation.shade.visible and host.confirmation.shade.modulate.a < 1, "Selecting begins fade-in")
		await create_timer(.25).timeout
		await settle()
		check(is_equal_approx(host.confirmation.shade.modulate.a, 1), "Fade completes")
		check(root.get_visible_rect().grow(-23).encloses(host.confirmation.panel.get_global_rect()), "Floating confirmation stays within safe edges")
		check(host.confirm_button.text == "Initiate" and host.confirmation.cancel_button.text == "Cancel", "Clear confirmation controls")
		check(host.confirm_button.size.y >= 48 and host.confirmation.cancel_button.size.y >= 48, "Touch targets")
		var tab = InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.pressed = true
		root.push_input(tab, true)
		check(root.gui_get_focus_owner() == host.confirm_button, "Tab reaches Initiate")
		root.push_input(tab, true)
		check(root.gui_get_focus_owner() == host.confirmation.cancel_button, "Tab stays within modal")
		await screenshot("open-%d" % resolution.x)
		click(host.return_button.get_global_rect().get_center())
		check(host.view_kind == "poi" and host.confirmation.shade.visible, "Shade blocks underlying navigation")
		click(host.confirmation.cancel_button.get_global_rect().get_center())
		check(not host.confirmation.shade.visible and host.selected_approach == -1, "Cancel closes selection")
		check(host.state.rng.state == rng_state and host.state.salvage == salvage and host.state.hull == hull and host.state.ftl_charge == ftl and not host.state.encounters[0].completed, "Cancel preserves RNG, resources and encounter")
		host.approach_buttons[0].pressed.emit()
		var escape = InputEventAction.new()
		escape.action = "ui_cancel"
		escape.pressed = true
		root.push_input(escape, true)
		check(not host.confirmation.shade.visible, "Back/Escape cancels")
		host.approach_buttons[0].pressed.emit()
		await settle()
		click(host.confirm_button.get_global_rect().get_center())
		host.confirm_button.pressed.emit()
		check(host.state.salvage == salvage + 3 and host.state.ftl_charge == ftl + 1, "Initiate applies reward exactly once")
		await settle()
		check(header_rects() == rectangles and host.title.text == title, "Outcome preserves exploration header")
		host.show_system()
		await settle()
		check(header_rects() == rectangles, "Return to system preserves header")
	host.free()
	await process_frame
	print("PoI confirmation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
