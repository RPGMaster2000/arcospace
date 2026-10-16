extends SceneTree
var failures: int = 0
var checks: int = 0
var host: Control

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 30: push_error(message)

func settle() -> void:
	for n in range(10): await process_frame

func geometry() -> void:
	var viewport: Rect2 = root.get_visible_rect()
	check(viewport.encloses(host.ui.get_global_rect()), "Station UI inside landscape viewport %s / %s" % [viewport, host.ui.get_global_rect()])
	check(viewport.encloses(host.return_button.get_global_rect()) and viewport.encloses(host.confirm_button.get_global_rect()), "Station Return and Confirm stay visible %s / %s" % [viewport, host.confirm_button.get_global_rect()])
	check(host.return_button.size.y >= 48 and host.confirm_button.size.y >= 48, "Fixed touch targets")
	check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Four services fit without unnecessary scrolling %s / %s" % [host.scroll.size, host.grid.size])
	for tile in host.approach_buttons:
		check(tile.size.y >= 84 and tile.get_global_rect().end.x <= host.scroll.get_global_rect().end.x + 1, "Service touch target fits")
		check(tile.details.get_global_rect().end.y <= tile.get_global_rect().end.y + 1, "Service description and price fit")
	if host.repair_selector.visible:
		check(viewport.encloses(host.repair_selector.get_global_rect()), "Repair selector visible")
		check(not host.repair_selector.get_global_rect().intersects(host.confirm_button.get_global_rect()), "Repair selector does not overlap confirmation")

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	host = load("res://scenes/expedition.tscn").instantiate()
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 789
	host.rules.log_rolls = false
	root.add_child(host)
	for ship_index in range(3):
		host.selected_ship = ship_index
		host.start_expedition()
		while host.state.service.is_empty():
			host.state.ftl_charge = host.state.required_ftl_charge
			host.state.generate_system()
		for window_size in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(960,540),Vector2i(1280,480),Vector2i(686,384)]:
			root.size = window_size
			host.state.salvage = 1000
			host.state.hull = host.state.ship().hull_capacity - 18
			host.show_outpost()
			await settle()
			check(host.approach_buttons.size() == 4 and host.resource_bar.entries.salvage.text.contains("1000"), "Four services and current balance shown")
			check(host.approach_buttons[3].details.text.contains(str(host.state.service_cost(3))), "Current escalating price shown")
			geometry()
			var ftl: int = host.state.ftl_charge
			var required: int = host.state.required_ftl_charge
			host.approach_buttons[0].pressed.emit()
			check(host.repair_selector.visible and host.confirm_button.disabled, "Zero repair cannot confirm")
			host.confirm_button.pressed.emit()
			check(host.state.salvage == 1000, "Disabled zero confirmation never spends")
			host.repair_selector.value = 12
			await settle()
			check(not host.confirm_button.disabled and host.approach_note.text.contains("Cost 12") and host.approach_note.text.contains(str(host.state.hull + 12)), "Selected repair amount, resulting Hull and exact cost previewed")
			geometry()
			host.confirm_button.pressed.emit()
			host.confirm_button.pressed.emit()
			check(host.state.salvage == 988 and host.state.hull == host.state.ship().hull_capacity - 6 and host.view_kind == "poi", "Single repair confirmation; direct station refresh")
			check(host.resource_bar.entries.salvage.text.contains("988") and host.confirm_button.disabled, "Balance refreshed; new selection required")
			# Repeat every service without leaving the menu; old choice controls cannot fire twice.
			for slot in [0,1,2,3,1,2,3]:
				var price: int = host.state.service_cost(slot, 1)
				var balance: int = host.state.salvage
				var material_bonus: int = host.state.modifier_value("materials")
				var card_count: int = host.state.acquired_cards.size()
				host.approach_buttons[slot].pressed.emit()
				if slot == 0: host.repair_selector.value = 1
				host.confirm_button.pressed.emit()
				host.confirm_button.pressed.emit()
				if slot > 0:
					check(host.view_kind == "outcome" and not host.state.pending_choice.is_empty(), "Paid choice presented before another purchase")
					var stale_choice: Button = host.grid.get_child(0)
					stale_choice.pressed.emit()
					stale_choice.pressed.emit()
				check(host.state.salvage == balance - price and host.view_kind == "poi" and host.state.pending_choice.is_empty(), "Each service spends once and returns to station")
				if slot == 1: check(host.state.modifier_value("materials") == material_bonus + 5, "UI supplies add five exactly once")
				if slot == 2: check(host.state.acquired_cards.size() == card_count + 1, "UI acquisition adds one card exactly once")
			check(host.state.ftl_charge == ftl and host.state.required_ftl_charge == required, "All UI purchases preserve travel accounting")
			host.return_button.pressed.emit()
			check(host.view_kind == "system" and host.state.can_visit(host.state.SERVICE_INDEX), "Return leaves station revisitable")
			host.visit(host.state.SERVICE_INDEX)
			check(host.view_kind == "poi", "Revisit available station")
			host.state.salvage = 0
			host.show_outpost()
			await settle()
			for button in host.approach_buttons: check(button.disabled and button.details.text.contains("LOCKED"), "Broke services show locked reason")
			geometry()
			host.return_button.pressed.emit()
			check(host.view_kind == "system", "Zero-Salvage departure remains free")
	host.free()
	await process_frame
	print("Trading Outpost UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
