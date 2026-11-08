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
	# Include a generated localized field in this visual fixture even when the
	# chosen system naturally rolls zero. Production counts remain unchanged.
	if host.state.environmental_instances.size() == 1:
		for seed_value in range(64):
			var candidate: Array = Regions.generate(seed_value, 1, [])
			if candidate.size() > 1:
				host.state.environmental_instances.append(candidate[1])
				break
		host.star_map.configured_seed = -1
		host.show_system()
	for frame in range(12): await process_frame
	var map = host.star_map
	var fields: Node3D = map.visual_root.get_node("AsteroidFields")
	check(fields.get_child_count() == host.state.environmental_instances.size() and fields.get_child_count() > 1, "Map renders belt and localized field")
	check(fields.find_children("*","CollisionObject3D",true,false).is_empty(), "Scenery has no raycast blockers")
	var index := -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind != "battle": continue
		var at: Array = host.state.battle_location(i)
		check(map.objects[i].position.is_equal_approx(Vector3(at[0],at[1],at[2])), "Visible marker equals authoritative evaluator location")
		if host.state.preview_modifier(i) == 1: index = i
	check(index >= 0, "Generated belt intersects an actual battle")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
		var renderer: String = RenderingServer.get_current_rendering_method()
		check(root.get_texture().get_image().save_png("res://.godot/testlogs/asteroid-fields-" + renderer + ".png") == OK, "Generated field screenshot captured")
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
