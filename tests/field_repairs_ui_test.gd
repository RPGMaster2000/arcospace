extends SceneTree
var host: Control
var failures: int = 0
var checks: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(10): await process_frame
func activate(control: Control, touch: bool = false) -> void:
	var location: Vector2 = control.get_global_rect().get_center()
	for pressed in [true,false]:
		if touch:
			var event = InputEventScreenTouch.new()
			event.index = 0
			event.position = location
			event.pressed = pressed
			root.push_input(event,true)
		else:
			var event = InputEventMouseButton.new()
			event.position = location
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
		await process_frame
	await settle()
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await create_timer(.22).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/field-repair-"+name+".png")
func run() -> void:
	host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 777
	root.add_child(host)
	for dimensions in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(686,384)]:
		root.size = dimensions
		var cap: int = host.state.ship().hull_capacity
		host.state.hull = cap-9
		host.state.salvage = 12
		host.show_system()
		await settle()
		var hull: Button = host.resource_bar.entries.hull
		check(host.resource_bar.heartbeat_active, "Damaged Hull warns on map")
		var size: Vector2 = hull.size
		host.resource_bar.pulse_elapsed = host.hull_pulse_period * .14
		host.resource_bar._process(0)
		check(hull.scale.x > 1 and hull.size == size and hull.modulate.g < 1, "Heartbeat tints/scales drawing without changing layout size")
		await activate(hull, dimensions.x == 960)
		var overlay = host.resource_bar.overlay
		check(overlay.shade.visible and overlay.extra.visible, "Mouse/touch opens existing Hull overlay with controls")
		check(overlay.body.text.contains("2 Salvage / Hull") and overlay.body.text.contains("Maximum affordable: 6"), "Accurate price and affordable quantity")
		host.field_repairs.selector.value = 4
		check(host.state.salvage == 12 and host.field_repairs.confirm.text.contains("8 Salvage"), "Selection previews exact cost without spending")
		check(host.field_repairs.preview.bar.preview_hull == cap-5 and host.field_repairs.preview.cost_text.text.contains("12 → 4") and host.field_repairs.preview.hull_text.text.contains("+4 Hull"), "Bar and balance connect selected gain to Salvage spending")
		await settle()
		check(root.get_visible_rect().encloses(overlay.panel.get_global_rect()), "Modal fits landscape")
		check(overlay.panel.get_global_rect().encloses(host.field_repairs.confirm.get_global_rect()) and host.field_repairs.confirm.size.y >= 48, "Confirm remains visible and touch sized")
		await capture(str(dimensions.x))
		await activate(host.field_repairs.confirm)
		check(host.state.hull == cap-5 and host.state.salvage == 4, "Confirm updates state immediately")
		check(host.resource_bar.entries.hull.text.contains(str(cap-5)) and host.resource_bar.entries.salvage.text.contains("4"), "HUD values refresh immediately")
		host.field_repairs.confirm.pressed.emit()
		check(host.state.salvage == 4 and host.field_repairs.confirm.disabled, "Repeated confirm cannot spend twice")
		overlay.dismiss()
		host.state.salvage = 100
		await activate(hull)
		await activate(host.field_repairs.confirm)
		check(host.state.hull == cap and not host.resource_bar.heartbeat_active and hull.scale == Vector2.ONE and hull.modulate == Color.WHITE, "Full Hull stops heartbeat immediately")
		check(host.field_repairs.confirm.disabled and overlay.body.text.contains("Hull full"), "Full Hull info remains; repairs disabled")
		overlay.dismiss()
		host.state.hull -= 1
		host.state.salvage = 0
		host.show_system()
		await settle()
		await activate(hull)
		check(host.resource_bar.heartbeat_active and host.field_repairs.confirm.disabled and overlay.body.text.contains("Requires at least 2"), "No Salvage keeps warning with clear unavailable reason")
		# Navigating into an encounter dismisses the same popup and blocks old callbacks.
		host.state.salvage = 100
		host.show_poi(0) if host.state.encounters[0].kind == "poi" else host.show_battle_preview(0)
		check(not overlay.shade.visible and not host.state.field_repairs_open and not host.resource_bar.heartbeat_active, "Encounter disables field repair and warning")
		host.field_repairs.confirm.pressed.emit()
		check(host.state.salvage == 100, "Old modal callback cannot spend inside encounter")
		# Same Outpost tile/selector changes to plating immediately when repairs complete.
		host.state.service = {"kind":"service","poi":host.rules.trading_outpost,"title":"Trading Outpost","completed":false}
		host.show_outpost()
		await settle()
		var position: Vector2 = host.approach_buttons[0].position
		check(host.approach_buttons[0].heading.text == "Repair Hull", "Station shows repair for damaged Hull")
		host._select_approach(0)
		host.repair_selector.value = 1
		host._confirm_approach()
		await settle()
		check(host.approach_buttons.size() == 4 and host.approach_buttons[0].heading.text == "Install Ablative Plating" and host.approach_buttons[0].position == position, "Same service location transitions to plating")
		host._select_approach(0)
		host.repair_selector.value = 4
		check(host.approach_note.text.contains("Cost 8") and host.approach_note.text.contains("plating"), "Station plating preview shows 2:1 cost")
		check(host.station_preview.visible and host.station_preview.bar.preview_hull == cap+4 and not host.approach_note.visible, "Shared plating preview replaces duplicate prose")
		await capture("plating-"+str(dimensions.x))
		host._confirm_approach()
		check(host.state.hull == cap+4, "Station installs selected plating")
		host.show_system()
		check(not host.resource_bar.heartbeat_active and host.resource_bar.entries.hull.get_node("Values/Base").get_theme_color("font_color") == Color(.78,.57,.28), "Above capacity uses amber and no pulse")
		host.state.hull = cap+10
		host.show_outpost()
		check(host.approach_buttons[0].disabled and host.approach_buttons[0].heading.text == "Ablative Plating Full", "Full plating keeps disabled tile in place")
		host.resource_bar.overlay.show_legend()
		check(not overlay.extra.visible, "Legend never retains repair controls")
		overlay.dismiss()
	# The extracted component must reject stale revisions and bind the newly restarted run.
	var previous_state: Resource = host.state
	var previous_hull: int = previous_state.hull
	var previous_salvage: int = previous_state.salvage
	host._restart()
	host.state.hull -= 2
	host.state.salvage = 4
	host.show_system()
	host._show_hull_info()
	check(host.field_repairs.preview.bar.preview_hull == host.state.ship().hull_capacity, "Restart binds repair preview to the new expedition")
	host.state.service_revision += 1
	host.field_repairs.confirm.pressed.emit()
	check(host.state.salvage == 4 and host.state.hull == host.state.ship().hull_capacity - 2, "Stale component confirmation cannot spend")
	host.field_repairs.selector.value = 1
	check(host.field_repairs.confirm.disabled, "Changing a stale selection disables confirmation")
	host._show_hull_info()
	host.field_repairs.confirm.pressed.emit()
	check(host.state.salvage == 0 and host.state.hull == host.state.ship().hull_capacity, "Reopened component confirms against the new revision")
	check(previous_state.hull == previous_hull and previous_state.salvage == previous_salvage, "Restarted repair controls never mutate the previous expedition")
	host.use_star_map = false
	host.state.hull = host.state.ship().hull_capacity - 2
	host.state.salvage = 4
	host.show_system()
	host._show_hull_info()
	host.field_repairs.confirm.pressed.emit()
	check(is_instance_valid(host.grid) and host.state.salvage == 0 and host.state.hull == host.state.ship().hull_capacity, "Original grid supports the same field repair entry point")
	host.queue_free()
	await process_frame
	print("Field repair UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
