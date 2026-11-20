extends "res://tests/warzone_presentation_test.gd"


func run() -> void:
	root.size = Vector2i(1280, 720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 19
	host.star_system_settings = host.star_system_settings.duplicate()
	host.star_system_settings.departure_turn_duration = 0.1
	host.star_system_settings.departure_duration = 0.1
	host.star_system_settings.camera_duration = 0.1
	host.star_system_settings.white_fade_duration = 0.05
	root.add_child(host)
	host.state.defense.complete = true
	await host._jump()
	await settle()
	var map = host.star_map
	var hud = host.screen.overview_hud
	var operation: RefCounted = host.state.warzone
	var presentation = map.warzone_presentation
	check(map.visual_data.starless and not map.objects.has(-100) and not map.world.get_node("SunLight").visible
		and map.visual_root.has_node("SectorFill"), "Live Warzone map has sky and fill lighting without a sun")
	check(presentation.influence != null and presentation.influence_target.size() == 12
		and presentation.paths.get_surface_count() == 1, "One influence mesh and one lattice line batch")
	check(hud.war_effort_bar.visible and hud.lattice_button.visible and operation.engagement_count() == 2,
		"War Effort, lattice control and two opening engagements")
	var before_clock: int = operation.clock_ms
	await touch(hud.lattice_button)
	check(presentation.overlay_enabled and operation.clock_ms == before_clock,
		"Touch toggles route overlay without advancing simulation")
	await capture("lattice-overview")
	var before_influence: PackedVector4Array = presentation.influence_target.duplicate()
	var index: int = operation.HOSTILE_ROOT + operation.HOSTILE_GROUPS
	var point: Vector3 = operation.objectives[operation.HOSTILE_ROOT].position
	host.state.update_navigation_position(host.state.Defense.wire(point))
	host.state.arrive_destination(index)
	host.show_poi(index)
	host._warzone_operation(index, "sabotage")
	await settle()
	check(operation.disrupted.has(operation.HOSTILE_ROOT) and presentation.influence_target != before_influence,
		"Real sabotage updates territory and link presentation")
	check(hud.war_effort_bar.value > 0 and operation.effort > 0, "Operation updates graphical War Effort")
	host.show_system()
	root.size = Vector2i(960, 540)
	await settle()
	check(root.get_visible_rect().encloses(hud.lattice_button.get_global_rect()),
		"Overlay stays inside the Android landscape viewport")
	await capture("lattice-cutoff")
	host.free()
	await process_frame
	print("Warzone lattice presentation: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
