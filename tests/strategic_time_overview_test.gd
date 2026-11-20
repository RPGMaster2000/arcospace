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
		"The overview immediately frames the sector and locks navigation")
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
	await check_defense()
	await check_disabled()
	print("Strategic time overview: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
