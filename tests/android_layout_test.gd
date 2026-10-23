extends SceneTree
const Host = preload("res://scenes/expedition.tscn")
const Rules = preload("res://encounters/expedition_rules.tres")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var failures: int = 0
var assertions: int = 0
var host: Control

func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for n in range(10): await process_frame
func poi_at_zero(poi: Resource) -> void:
	host.state.encounters[0] = {"kind":"poi", "poi":poi, "title":poi.title, "completed":false}
	host.show_poi(0)
func verify_geometry() -> void:
	var viewport_rect: Rect2 = root.get_visible_rect()
	check(viewport_rect.encloses(host.ui.get_global_rect()), "UI inside viewport")
	check(host.scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "No horizontal scrolling")
	if host.view_kind == "poi":
		check(viewport_rect.encloses(host.return_button.get_global_rect()) and (not host.confirmation.shade.visible or viewport_rect.encloses(host.confirm_button.get_global_rect())), "Fixed Return and Confirm remain visible")
		check(host.return_button.size.y >= 48 and host.confirm_button.size.y >= 48, "Touch-sized fixed controls")
	if is_instance_valid(host.grid):
		for tile in host.grid.get_children():
			check(tile.size.y >= 84, "Tile touch target")
			check(tile.heading.get_global_rect().end.y <= tile.get_global_rect().end.y + 1, "Heading fits tile")
			check(tile.details.get_global_rect().end.y <= tile.get_global_rect().end.y + 1, "All reward lines fit tile")
			check(tile.get_global_rect().end.x <= host.scroll.get_global_rect().end.x + 1, "Tile width fits")
func screenshot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/layout-" + name + ".png")
func mouse(position: Vector2, pressed: bool, button: int = MOUSE_BUTTON_LEFT) -> void:
	var event = InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = button
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and button == MOUSE_BUTTON_LEFT else 0
	event.pressed = pressed
	root.push_input(event, true)

