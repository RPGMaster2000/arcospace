extends "res://tests/warzone_presentation_test.gd"

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Launch = preload("res://scripts/expedition/developer_launch.gd")
const Expedition = preload("res://scenes/expedition.tscn")


func fresh(mode: String) -> State:
	var rules := Rules.duplicate()
	rules.warzone_tuning = rules.warzone_tuning.duplicate()
	rules.warzone_tuning.wait_seconds = 10
	var state := State.new()
	state.start(0, rules, 19, Launch.configuration(mode, 1, -1) if mode == "warzone" else {})
	return state


func mount(state: State, store = null) -> Control:
	var host := Expedition.instantiate()
	host.persistence_enabled = store != null
	if store != null: host.save_store = store
	host.resume_data = {"state": state}
	host.play_system_intro = false
	host.star_system_settings = host.star_system_settings.duplicate()
	host.star_system_settings.camera_duration = 0.08
	# Use deterministic state and a short camera animation, with real map controls.
	root.add_child(host)
	return host


func check_warzone(wall_clock: bool) -> void:
	var baseline := fresh("warzone")
	check(baseline.wait_in_warzone(), "Instant reference accepts the same Wait action")
	var state := fresh("warzone")
	var host := mount(state)
	await settle()
	var display = host.strategic_overview
	var camera = host.star_map.camera
	camera.pan_offset += Vector2(3, 2)
	camera.zoom_by(1.18)
	await settle()
	var before: Transform3D = camera.transform
	var pan: Vector2 = camera.pan_offset
	host._wait_in_warzone()
	check(display.active and state.warzone.clock_ms == 0 and display.activity.duration == 10.0,
		"Accepting Wait cuts to the system before spending strategic time")
	check(camera.viewing == &"strategic_time" and camera.transform != before and not host.star_map.interactive,
		"The overview immediately frames the battlefield and locks navigation")
	check(root.get_visible_rect().encloses(display.progress.get_global_rect()), "Progress bar fits a narrow landscape viewport")
	var time_used := 0.0
	if wall_clock:
		var start := Time.get_ticks_usec()
		await create_timer(0.35, false, false, true).timeout
		var wall_seconds := (Time.get_ticks_usec() - start) / 1000000.0
		time_used = display._clock
		check(absf(display.progress.value - wall_seconds) < 0.25 and display.progress.value > 0.15,
			"Live overview runs at one strategic second per real second")
	else:
		display.advance(0.4)
		time_used = 0.4
	display.set_process(false)
	check(state.warzone.clock_ms > 0 and state.warzone.clock_ms < 1000,
		"The battle clock is incremental while the progress bar is visible")
	display.advance(9.99 - time_used)
	check(display.activity != null and state.warzone.clock_ms < 10000, "Ten seconds cannot settle early")
	host._wait_in_warzone() # Repeated input while the first action is unresolved.
	display.advance(0.06)
	check(display.active and display.activity == null and state.warzone.clock_ms == 10000,
		"Exactly ten strategic seconds finish before camera return")
	var during_return: int = state.warzone.clock_ms
	await display.finished
	check(state.warzone.clock_ms == during_return and state.warzone.snapshot() == baseline.warzone.snapshot(),
		"The camera return spends no time and visible/instant Wait have identical results")
	check(camera.pan_offset == pan and camera.transform.is_equal_approx(before), "Return restores camera pan and orientation")
	host.queue_free()
	await process_frame


