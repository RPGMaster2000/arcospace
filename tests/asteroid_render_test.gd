extends SceneTree
## Production map + arena wiring, with screenshots in the existing CI artifacts.
const Regions = preload("res://scripts/expedition/asteroid_regions.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1280,720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.game_mode = "exploration"
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	for frame in range(12): await process_frame
	var map = host.star_map
	var fields: Node3D = map.visual_root.get_node("AsteroidFields")
	check(fields.get_child_count() == host.state.environmental_instances.size() and fields.get_child_count() == 1, "Map renders exactly one formation")
	check(map.selection_rings.size() == map.markers.size(), "Every selectable PoI has one world-plane ring")
	for i in map.selection_rings:
		var ring = map.selection_rings[i]
		var marker = map.markers[i]
		check(ring.rotation == Vector3.ZERO and ring.position.y < map.objects[i].position.y, "Ring lies beneath PoI on system plane")
		marker._set_hovered(true)
		ring.sync(marker, map.objects[i])
		check(ring.emphasized, "Ring reuses existing hover state")
		marker._set_hovered(false)
	check(fields.find_children("*","CollisionObject3D",true,false).is_empty(), "Scenery has no raycast blockers")
	var index := -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind != "battle": continue
		var at: Array = host.state.battle_location(i)
		check(map.objects[i].position.is_equal_approx(Vector3(at[0],at[1],at[2])), "Visible marker equals authoritative evaluator location")
		if host.state.preview_modifier(i) == 1: index = i
	check(index >= 0, "Generated belt intersects an actual battle")
	# Rebuild the production map for each formation without combining fixtures.
	var seen := {}
	var anchors: Array = host.state.encounter_positions.values()
	for seed_value in range(64):
		var candidate: Array = Regions.generate(seed_value, 1, anchors)
		var kind: String = candidate[0].configuration.subtype
		if seen.has(kind): continue
		seen[kind] = true
		host.state.environmental_instances = candidate
		map.configured_seed = -1
		host.show_system()
		for frame in range(4): await process_frame
		var exclusions: Array = [{"position": Vector3.ZERO, "radius": 1.26 * map.settings.sun_core_scale}]
		for planet in map.planet_nodes.values():
			exclusions.append({"position": planet.position, "radius": float(planet.get_meta("radius")) * 1.035})
		for i in map.markers:
			exclusions.append({"position": map.objects[i].position, "radius": float(map.objects[i].get_meta("radius",0.65))})
		var scenery: MultiMesh = map.visual_root.get_node("AsteroidFields").get_child(0).multimesh
		check(scenery.instance_count > 50, "Celestial clearance retains visible " + kind)
		if DisplayServer.get_name() != "headless":
			for rock in range(scenery.instance_count):
				var transform: Transform3D = scenery.get_instance_transform(rock)
				var scale: Vector3 = transform.basis.get_scale()
				check(preload("res://scripts/presentation/star_system/asteroid_fields.gd").clear_position(transform.origin,maxf(scale.x,maxf(scale.y,scale.z))-0.00001,exclusions), "Rendered mesh clears every celestial body: " + kind)
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
			var renderer: String = RenderingServer.get_current_rendering_method()
			check(root.get_texture().get_image().save_png("res://.godot/testlogs/asteroid-" + kind + "-" + renderer + ".png") == OK, "Formation and PoI marker screenshot captured")
		if seen.size() == 3: break
	check(seen.size() == 3, "Production map renders all three formation types")
	# Choose an actual contained battle in the final fixture for arena entry.
	index = -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind == "battle" and host.state.preview_modifier(i) == 1: index = i
	if index >= 0:
		host.map_destination = index
		host.show_battle_preview(index)
		check(host.view.find_child("ModifierDetails",true,false).visible, "Tactical briefing shows existing Asteroid Belt details")
		host.start_battle(index, 98765)
		check(is_instance_valid(host.battle), "Spatial battle enters through production lifecycle")
		if is_instance_valid(host.battle):
			host.battle.enemy_timer.stop()
			check(host.battle.modifier.kind == 1, "Existing modifier 1 selected")
			check(host.battle.get_node("BattleView/Viewport/Battlefield").scene_file_path == "res://scenes/battlefield_asteroid_belt.tscn", "Existing combat arena reused")
	host.free()
	print("Asteroid rendered integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
