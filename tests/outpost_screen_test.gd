extends SceneTree
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func capture(name: String) -> void:
	for frame in range(12):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await create_timer(0.22).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
		root.get_texture().get_image().save_png(
			"res://.godot/testlogs/outpost-owned-" + name + ".png"
		)


func run() -> void:
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 789
	host.rules.log_rolls = false
	root.add_child(host)
	host.state.service = {"kind":"service", "poi":host.rules.trading_outpost, "title":"Trading Outpost", "completed":false}
	host.state.salvage = 100
	host.state.hull = host.state.ship().hull_capacity - 5
	host.show_outpost()
	var panel = host.outpost_screen
	var hull: int = host.state.hull
	for dimensions in [Vector2i(1280, 720), Vector2i(686, 384)]:
		root.size = dimensions
		await capture("services-%d" % dimensions.x)
		panel.select_service(0)
		panel.selector.value = 2
		await capture("confirmation-%d" % dimensions.x)
		panel.cancel_selection()
	panel.select_service(0)
	panel.selector.value = 2
	check(
		host.state.salvage == 100 and host.state.hull == hull,
		"Selection/preview never spends or repairs"
	)
	check(panel.preview.bar.preview_hull == hull + 2, "Component owns the quantity preview")
	panel.cancel_selection()
	panel.confirm_purchase()
	check(
		host.state.salvage == 100 and host.selected_approach == -1,
		"Cancellation clears selection and prevents purchase"
	)
	panel.select_service(0)
	panel.selector.value = 2
	host.state.service_revision += 1
	panel.confirm_purchase()
	check(
		host.state.salvage == 100 and host.state.hull == hull,
		"State rejects a confirmation made stale after selection"
	)
	host.show_outpost()
	var old = host.outpost_screen
	old.select_service(0)
	old.selector.value = 2
	host.show_outpost()
	check(old.get_parent() == null, "Old view detached before deferred deletion")
	old.purchase_requested.emit(0, 2, host.state.service_revision)
	old.selection_changed.emit(3)
	check(
		host.state.salvage == 100 and host.selected_approach == -1,
		"Replaced view cannot purchase or overwrite new selection"
	)
	old.confirm_purchase()
	check(host.state.salvage == 100, "Detached confirmation is inert")
	var active = host.outpost_screen
	active.select_service(0)
	active.selector.value = 2
	active.confirm_purchase()
	active.confirm_purchase()
	check(
		host.state.salvage == 98 and host.state.hull == hull + 2,
		"Active view purchases exactly once"
	)
	check(
		host.outpost_screen != active and host.outpost_screen.selected_slot == -1,
		"Successful purchase creates a fresh unselected view"
	)
	host.show_poi(0) if host.state.encounter_at(0).kind == "poi" else host.show_system()
	active.purchase_requested.emit(0, 1, host.state.service_revision)
	check(host.state.salvage == 98, "Navigation invalidates an old purchase request")
	host.free()
	await process_frame
	print("Outpost component: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