func check_inspection() -> void:
	var state := fresh("warzone")
	var host := mount(state)
	await settle()
	var index: int = state.warzone.HOSTILE_ROOT + state.warzone.HOSTILE_GROUPS
	host._inspect_marker(index)
	await settle()
	var titles: Array[Node] = host.view.find_children("*", "Label", true, false).filter(
		func(label): return label.text == "Hostile Command")
	check(titles.size() == 1, "Inspection displays the original Hostile Command title")
	if not titles.is_empty():
		var title := titles[0] as Label
		for resolution in [Vector2i(960, 540), Vector2i(1344, 576), Vector2i(1280, 720)]:
			root.size = resolution
			await settle()
			var single_line := title.get_theme_font("font").get_string_size(title.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size"))
			check(title.size.x >= single_line.x and title.get_line_count() == 1
				and title.get_parent().get_global_rect().encloses(title.get_global_rect()),
				"Hostile Command uses the inspection row at %s" % resolution)
		title.text = "Long Hostile Command title for natural word wrapping at narrow viewport sizes"
		await settle()
		check(title.get_line_count() > 1 and title.get_line_count() <= title.text.split(" ").size(),
			"Long headings wrap by words in the inspection column")
		title.text = "Hostile Command"
		await capture("warzone-inspection")
	host._dismiss_inspection()
	await create_timer(0.26).timeout
	var key: int = host.star_map.WARZONE_ALLY_MARKER_BASE
	host._inspect_marker(key)
	await settle()
	var names: Array[Node] = host.view.find_children("*", "Label", true, false).filter(
		func(label): return label.text.begins_with("Allied Vanguard"))
	check(names.size() == 1 and names[0].get_line_count() == 1, "Fleet inspection uses the same horizontal layout")
	host.queue_free()
	await process_frame


func check_battlefield_framing() -> void:
	root.size = Vector2i(960, 540)
	var state := fresh("warzone")
	var operation: RefCounted = state.warzone
	# Two genuine contacts well apart. Distant formations and scenery must
	# not expand the frame for the selected contact.
	for i in operation.fleets.size():
		operation.fleets[i].position = Vector3(48.0 + i * 5.0, 0, 31.0)
	for pair in [[0, 2, Vector3(-20, 0, -4)], [1, 3, Vector3(24, 0, -4)]]:
		operation.fleets[pair[0]].position = pair[2]
		operation.fleets[pair[1]].position = pair[2] + Vector3(1.2, 0, 0)
	var host := mount(state)
	await settle()
	var display = host.strategic_overview
	var camera: Camera3D = host.star_map.camera
	host._wait_in_warzone()
	display.set_process(false)
	var id: int = display._framing._anchor
	check(id in [2, 3], "The hard cut prioritizes one of the actual engagements")
	var contact: Dictionary = operation.fleets[id]
	var ally: Dictionary = operation.fleets[contact.engaged]
	var other: Vector3 = operation.fleets[5 - id].position
	check(_in_frame(display, camera, contact.position) and _in_frame(display, camera, ally.position),
		"Both participants fit in the HUD-safe view immediately")
	check(not _in_frame(display, camera, other), "A separate distant engagement does not zoom out the view")
	await settle()
	check(host.star_map.warzone_presentation.fx.emitted_beams > 0, "NPC beams still display during the overview")
	await capture("strategic-battlefield")
	var before := camera.global_position
	var movement := camera.global_basis.x * 6.0
	contact.position += movement
	ally.position += movement
	display._framing.update(host.star_map, display.framing_bounds, 0.2)
	check(camera.global_position.distance_to(before) > 0.3 and camera.global_position.distance_to(before) < 5.0,
		"Camera tracking applies only part of the new target displacement per update")
	for frame in 24:
		display._framing.update(host.star_map, display.framing_bounds, 0.1)
	check(_in_frame(display, camera, contact.position) and display._framing._anchor == id,
		"The camera follows the same engagement and recovers its margins")
	for fleet in operation.fleets: fleet.strength = 0
	for frame in 24:
		display._framing.update(host.star_map, display.framing_bounds, 0.1)
	check(_in_frame(display, camera, host.star_map.ship.position), "No-hostile fallback keeps the player visible")
	display.finish_immediately()
	host.queue_free()
	await process_frame


func _in_frame(display: CanvasLayer, camera: Camera3D, point: Vector3) -> bool:
	var size := camera.get_viewport().get_visible_rect().size
	return not camera.is_position_behind(point) and display.framing_bounds().has_point(camera.unproject_position(point) / size)


func check_defense() -> void:
	var state := fresh("defense")
	var baseline := fresh("defense")
	var site := -1
	for index in state.encounters.size():
		if state.encounters[index].kind == "poi" and not state.poi_approaches(index).is_empty() \
			and state.locked_reason(state.poi_approaches(index)[0]).is_empty():
			site = index
			break
	check(site >= 0, "Seed provides a valid guaranteed PoI")
	if site < 0: return
	var anchor := State.Defense.wire(state.defense.anchors[site])
	for candidate in [state, baseline]:
		candidate.update_navigation_position(anchor)
		candidate.arrive_destination(site)
	baseline.resolve_approach(site, 0)
	var store := Save.new()
	store.path = "user://strategic-time-overview-test.json"
	store.clear_run()
	check(store.save_run(state), "Normal checkpoint written before a timed action")
	var host := mount(state, store)
	host.show_poi(site)
	await settle()
	var display = host.strategic_overview
	var pressure: float = state.defense.pressure
	var commits: Array[Dictionary] = []
	state.defense_advanced.connect(func(events): commits.append(events))
	var unit: Dictionary = state.defense.units[0]
	var before: Vector3 = unit.position
	host._approach(site, 0)
	check(display.active and state.last_poi_success == -1 and state.defense.pressure == pressure,
		"Guaranteed reward stays pending after the camera cut")
	display.set_process(false)
	display.advance(0.75)
	check(state.defense.pressure > pressure and not before.is_equal_approx(unit.position),
		"Defense pressure and enemy world positions advance during the overview")
	check(state.last_poi_success == -1 and FileAccess.file_exists(store.path) and commits.is_empty(),
		"Intermediate updates do not publish a completed span or grant the reward")
	await capture("strategic-time")
	host.notification(NOTIFICATION_APPLICATION_PAUSED)
	check(not display.active and state.last_poi_success == 1, "Suspension settles a confirmed action exactly once")
	check(commits.size() == 1 and is_equal_approx(commits[0].elapsed,
		float(state.poi_approaches(site)[0].get_meta("strategic_seconds"))),
		"The live span publishes one aggregate time event")
	check(Save.encode(state) == Save.encode(baseline), "Interrupted presentation matches instant PoI resolution")
	var loaded: Resource = store.load_run().get("state")
	check(loaded != null and loaded.last_poi_success == state.last_poi_success and loaded.salvage == state.salvage
		and loaded.encounters[site].completed and is_equal_approx(loaded.defense.pressure, state.defense.pressure),
		"Resume retains the completed encounter, pressure and reward from the settled checkpoint")
	if loaded != null:
		var restored_position := State.Defense.point(loaded.navigation.position)
		check(restored_position.is_equal_approx(State.Defense.point(anchor)), "Resume restores the original PoI position")

	state._commit_activity_time(0.5)
	check(not display.active, "Combat's direct strategic-time commit bypasses the overview")
	host.queue_free()
	await process_frame
	store.clear_run()


func check_disabled() -> void:
	var state := fresh("warzone")
	var host := mount(state)
	await settle()
	host.settings_button.menu.present()
	var toggle: CheckButton = host.settings_button.menu.strategic_time_toggle
	check(toggle.button_pressed, "Settings reflects the persisted overview preference")
	toggle.button_pressed = false
	host.settings_button.menu.dismiss()
	host._wait_in_warzone()
	check(not host.strategic_overview.active and state.warzone.clock_ms == 10000,
		"Turning the setting off resolves the full cost immediately")
	host.queue_free()
	await process_frame
	Preferences.set_strategic_time_overview(true)


func run() -> void:
	root.size = Vector2i(960, 540)
	check(Preferences.strategic_time_overview(), "Strategic Time Overview is enabled by default")
	check(Preferences.set_strategic_time_overview(false) == OK and not Preferences.strategic_time_overview(),
		"Disabled preference roundtrips through the existing settings file")
	check(Preferences.set_strategic_time_overview(true) == OK and Preferences.strategic_time_overview(),
		"Enabled preference roundtrips through the existing settings file")
	await check_warzone(true)
	await check_inspection()
	await check_battlefield_framing()
	await check_defense()
	await check_disabled()
	print("Strategic time overview: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
