extends SceneTree
## Render the developer-selected late environments in the production expedition scene.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Variation = State.SystemVariation
var failures := 0
var checks := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)


func settle() -> void:
	for frame in 4: await process_frame


func run() -> void:
	var rendered := DisplayServer.get_name() != "headless"
	var method := RenderingServer.get_current_rendering_method()
	if rendered and not OS.get_cmdline_user_args().is_empty():
		check(method == OS.get_cmdline_user_args()[0], "Requested renderer initialized")
	var examples := Variation.ARCHETYPES + ["binary"] if "--capture-all" in OS.get_cmdline_user_args() else ["crowded", "binary"]
	for label in examples:
		var archetype: String = "asymmetric" if label == "binary" else label
		var config := {"mode":"defense","stage":5,"rank":-1,"environment":archetype,
			"seed":"214","binary":int(label == "binary")}
		if label == "binary": config.size_class = "Expansive"
		var state := State.new()
		state.start(0, Rules, 0, config)
		check(state.seed_used == 214 and state.system_variation.archetype == archetype, "Developer seed and archetype apply " + label)
		var host = load("res://scenes/expedition.tscn").instantiate()
		host.persistence_enabled = false
		host.play_system_intro = false
		host.resume_data = {"state":state, "battle":{}}
		host.rules = Rules
		root.size = Vector2i(960, 540)
		root.add_child(host)
		await settle()
		var map = host.star_map
		var model: MeshInstance3D = map.objects[-100]
		var multiplier: float = model.material_override.get_shader_parameter("core_scale")
		check(is_equal_approx(multiplier, float(state.system_variation.star_radius) / State.EnvironmentData.Solar.CORE_RADIUS_PER_SCALE),
			"Visible central radius follows committed class")
		var companion: Node3D = map.visual_root.get_node_or_null("VisualCompanionStar")
		check((companion != null) == (label == "binary"), "Binary visibility follows committed record")
		var radii := State.SystemLayout.planetary_radii(state.encounters, state.system_variation.planet_scales)
		for index in radii:
			var planet: Node3D = map.objects[index]
			check(planet.position.distance_to(state.defense.anchors[index]) < 0.001, "Rendered planet at authoritative destination")
			check(is_equal_approx(float(planet.get_meta("radius")) * 1.035, float(radii[index])),
				"Rendered planet matches clearance radius")
			check(map.visual_data.planets[map.visual_data.assignments[index]].type == state.system_variation.planet_types[str(index)],
				"Correct planetary PoI appearance")
		for dimensions in ([Vector2i(960, 540), Vector2i(686, 384)] if label == "binary" else [Vector2i(960, 540)]):
			root.size = dimensions
			await settle()
			map.fit_overview()
			var bounds := Rect2(Vector2.ZERO, Vector2(map.viewport.size))
			var visible := 0
			for index in state.defense.anchors:
				var point: Vector2 = map.camera.unproject_position(map.objects[index].position)
				check(bounds.has_point(point), "Fit projects the whole playable environment")
				visible += int(map.markers[index].visible)
			check(visible > 0, "Destination markers retained")
			if rendered and dimensions.x == 960:
				await RenderingServer.frame_post_draw
				var path := "res://.godot/testlogs/later-starfront"
				DirAccess.make_dir_recursive_absolute(path)
				root.get_texture().get_image().save_webp("%s/%s-%s.webp" % [path, method, label], false, 0.80)
		host.free()
		await process_frame
	print("Starfront environment rendering: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