func run() -> void:
	host = Host.instantiate()
	host.persistence_enabled = false
	host.use_star_map = false # Keep coverage of the preserved grid presentation.
	host.rules = Rules.duplicate(true)
	host.rules.log_rolls = false
	host.rules.debug_seed = 789
	root.add_child(host)
	current_scene = host
	# Every authored approach, all player attributes, all reward lines.
	for ship_index in range(preload("res://scripts/ships/ship_library.gd").PLAYERS.size()):
		host.selected_ship = ship_index
		host.start_expedition()
		host.state.salvage = 30
		host.state.hull = 20
		for poi in Rules.pois:
			poi_at_zero(poi)
			await settle()
			check(host.grid.columns == 2, "Two-column approaches")
			for slot in range(poi.approaches.size()):
				var approach: Resource = poi.approaches[slot]
				var button = host.approach_buttons[slot]
				check(button.details.get_parsed_text().contains(host.compact_outcome(approach.success)), "Exact success values")
				check(button.details.text.contains(String.num(approach.success_chance * 100, 2).trim_suffix(".0") + "%"), "Exact probability")
				if approach.success_chance < 1:
					check(button.details.get_parsed_text().contains(host.compact_outcome(approach.failure)), "Exact failure values")
				check(button.disabled == (not host.state.locked_reason(approach).is_empty()), "Actual selected-ship requirements")
				host._cancel_approach()
				button.pressed.emit()
				check(not host.state.encounters[0].completed and host.state.salvage == 30 and host.state.hull == 20, "Selecting never executes")
			# Popup centering resolves after deferred minimum-size/layout updates.
			await settle()
			verify_geometry()
			host.return_button.pressed.emit()
			check(host.view_kind == "system" and not host.state.encounters[0].completed, "Return preserves encounter")
	# Confirm is the only UI execution path; repeated presses are harmless.
	poi_at_zero(Rules.pois[0])
	var before: int = host.state.ftl_charge
	host.approach_buttons[0].pressed.emit()
	check(not host.confirm_button.disabled and host.approach_buttons[0].selected, "Selection visibly enables Confirm")
	await settle()
	await screenshot("mining-selected")
	host.confirm_button.pressed.emit()
	host.confirm_button.pressed.emit()
	check(host.state.salvage == 33 and host.state.ftl_charge == before + 1 and host.state.encounters[0].completed, "Confirm grants exactly one unchanged reward")
	while host.presenting_outcome: await process_frame
	host.show_system()
	check(host.grid.get_child(0).disabled, "Completed tile stays disabled")
	# Six encounter cards fit common landscape viewports; all PoIs remain readable.
	for window_size in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(960,540),Vector2i(1280,480),Vector2i(686,384)]:
		root.size = window_size
		host.show_system()
		await settle()
		verify_geometry()
		check(host.grid.columns == 3 and host.grid.get_child_count() == 6, "3 by 2 encounter grid")
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Six encounters fit without scrolling")
		await screenshot("system-%dx%d" % [window_size.x,window_size.y])
		for poi in Rules.pois:
			poi_at_zero(poi)
			await settle()
			verify_geometry()
		await screenshot("poi-%dx%d" % [window_size.x,window_size.y])
	# Seven approaches exercise overflow with fixed controls and native scroll input.
	root.size = Vector2i(1280,720)
	var many = Rules.pois[0].duplicate(true)
	for n in range(3): many.approaches.append(many.approaches[0])
	poi_at_zero(many)
	await settle()
	check(host.more_hint.visible and host.grid.get_child_count() == 7, "Overflow hint and extra approach rows")
	var position: Vector2 = host.scroll.get_global_rect().get_center()
	mouse(position,true,MOUSE_BUTTON_WHEEL_DOWN)
	mouse(position,false,MOUSE_BUTTON_WHEEL_DOWN)
	await settle()
	check(host.scroll.scroll_vertical > 0, "Desktop wheel scrolls vertically")
	host.scroll.scroll_vertical = 0
	Input.emulate_touch_from_mouse = true
	await settle()
	position = host.approach_buttons[0].get_global_rect().get_center()
	mouse(position,true)
	for n in range(1,9):
		var motion = InputEventMouseMotion.new()
		motion.position = position - Vector2(0,n*16)
		motion.relative = Vector2(0,-16)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		await process_frame
	mouse(position - Vector2(0,128),false)
	await settle()
	check(host.scroll.scroll_vertical > 0, "Godot emulated touch drag scrolls")
	check(host.selected_approach == -1 and not host.state.encounters[0].completed, "Swipe does not select or execute")
	Input.emulate_touch_from_mouse = false
	# Android screen events also prevent release activation on a tile.
	var touch = InputEventScreenTouch.new()
	touch.position = host.scroll.get_global_rect().get_center()
	touch.pressed = true
	host.scroll._input(touch)
	var drag = InputEventScreenDrag.new()
	drag.position = touch.position + Vector2(0,-80)
	host.scroll._input(drag)
	touch.pressed = false
	host.scroll._input(touch)
	host.approach_buttons[0].pressed.emit()
	check(host.selected_approach == -1 and host.confirm_button.disabled, "Touch release activation rejected after drag")
	verify_geometry()
	await screenshot("overflow")
	# Inspector texture works, aspect-preserving crop remains configured; empty is valid.
	var image = Image.create(550,100,false,Image.FORMAT_RGBA8)
	image.fill(Color.DARK_BLUE)
	many.banner_texture = ImageTexture.create_from_image(image)
	poi_at_zero(many)
	check(host.header.image.texture == many.banner_texture and host.header.image.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Inspector banner uses aspect-preserving crop")
	check(Presentation.icon("gas_giant",host.get_theme_default_font(),true) == "[GAS]", "Reliable Android text fallback")
	check(Presentation.classification({"kind":"poi","poi":load("res://encounters/spatial_anomaly.tres")}) == "special", "Anomaly blue classification")
	check(Presentation.classification({"kind":"poi","poi":load("res://encounters/radiation_nebula.tres")}) == "hazard", "Hazard orange classification")
	# Existing ship comparison cards remain navigable and fit their children.
	host._exit()
	await settle()
	var setup = current_scene
	setup.showcase._stop_tween()
	setup.showcase._finish_intro()
	setup.showcase.logo.modulate.a = 0.0
	setup.showcase.phase = setup.showcase.Phase.SHIP_SELECTION
	setup._selection_ready()
	await process_frame
	for window_size in [Vector2i(1280,720),Vector2i(1280,480),Vector2i(686,384)]:
		root.size = window_size
		await settle()
		for index in range(preload("res://scripts/ships/ship_library.gd").PLAYERS.size()):
			setup._select(index)
			await settle()
			var panel = setup.get_node("Selection/Information")
			check(root.get_visible_rect().encloses(panel.get_global_rect()), "Ship information fits viewport")
			check(setup.get_node("Selection/Information/Margin/Scroll/Column/Identity/Stats").get_global_rect().end.y <= setup.deck_button.get_global_rect().position.y, "Statistics do not overlap actions")
		await screenshot("ships-%dx%d" % [window_size.x,window_size.y])
	setup.free()
	await process_frame
	print("Android layout checks: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)

