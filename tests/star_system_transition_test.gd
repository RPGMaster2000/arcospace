extends SceneTree
const Save = preload("res://scripts/persistence/expedition_save.gd")
var failures := 0
var checks := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(12):
		await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/system3d-" + label + ".png")
func run() -> void:
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	await settle()
	var state = host.state
	var rng_before: int = state.rng.state
	for dimensions in [Vector2i(1280, 720), Vector2i(960, 540)]:
		root.size = dimensions
		host.show_system()
		await create_timer(0.9).timeout
		await settle()
		var map: Control = host.star_map
		check(map.size.y > 200, "Map has usable landscape height")
		for index in map.markers:
			var button: Button = map.markers[index]
			check(button.position.y+button.size.y<map.camera.unproject_position(map.objects[index].position).y, "Projected destination tag stays above its object without edge clamping")
			var plate: StyleBoxFlat = button.get_theme_stylebox("normal")
			check(plate.corner_radius_top_left > 0 and button.get_theme_font("font") == preload("res://assets/fonts/ArcospaceEmoji.ttf"), "Rounded tag uses native color emoji metrics")
			var anchor: Vector2 = button.position + button.get("anchor_point")
			check(anchor.is_equal_approx(map.camera.unproject_position(map.objects[index].position)), "Connector tracks projected destination")
			var claims := 0
			for other in map.markers:
				if map.markers[other]._has_point(anchor-map.markers[other].position): claims += 1
			check(claims==1,"Overlapping destination tags retain one unambiguous model tap")
			check(button._has_point(button.anchor_point),"Each destination model retains its own tap target")
			check(button._has_point(button.icon_center),"Each visible icon remains individually selectable")
		await capture("overview-%d" % dimensions.x)
		var heading: Rect2 = host.heading_row.get_global_rect()
		var bar: Rect2 = host.resource_bar.get_global_rect()
		host.map_destination = 0
		host.show_poi(0) if state.encounters[0].kind == "poi" else host.show_battle_preview(0)
		await create_timer(0.9).timeout
		await settle()
		var point: Vector2 = map.camera.unproject_position(map.objects[0].position)
		check(point.x < map.size.x * 0.48 and point.y > 0 and point.y < map.size.y, "Focus frames destination on left")
		check(host.screen.sidebar.size.x >= dimensions.x * (0.35 if host.view_kind == "poi" else 0.45), "Readable right-side panel")
		check(host.screen.compact_focus and not host.heading_row.visible and not host.resource_bar.visible, "Focus suspends the global HUD and uses the compact interaction panel")
		for index in map.markers:
			map.camera.focus(map.objects[index].position, map.settings)
			map.camera.motion.custom_step(2.0)
			var projected: Vector2 = map.camera.unproject_position(map.objects[index].position)
			check(projected.x > 0 and projected.x < map.size.x * 0.48 and projected.y > 0 and projected.y < map.size.y, "Every destination focus stays in left presentation area")
		map.camera.focus(map.objects[0].position, map.settings)
		map.camera.motion.custom_step(2.0)
		if state.encounters[0].kind == "poi":
			check(host.grid.columns == 1 and host.scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "Vertical approach list retains scrolling for overflow")
		await capture("focus-%d" % dimensions.x)
	check(state.rng.state == rng_before, "Visuals never consume gameplay RNG")
	host.show_system()
	await create_timer(0.9).timeout
	# Mouse and Android-style screen touch use the same projected hit region.
	host.star_map.travel_duration = 0.06
	var target: int = 0
	var center: Vector2 = host.star_map.global_position + host.star_map.camera.unproject_position(host.star_map.objects[target].position)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = center
		event.pressed = pressed
		root.push_input(event, true)
	await create_timer(0.15).timeout
	check(state.navigation_origin == target, "Touching the model still triggers arrival with its offset label")
	# Test FTL with real default choreography; duplicate requests cannot consume twice.
	state.pending_choice = ""
	state.pending_destination = -1
	state.travel_destination = -1
	state.chasedown_index = -1
	state.ftl_charge = state.required_ftl_charge
	host.show_system()
	var old_system: int = state.system_number
	host._jump()
	host._jump()
	check(host.transitioning and state.system_number == old_system, "FTL locks immediately before progression")
	var departure_origin: Vector3 = host.star_map.ship.position
	await create_timer(host.star_system_settings.departure_turn_duration * 0.5).timeout
	check(host.star_map.ship.position == departure_origin and host.star_map.camera.viewing == &"overview", "FTL turns in place before camera zoom")
	await create_timer(host.star_system_settings.departure_turn_duration * 0.5 + 0.05).timeout
	var view: Transform3D = host.star_map.camera.ship_view(departure_origin)
	var direction: Vector3 = (view.origin + view.basis.x * host.star_system_settings.departure_side_offset - departure_origin).normalized()
	check(host.star_map.ship.basis.x.normalized().dot(direction) > 0.999, "FTL turn completes before acceleration")
	await create_timer(1.0).timeout
	await capture("ftl-zoom")
	await create_timer(0.8).timeout
	await capture("ftl-departure")
	await create_timer(1.0 + host.star_system_settings.introduction_duration*1.1).timeout
	check(not host.transitioning and state.system_number == old_system + 1 and state.ftl_charge == 0, "FTL progresses exactly once")
	check(not host.transition.curtain.visible and host.star_map.visible, "White curtain clears onto new map")
	check(host.star_map.orbit_index == -1 and not host.star_map.traveling, "New system restores navigation")
	await capture("next-system")
	var enemy := -1
	for i in range(state.encounters.size()):
		if state.encounters[i].kind == "battle":
			enemy = i
			break
	check(enemy >= 0, "Generated system supplies enemy")
	host._enter_battle(enemy)
	host._enter_battle(enemy)
	await create_timer(1.0).timeout
	await capture("battle-white")
	await create_timer(0.7).timeout
	check(host.battle != null and state.active_battle == enemy, "Battle initialized with correct encounter")
	check(not host.transition.curtain.visible and not host.star_map.visible, "Curtain clears after battle initializes; map viewport sleeps")
	await capture("battle-revealed")
	# The existing serialization remains sufficient: no camera or animation state is saved.
	var data: Dictionary = Save.encode(state)
	check(data.has("system_number") and not data.has("camera"), "Save format stays presentation-independent")
	host.queue_free()
	await settle()
	print("Star system transitions: %d checks, %d failures" % [checks, failures])
	quit(failures)
