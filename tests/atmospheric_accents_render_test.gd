extends SceneTree
## Production expedition, stable saved recipes, real renderer pixels and comparisons.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Accents = preload("res://scripts/presentation/star_system/atmospheric_accents.gd")
const Calibration = preload("res://resources/presentation/star_system_settings.tres")
const DefenseVisual = preload("res://scripts/presentation/star_system/defense_presentation.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func settle() -> void:
	for frame in 4:
		await process_frame


func image(map: Control) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return map.viewport.get_texture().get_image()


func difference(a: Image, b: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(1, a.get_height() - 1, 7):
		for x in range(1, a.get_width() - 1, 7):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			count += 3
	return total / maxi(1, count)


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var folder := "res://.godot/testlogs/atmospheric-accents"
	DirAccess.make_dir_recursive_absolute(folder)
	root.get_texture().get_image().save_webp(
		"%s/%s-%s.webp" % [folder, RenderingServer.get_current_rendering_method(), label]
	)


func preview(state: Resource) -> Dictionary:
	var data := Accents.Visual.generate(
		state.seed_used,
		1,
		[],
		Calibration,
		state.system_profile,
		state.layout_expansion,
		state.orbit_clearance,
		preload("res://scripts/expedition/environment_clearance.gd").solar_clearance(
			state.environmental_instances
		)
	)
	var sizes := State.SystemLayout.planetary_radii(state.encounters)
	DefenseVisual.layout(
		data,
		state.defense_map_view(),
		sizes.keys(),
		state.layout_expansion,
		state.orbit_clearance,
		sizes,
		preload("res://scripts/expedition/environment_clearance.gd").solar_clearance(
			state.environmental_instances
		)
	)
	var exclusions: Array = [{"position": Vector3.ZERO, "radius": 2.0}]
	for planet in data.planets:
		exclusions.append({"position": planet.position, "radius": planet.radius * 1.5 * 1.035})
	for at in data.anchors.values():
		exclusions.append({"position": at, "radius": 1.2})
	return Accents.recipe(
		state.seed_used,
		1,
		data,
		state.system_variation,
		Calibration.atmospheric_accents,
		state.layout_expansion,
		state.environmental_instances,
		exclusions
	)


func pixel_checks(map: Control) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hidden: Array = []
	for node in map.world.get_children():
		if node is Node3D and node != map.camera and node != map.background and node.visible:
			node.hide()
			hidden.append(node)
	for node in map.background.get_children():
		if node != map.background.atmospheric_accent and node is Node3D and node.visible:
			node.hide()
			hidden.append(node)
	var camera: Camera3D = map.camera
	var rest := camera.global_transform
	var first := await image(map)
	camera.global_position += Vector3(4, 2, 3)
	var translated := await image(map)
	check(difference(first, translated) < 0.001, "Actual accent pixels are translation invariant")
	camera.global_transform = rest
	camera.global_basis = rest.basis.rotated(Vector3.UP, 0.12)
	var rotated := await image(map)
	check(
		difference(first, rotated) > 0.000005,
		"Actual panorama feature follows world direction during camera rotation"
	)
	camera.global_transform = rest
	# Retain the production star sky for the visibility check. Isolated pixels
	# alone could pass while an opaque/background pass covers the real accent.
	map.background.sky.show()
	var combined := await image(map)
	map.background.atmospheric_accent.hide()
	var sky_only := await image(map)
	check(
		difference(combined, sky_only) > 0.00002,
		"Panorama remains visibly present over the actual production star sky"
	)
	map.background.sky.hide()
	map.background.atmospheric_accent.show()
	# Opaque nearby geometry must occlude the far-depth transparent layer.
	var quad := QuadMesh.new()
	quad.size = Vector2(40, 40)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.6, 0.3)
	var proxy := Accents.Meshes.part(
		map.world, "TestForeground", quad, camera.position - camera.basis.z * 5, material
	)
	proxy.basis = camera.basis
	var covered := await image(map)
	map.background.atmospheric_accent.hide()
	var uncovered := await image(map)
	check(
		difference(covered, uncovered) < 0.00001,
		"Opaque gameplay geometry correctly occludes panorama accents"
	)
	proxy.free()
	map.background.atmospheric_accent.show()
	camera.global_transform = rest
	for node in hidden:
		node.show()


func run() -> void:
	if DisplayServer.get_name() != "headless":
		check(
			RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0],
			"Requested renderer is active"
		)
	var examples := {}
	for seed_value in range(1, 1001):
		var rules: Resource = Rules.duplicate(true)
		rules.log_rolls = false
		var state := State.new()
		state.start(0, rules, seed_value)
		var plan := preview(state)
		var labels: Array = []
		if plan.kind == "quiet" and state.system_variation.companion.is_empty():
			labels.append("quiet")
		if not state.system_variation.companion.is_empty():
			labels.append("binary")
		if state.system_variation.archetype in ["crowded", "scattered", "storm_dominated"]:
			labels.append(state.system_variation.archetype)
		if plan.kind in ["rocks", "moon", "anomaly"]:
			labels.append(plan.kind)
		if not plan.sky.is_empty() and plan.sky.asset in ["nebula", "galaxy"]:
			labels.append(plan.sky.asset)
		for label in labels:
			if not examples.has(label):
				examples[label] = seed_value
		if examples.size() == 10:
			break
	check(examples.size() == 10, "All quiet, busy and atmospheric combinations occur in system one")
	print("Atmospheric production examples: ", examples)
	for label in examples:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(960, 540)
		var host = load("res://scenes/expedition.tscn").instantiate()
		host.persistence_enabled = false
		host.play_system_intro = false
		host.rules = Rules.duplicate(true)
		host.rules.debug_seed = examples[label]
		host.rules.log_rolls = false
		root.add_child(host)
		await settle()
		var map: Control = host.star_map
		var before := Save.encode(host.state)
		var plan: Dictionary = map.atmospheric_recipe
		if label in ["rocks", "moon", "anomaly"]:
			check(plan.kind == label, "Production renderer constructs " + label)
		if label in ["nebula", "galaxy"]:
			check(plan.sky.get("asset", "") == label, "Production renderer references " + label)
		check(map.atmospheric_nodes.size() <= 1, "One world accent maximum")
		check(map.background.layers.size() <= 4, "Existing sky layer budget remains bounded")
		if not plan.sky.is_empty():
			var material: ShaderMaterial = map.background.atmospheric_accent.material_override
			var direction: Vector3 = material.get_shader_parameter("sky_direction")
			var screen_at: Vector2 = (
				map.camera.unproject_position(map.camera.global_position + direction * 55.0)
				/ Vector2(map.viewport.size)
			)
			check(
				Rect2(0.08, 0.08, 0.84, 0.84).has_point(screen_at),
				"Landmark center fits the actual production FOV"
			)
			check(
				map.background.atmospheric_accent.mesh is ArrayMesh,
				"Panoramas use curved angular geometry rather than a stretched image quad"
			)
			var original: Resource = load(Accents.PANORAMAS[plan.sky.asset])
			check(
				material.get_shader_parameter("source_texture") == original,
				"Panorama reuses the original battlefield texture Resource"
			)
			check(
				material.render_priority < 0 and not "depth_test_disabled" in material.shader.code,
				"Distant imagery preserves normal occlusion"
			)
			await pixel_checks(map)
		for node in map.atmospheric_nodes:
			check(
				node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"Scenery adds no shadow rendering"
			)
			check(
				node.find_children("*", "CollisionObject3D", true, false).is_empty(),
				"Scenery cannot intercept taps or movement"
			)
		for dimensions in [Vector2i(1280, 720), Vector2i(960, 540), Vector2i(1280, 573)]:
			root.size = dimensions
			await settle()
			var pose: Transform3D = map.camera.global_transform
			var suffix := "%s-seed-%d-%dx%d" % [label, examples[label], dimensions.x, dimensions.y]
			await capture(suffix + "-after")
			for node in map.atmospheric_nodes:
				node.hide()
			if is_instance_valid(map.background.atmospheric_accent):
				map.background.atmospheric_accent.hide()
			await settle()
			check(map.camera.global_transform == pose, "Comparison uses identical camera framing")
			await capture(suffix + "-before")
			for node in map.atmospheric_nodes:
				node.show()
			if is_instance_valid(map.background.atmospheric_accent):
				map.background.atmospheric_accent.show()
		check(
			Save.encode(host.state) == before,
			"Rendering, resizing and decoration never change gameplay or RNG"
		)
		var saved: Resource = Save.new().decode(
			JSON.parse_string(JSON.stringify(before)), host.state.rules
		)
		check(saved != null, "Real expedition save restores")
		var restored_host = load("res://scenes/expedition.tscn").instantiate()
		restored_host.persistence_enabled = false
		restored_host.play_system_intro = false
		restored_host.resume_data = {"state": saved}
		root.add_child(restored_host)
		await settle()
		check(
			restored_host.star_map.atmospheric_recipe == plan,
			"Real resume reconstructs the exact same accent"
		)
		restored_host.free()
		host.free()
		await process_frame
	print("Atmospheric rendering: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
