extends SceneTree
const Solar = preload("res://scripts/expedition/solar_regions.gd")
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for frame in range(12): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	check(root.get_texture().get_image().save_png("res://.godot/testlogs/solar-" + label + "-" + RenderingServer.get_current_rendering_method() + ".png") == OK, "Solar screenshot captured")
func run() -> void:
	root.size = Vector2i(1280,720)
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer has not fallen back")
	for mode in ["exploration","defense"]:
		var host = load("res://scenes/expedition.tscn").instantiate()
		host.persistence_enabled = false
		host.rules = host.rules.duplicate(true)
		host.rules.game_mode = mode
		host.rules.debug_seed = 1042
		host.rules.log_rolls = false
		root.add_child(host)
		await settle()
		var map = host.star_map
		var solar: Dictionary = host.state.environmental_instances[1]
		var index := -1
		var nearest := INF
		for i in range(host.state.encounters.size()):
			if host.state.encounters[i].kind != "battle" or not host.state.can_visit(i): continue
			var at: Array = host.state.battle_location(i)
			var distance := Vector3(at[0],at[1],at[2]).length()
			if distance < nearest:
				index = i
				nearest = distance
		check(index >= 0, "Available physical encounter for solar presentation")
		if index < 0:
			host.free()
			continue
		# Controlled overlap fixture: keep the star and encounter positions intact.
		# Only enlarge the region when necessary to exercise an incoming defense unit.
		solar.region.radius = maxf(float(solar.region.radius),nearest + 0.5)
		var asteroid: Dictionary = Asteroids.generate(7,1,[])[0]
		asteroid.position = host.state.battle_location(index)
		asteroid.region = {"shape":"pockets","angle":0.0,"half_height":1.0,
			"pockets":[{"offset":[0.0,0.0],"axes":[3.0,2.0],"angle":0.0}]}
		host.state.environmental_instances = [asteroid,solar]
		map.configured_seed = -1
		host.show_system()
		await settle()
		var visuals: Node3D = map.visual_root.get_node("SolarInterference")
		check(visuals.get_child_count() == 2 and not visuals.is_processing(), "Solar uses only two shader-animated meshes and no CPU animation")
		check(visuals.find_children("*","CollisionObject3D",true,false).is_empty() and visuals.find_children("*","Light3D",true,false).is_empty(), "Solar effects add no hitboxes or lights")
		check(visuals.position == map.objects[-100].position and is_equal_approx(float(map.objects[-100].material_override.get_shader_parameter("core_scale")) * Solar.CORE_RADIUS_PER_SCALE,float(solar.configuration.star_radius)), "Saved stellar position and visible scale anchor the influence")
		check(visuals.get_node("InfluenceBoundary").mesh.size == Vector2.ONE * float(solar.region.radius) * 2.08, "Faint boundary uses authoritative radius")
		check(is_equal_approx(float(visuals.get_node("Corona").material_override.get_shader_parameter("phase")),float(solar.visual.phase)), "Animation phase is deterministic saved visual data")
		check(is_equal_approx(map.world.get_node("SunLight").light_energy,map.settings.sunlight_energy), "Existing star lighting is unchanged")
		check(host.state.preview_modifier(index) == 3 and map.markers[index].tooltip_text.contains(Modifiers.NAMES[3]), "Map inspection selects existing Solar Flare over asteroid overlap")
		for i in map.markers:
			var marker = map.markers[i]
			if marker.visible and not marker.completed:
				var hit: Vector2 = marker.get_global_rect().get_center()
				if not map.point_is_reserved(hit) and map.nearest_marker(hit) == i:
					check(marker._has_point(hit-marker.global_position), "Solar meshes cannot obstruct existing PoI/touch targets")
		await capture(mode + "-overview")
		if mode == "exploration":
			map.camera.zoom_by(1.5)
			await create_timer(0.3).timeout
			await capture("corona-detail")
			map.camera.zoom_target = map.settings.default_zoom
			await create_timer(0.3).timeout
			root.size = Vector2i(960,540)
			await settle()
			await capture("compact")
			root.size = Vector2i(1280,720)
		else:
			var before: Dictionary = host.state.defense.snapshot()
			var ship: Vector3 = map.ship.position
			host._inspect_marker(index)
			check(host.inspecting and host.state.defense.snapshot() == before and map.ship.position == ship, "Existing inspection remains read-only with solar influence")
		host.show_battle_preview(index)
		var details = host.view.find_child("ModifierDetails",true,false)
		check(details.visible and details.text.contains(Modifiers.NAMES[3]), "Tactical briefing agrees on Solar Flare")
		var briefing = details.get_parent()
		details.pressed.emit()
		check(briefing._overlay.body.text.contains(Modifiers.description(3)), "Description is the unchanged existing Solar Flare description")
		briefing._overlay.dismiss()
		await settle()
		await capture(mode + "-briefing")
		if mode == "defense":
			host._dismiss_inspection()
			host.state.defense.contact = index # Controlled contact fixture; inspection alone cannot enter combat.
		host.start_battle(index,778899)
		check(is_instance_valid(host.battle), "Solar battle enters through existing lifecycle")
		if is_instance_valid(host.battle):
			host.battle.enemy_timer.stop()
			check(host.battle.modifier.kind == 3 and host.battle.battle_environment.type == Solar.TYPE, "Combat presentation agrees with map and briefing selection")
			check(host.battle.get_node("BattleView/Viewport/Battlefield").scene_file_path == "res://scenes/battlefield_solar_flare.tscn", "Existing Solar Flare combat arena reused")
			await settle()
			await capture(mode + "-battle")
		host.free()
		await process_frame
	print("Solar rendered integration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
