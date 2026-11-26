extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Convoy = preload("res://scripts/expedition/evacuation_convoy.gd")
const Details = preload("res://scripts/ui/system_details.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, description: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error(description)


func settle() -> void:
	for frame in 5: await process_frame


func click(at: Vector2, touch: bool) -> void:
	for pressed in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = at
			event.pressed = pressed
			root.push_input(event, true)
		else:
			var event := InputEventMouseButton.new()
			event.position = at
			event.pressed = pressed
			event.button_index = MOUSE_BUTTON_LEFT
			root.push_input(event, true)
		await process_frame


func run() -> void:
	var renderer := RenderingServer.get_current_rendering_method()
	var rendered := DisplayServer.get_name() != "headless"
	if rendered and not OS.get_cmdline_user_args().is_empty():
		check(renderer == OS.get_cmdline_user_args()[0], "Requested renderer initialized")
	root.size = Vector2i(960,540)
	var state := State.new()
	state.start(0, Rules, 39, {"mode":"defense", "stage":5, "rank":-1, "convoy_force_pursuit":true})
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state":state, "battle":{}}
	host.rules = Rules
	root.add_child(host)
	await settle()
	var map = host.star_map
	var convoy: RefCounted = state.defense.convoy
	var start: Vector3 = convoy.position()
	check(map.objects.has(Convoy.MARKER) and map.objects[Convoy.MARKER].visible, "Rendered evacuation transport")
	check(is_equal_approx(map.markers[Convoy.MARKER].fleet_strength, 1.0), "Convoy meter reflects exact integrity")
	check(map.convoy_route_visual.visible and map.convoy_route_visual.extraction_label.visible and map.convoy_route_visual.extraction_label.text == "EVAC BEACON", "Distinct route and extraction beacon")
	var hostile: Button = map.markers[convoy.pursuers.front()]
	check(hostile.tooltip_text.contains("Pursuing evacuation convoy") and hostile.has_meta("evacuation_pursuit"), "Pursuer has a visible badge and evacuation target")
	check(Details.text(state).contains("Integrity 40 / 40") and Details.text(state).contains("mandatory elite"), "System Details shows secondary objective and consequences")
	for size in [Vector2i(960,540), Vector2i(686,384)]:
		root.size = size
		await settle()
		map.fit_overview()
		await settle()
		var beacon := Rect2(Vector2.ZERO, Vector2(map.viewport.size))
		check(beacon.has_point(map.camera.unproject_position(convoy.destination())), "Extraction framed in landscape")
		var marker: Button = map.markers[Convoy.MARKER]
		var at := marker.get_global_rect().get_center()
		check(marker.visible and marker.tooltip_text.contains("40/40") and map.nearest_marker(at) == Convoy.MARKER, "Readable, selectable integrity marker")
		if rendered and size.x == 960:
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
			root.get_texture().get_image().save_webp("res://.godot/testlogs/convoy-%s.webp" % renderer, false, 0.8)
		await click(at, size.x < 960)
		await settle()
		check(host.inspecting and host.map_destination == Convoy.MARKER, "Pointer opens standard convoy inspection")
		check(convoy.position() == start and not state.navigation.leg_active, "Inspection leaves strategic simulation paused")
		var rendezvous: Button
		for button in host.view.find_children("*", "Button", true, false):
			if button.text == "Plot Rendezvous": rendezvous = button
		check(is_instance_valid(rendezvous) and rendezvous.is_visible_in_tree(), "Rendezvous available in inspection")
		if size.x < 960 and is_instance_valid(rendezvous):
			for attempt in 40:
				if host.screen.allows_activation(): break
				await create_timer(0.05).timeout
			rendezvous.pressed.emit()
			check(not host.inspecting and state.navigation.leg_active and state.travel_destination < 0, "Rendezvous requests normal navigation without attacking")
		else: host._dismiss_inspection()
	var player: Vector3 = state.defense.start
	map.apply_navigation_position(player)
	state.cancel_travel()
	host.phase = host.Phase.OVERVIEW
	state._advance_strategy(convoy.remaining_seconds() + 0.01, player, player, true)
	await settle()
	check(not convoy.traveling() and not map.objects[Convoy.MARKER].visible and not map.convoy_route_visual.visible and not map.convoy_route_visual.extraction_label.visible, "Resolved objective and beacon leave the map")
	host.queue_free()
	await create_timer(0.3).timeout
	print("Starfront convoy rendering: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
