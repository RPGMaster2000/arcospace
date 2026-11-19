extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in 6: await process_frame


func touch(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()


func run() -> void:
	root.size = Vector2i(1280, 720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	root.add_child(host)
	host.state.defense.complete = true
	check(host.state.generate_system(), "Homeworld transition opens a Warzone")
	host.show_system()
	await settle()
	var hud = host.screen.overview_hud
	var map = host.star_map
	check(hud.metagame.text.contains("OBJECTIVES 1 / 2") and hud.wait_button.visible, "The map mounts the Warzone progress and wait controls")
	check(not hud.pressure_bar.visible, "Warzone uses an objective HUD")
	check(map.warzone_presentation.allies.size() == 2 and map.warzone_presentation.paths.get_surface_count() > 0,
		"The map presents allied groups and fleet routes")
	check(map.markers[5].objective_value == "Allied" and map.markers[6].objective_value == "Hostile",
		"Ownership is readable without color")
	check(not host.state.can_jump(), "The initial operation keeps FTL locked")
	var before: int = host.state.warzone.clock_ms
	await touch(hud.details_button)
	check(host.screen.system_details_overlay.shade.visible and host.state.warzone.clock_ms == before,
		"Opening the Warzone reports by touch consumes no strategic time")
	host.screen.system_details_overlay.dismiss()
	check(map.point_is_reserved(hud.wait_button.get_global_rect().get_center()), "The wait button reserves its hit area")
	await touch(hud.wait_button)
	check(host.state.warzone.clock_ms == before + host.state.warzone.tuning.wait_seconds * 1000,
		"An explicit touch wait advances the timeline")
	before = host.state.warzone.clock_ms
	map.travel(5)
	for attempt in 60:
		if host.view_kind == "poi": break
		await create_timer(0.05).timeout
	check(host.view_kind == "poi" and host.state.navigation_origin == 5,
		"Travel to the relay opens the objective panel through the normal map path")
	check(host.state.warzone.clock_ms > before, "Committed ship movement advances autonomous fleets")
	host.show_system()
	root.size = Vector2i(960, 540)
	await settle()
	check(root.get_visible_rect().encloses(hud.panels[1].get_global_rect()) and root.get_visible_rect().encloses(hud.panels[2].get_global_rect()),
		"Warzone controls fit a compact landscape viewport")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
		root.get_texture().get_image().save_webp("res://.godot/testlogs/warzone-%s.webp" % RenderingServer.get_current_rendering_method())
	host.free()
	await process_frame
	print("Warzone presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
