extends SceneTree
var failures: int = 0
var checks: int = 0
var host: Control
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 25: push_error(message)
func settle() -> void:
	for n in range(16): await process_frame
func fit(context: String) -> void:
	var safe: Rect2 = root.get_visible_rect().grow(-23)
	for button in host.resource_bar.entries.values():
		check(safe.encloses(button.get_global_rect()), "Safe edge padding: " + context)
		for label in button.get_node("Values").get_children():
			if not label.text.is_empty(): check(button.get_global_rect().encloses(label.get_global_rect()), "Value fully contained: " + context)
	check(host.resource_bar.entries.size() == 7, "Only seven combined indicators")
	check(safe.encloses(host.jump_button.get_global_rect()), "Bottom control padded")
	check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "No unnecessary scrollbar: " + context + " viewport=%s grid=%s" % [host.scroll.size, host.grid.size])
	check(host.scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "No horizontal scrolling")
func screenshot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/dark-" + name + ".png")
func run() -> void:
	host = load("res://scenes/expedition.tscn").instantiate()
	host.use_star_map = false # Keep coverage of the preserved grid presentation.
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 789
	host.rules.log_rolls = false
	root.add_child(host)
	current_scene = host
	for viewport_size in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(1680,720), Vector2i(2400,1080), Vector2i(686,384)]:
		root.size = viewport_size
		for mode in ["ordinary", "all penalties", "extreme mixed"]:
			host.state.pending_bonuses.clear()
			host.state.pending_penalties.clear()
			host.state.production_upgrades.clear()
			if mode != "ordinary":
				for key in ["materials", "energy", "crew", "shields"]:
					host.state.add_modifiers({key:-999999})
					if mode == "extreme mixed": host.state.add_modifiers({key:999999})
				host.state.add_modifiers({"emp_pulse_charge":999999, "emp_pulse_offline":999999})
				if mode == "extreme mixed":
					for key in host.state.PRODUCTION: host.state.production_upgrades[key] = 999
			host.show_system()
			await settle()
			fit("system %s %s" % [viewport_size, mode])
			await screenshot("system-%d-%s" % [viewport_size.x, mode.replace(" ", "-")])
			for poi in host.rules.pois:
				host.state.encounters[0] = {"kind":"poi", "poi":poi, "title":poi.title, "completed":false}
				host.show_poi(0)
				await settle()
				fit("%s %s %s" % [poi.title, viewport_size, mode])
				check(safe_controls(), "Padded Return and Confirm")
				if poi.resource_path.ends_with("mining_operation.tres"):
					await screenshot("poi-%d-%s" % [viewport_size.x, mode.replace(" ", "-")])
			host.state.service = {"kind":"service", "poi":host.rules.trading_outpost, "title":"Trading Outpost", "completed":false}
			host.state.salvage = 999999
			host.show_outpost()
			await settle()
			fit("Trading Outpost %s %s" % [viewport_size, mode])
			host.resource_bar.entries.energy.pressed.emit()
			await settle()
			var overlay = host.resource_bar.overlay
			check(root.get_visible_rect().grow(-23).encloses(overlay.panel.get_global_rect()), "Description padded")
			check(overlay.body.text.contains("[b]Reactor[/b]") and overlay.body.text.contains("[b]Next battle[/b]"), "Concise visual description retains meaning")
			check(not host.resource_bar.entries.energy.tooltip_text.contains("[b]"), "Tooltip has no raw markup")
			await screenshot("detail-%d-%s" % [viewport_size.x, mode.replace(" ", "-")])
			overlay.dismiss()
	host.free()
	await process_frame
	print("Crowded bar checks: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func safe_controls() -> bool:
	var safe: Rect2 = root.get_visible_rect().grow(-23)
	return safe.encloses(host.return_button.get_global_rect()) and (not host.confirmation.shade.visible or safe.encloses(host.confirm_button.get_global_rect()))
