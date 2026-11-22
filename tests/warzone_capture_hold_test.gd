extends "res://tests/strategic_time_overview_test.gd"


func run() -> void:
	root.size = Vector2i(960, 540)
	var state := State.new()
	state.start(0, Rules, 19)
	state.defense.complete = true
	state.generate_system()
	var op = state.warzone
	var site: int = op.site("junction")
	var index: int = site + op.HOSTILE_GROUPS
	var point: Vector3 = op.objectives[site].position
	for fleet in op.fleets:
		fleet.strength = 0
		fleet.engaged = -1
	state._sync_warzone()
	state.navigation.checkpoint_position(State.Defense.wire(point))
	state.navigation_origin = index
	var host := mount(state)
	host.show_poi(index)
	await create_timer(0.30).timeout
	var hold := _hold_button(host)
	check(hold != null and op.clock_ms == 0, "Eligible hostile station offers Hold Until Captured before time advances")
	if hold == null:
		host.free()
		quit(1)
		return
	await touch(hold)
	check(host.capture_hud.blocker.visible and not host.strategic_overview.active and not host._map_input_allowed(),
		"Touch starts the capture HUD and locks navigation on the live map")
	check(root.get_visible_rect().encloses(host.capture_hud.cancel_button.get_global_rect()),
		"Cancel Hold fits a 960×540 touch viewport")
	var wall_start := Time.get_ticks_usec()
	var clock_start: int = op.clock_ms
	await create_timer(0.30, false, false, true).timeout
	var wall_ms := (Time.get_ticks_usec() - wall_start) / 1000.0
	check(absf(op.clock_ms - clock_start - wall_ms) < 150.0 and op.clock_ms > clock_start,
		"Live capture time advances at the real wall-clock rate")
	host.set_process(false)
	host._advance_capture_hold(1.0)
	check(op.objectives[site].progress == 1 and host.capture_hud.progress.value == 1
		and State.Defense.point(state.navigation.position) == point, "Existing capture ticks update the HUD without moving the ship")
	await capture("capture-hold")
	await touch(host.capture_hud.cancel_button)
	var stopped: int = op.clock_ms
	host._advance_capture_hold(100.0)
	check(op.clock_ms == stopped and op.objectives[site].progress == 1
		and host._capture_hold < 0 and not state.navigation.leg_active, "Cancelling preserves progress and spends no further time")
	await create_timer(0.30).timeout
	check(host._map_input_allowed() and host.screen.overview_hud.wait_button.visible, "Cancellation restores navigation and universal Wait")
	var encoded := Save.encode(state)
	var restored := Save.new().decode(encoded, state.rules)
	check(restored != null and restored.warzone.clock_ms == stopped and restored.warzone.objectives[site].progress == 1,
		"Save data retains committed progress and the exact stopped clock")
	host.free()
	await process_frame

	if restored == null:
		quit(1)
		return
	host = mount(restored)
	host.set_process(false)
	op = restored.warzone
	check(host._capture_hold < 0 and not host.capture_hud.blocker.visible, "Resume leaves automatic capture stopped")
	host.show_poi(index)
	await create_timer(0.30).timeout
	host._start_capture_hold(index)
	var cut: int = op.root("allied")
	op.disrupted[cut] = 6
	op._refresh_supply()
	host._advance_capture_hold(2.0)
	check(host._capture_hold < 0 and op.clock_ms == stopped and op.objectives[site].progress == 0
		and host.capture_hud.notice_label.text.contains("Supply disconnected"), "Supply loss cancels the capture and its hold immediately")
	op.disrupted.clear()
	op.capture_cutoffs.clear() # Simulate leaving and re-entering after reconnection.
	op._refresh_supply()
	op.objectives[site].owner = "neutral"
	host.show_poi(index)
	await create_timer(0.30).timeout
	check(_hold_button(host) != null, "Eligible neutral objective offers Hold Until Captured")
	host._start_capture_hold(index)
	var hostile: Dictionary = op.fleets[2]
	hostile.strength = 4
	hostile.at = site
	hostile.destination = site
	hostile.position = point + Vector3(op.tuning.objective_radius + 0.03, 0, 0)
	var step: int = op.motion_step_ms()
	var next_tick := stopped - posmod(stopped, step) + step
	host._advance_capture_hold(1.0)
	check(host._capture_hold < 0 and op.clock_ms == next_tick and host.capture_hud.notice_label.text.contains("contested"),
		"A hostile moving into capture range interrupts at the first affected simulation tick")
	stopped = op.clock_ms
	hostile.strength = 0
	host.show_poi(index)
	await create_timer(0.30).timeout
	host._start_capture_hold(index)
	host.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	host._advance_capture_hold(6.0)
	host.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(host._capture_hold < 0 and op.clock_ms == stopped, "Android suspension stops hold without catch-up")
	host.show_poi(index)
	await create_timer(0.30).timeout
	host._start_capture_hold(index)
	host._advance_capture_hold(99.0)
	check(op.objectives[site].owner == "allied" and op.clock_ms == stopped - posmod(stopped, 1000) + op.tuning.capture_seconds * 1000
		and host._capture_hold < 0, "Hold completes through normal capture and stops at the exact completion tick")
	host.show_poi(index)
	check(_hold_button(host) == null, "Allied stations never offer Hold Until Captured")
	host.free()
	await process_frame
	print("Warzone capture hold: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))


func _hold_button(host: Control) -> Button:
	for node in host.view.find_children("*", "Button", true, false):
		if node.text == "Hold Until Captured": return node
	return null
