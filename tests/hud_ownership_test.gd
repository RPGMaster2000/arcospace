extends SceneTree
var failures := 0
var checks := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle():
	await create_timer(0.28).timeout
	for i in range(12): await process_frame
func click(button: Button):
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = button.get_global_rect().get_center()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
func run():
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	await settle()
	var hud = host.screen.overview_hud
	var bar = host.resource_bar
	var identities: Array = bar.entries.values()
	var parents: Array = identities.map(func(button): return button.get_parent())
	var connections: Array = identities.map(func(button): return button.pressed.get_connections().size())
	var battle := -1
	var poi := -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind == "battle": battle = i
		else: poi = i
	var rng: int = host.state.rng.state
	for round_index in range(3):
		for index in [poi,battle]:
			host.map_destination = index
			if index == poi: host.show_poi(index)
			else: host.show_battle_preview(index)
			await settle()
			check(hud.mode == hud.Mode.FOCUS,"Screen requests explicit focus mode")
			check(identities.map(func(button): return button.get_parent()) == parents,"Focus never reparents resource controls")
			check(identities.map(func(button): return button.pressed.get_connections().size()) == connections,"Callbacks remain connected exactly once")
			await click(bar.entries.energy)
			check(bar.overlay.shade.visible,"Existing resource modal works while focus is active")
			bar.overlay.dismiss()
			host.show_system()
			await settle()
			check(hud.mode == hud.Mode.OVERVIEW,"Overview restores the same mounted controls")
	# Legacy/battle handoff restores original sizing, then mounts cleanly again.
	host.screen.hide_for_battle()
	await settle()
	check(not hud.active and bar.get_parent() != hud,"Hidden mode restores legacy owner")
	for button in identities:
		check(button.custom_minimum_size.y == 48,"Original resource minimum restored")
	host.show_system()
	await settle()
	check(hud.utilities.get_child_count() == 5,"Utility group has no duplicated zoom controls after remount")
	var previous: Array = hud.utilities.get_children().slice(3)
	host.star_map.free()
	host.star_map = null
	host.show_system()
	await settle()
	check(hud.utilities.get_child_count() == 5,"Replacing a map releases its borrowed zoom controls")
	check(previous.all(func(button): return not is_instance_valid(button)),"Old zoom actions are released with the map generation")
	check(host.state.rng.state == rng,"Ownership transitions do not change gameplay RNG")
	host.free()
	print("HUD ownership: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
