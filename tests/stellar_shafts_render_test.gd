extends SceneTree
## Identical camera fixtures capture the baseline and the calibrated map.
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Planets = preload("res://scripts/presentation/star_system/planet_models.gd")
var failures := 0
var checks := 0
var baseline := false
var map: Control
var metrics := {}
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	map._process(0.0)
	for frame in range(8): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	var shafts = map.visual_root.get_node_or_null("StellarShafts")
	if shafts == null: return
	var folder := "res://.godot/testlogs/stellar-shafts"
	DirAccess.make_dir_recursive_absolute(folder)
	for enabled in [false,true]:
		shafts.visible = enabled
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(folder + "/" + label + ("-after-" if enabled else "-before-") + RenderingServer.get_current_rendering_method() + ".png") == OK,"Matched production volume capture saved")
	shafts.show()
func frame_at(at: Vector3, target: Vector3) -> void:
	map.camera.frame(at,target,0.0,&"lighting_fixture")
func pixel_mean(image: Image, world_point: Vector3) -> float:
	var at: Vector2i = Vector2i(map.camera.unproject_position(world_point))
	var total := 0.0
	for y in range(-1,2):
		for x in range(-1,2):
			total += image.get_pixelv(at + Vector2i(x,y)).get_luminance()
	return total / 9.0
func run() -> void:
	baseline = true # This suite isolates world volumes; parent lighting assertions run separately.
	root.size = Vector2i(1280,720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.game_mode = "exploration"
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	for frame in range(16): await process_frame
	map = host.star_map
	var saved: Dictionary = Save.encode(host.state)
	host.process_mode = Node.PROCESS_MODE_DISABLED
	map.set_process(false)
	map.camera.set_process(false)
	if map.camera.motion and map.camera.motion.is_running(): map.camera.motion.kill()
	for mesh in map.visual_root.find_children("*","MeshInstance3D",true,false):
		if mesh.material_override is ShaderMaterial:
			var path: String = mesh.material_override.shader.resource_path
			if path.ends_with("body.gdshader"): mesh.material_override.set_shader_parameter("noise_gaseous_speed",0.0)
			if path.ends_with("clouds.gdshader"): mesh.material_override.set_shader_parameter("speed",0.0)
	var overview: Transform3D = map.camera.transform
	await settle()
	await capture("centered")
	metrics["overview_draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if not baseline:
		check(map.sun_lens.edge_weight(0.03,map.settings.lens_edge_fade_range) > 0.9,"Flare stays visible at three percent from the viewport edge")
		var last := 0.0
		for step in range(51):
			var weight: float = map.sun_lens.edge_weight(float(step)/1000.0,map.settings.lens_edge_fade_range)
			check(weight >= last and weight-last < 0.05,"Edge attenuation is bounded, smooth and monotonic")
			last = weight
		check(map.sun_lens.edge_weight(-0.01,map.settings.lens_edge_fade_range) == 0.0 and map.sun_lens.edge_weight(0.0,map.settings.lens_edge_fade_range) == 0.0,"Flare is absent at or beyond actual borders")
		check(map.sun_lens.edge_weight(0.5,map.settings.lens_edge_fade_range) == 1.0 and is_equal_approx(map.settings.lens_flare_multiplier,0.32),"Centered flare strength remains unchanged")
	var depth: float = -map.camera.to_local(map.objects[-100].global_position).z
	var half_width: float = depth * tan(deg_to_rad(map.camera.fov * 0.5)) * float(map.viewport.size.x)/map.viewport.size.y
	for fixture in [{"label":"edge","shift":-0.94},{"label":"offscreen","shift":-1.30}]:
		map.camera.transform = overview
		map.camera.position += overview.basis.x * half_width * float(fixture.shift)
		await settle()
		var uv: Vector2 = map.camera.unproject_position(map.objects[-100].global_position) / Vector2(map.viewport.size)
		metrics[fixture.label + "_sun_uv"] = [uv.x,uv.y]
		if fixture.label == "offscreen" and map.sun_lens.effect != null:
			check(not map.sun_lens.effect.enabled,"Completely offscreen sun never produces a lens flare")
		if not baseline and fixture.label == "edge" and map.sun_lens.effect != null:
			check(map.sun_lens.effect.enabled and float(map.sun_lens.effect.get("Effect_Multiplier")) > map.settings.lens_flare_multiplier * 0.9,"Rendered near-edge source retains its projected flare")
		await capture(fixture.label)
	map.camera.transform = overview
	await settle()
	map.feedback.set_process(false)
	map.feedback.hide()
	map.feedback.player_marker.hide()
	for orbit in map.orbit_nodes.values(): orbit.hide()
	for ring in map.selection_rings.values(): ring.hide()
	var planet: Node3D = map.planet_nodes.values()[0]
	var radius: float = planet.get_meta("radius")
	var toward_star: Vector3 = (map.objects[-100].position - planet.position).normalized()
	var tangent: Vector3 = Vector3.UP.cross(toward_star).normalized()
	map.ship.position = planet.position + tangent * radius * 2.1
	for fixture in [{"label":"terminator","direction":toward_star * 0.3 + tangent + Vector3.UP * 0.35},
		{"label":"dark-side","direction":-toward_star + Vector3.UP * 0.2},
		{"label":"spacecraft","direction":tangent + Vector3.UP * 0.55}]:
		frame_at(planet.position + fixture.direction.normalized() * radius * 8.0,planet.position)
		await settle()
		for button in map.markers.values(): button.hide()
		await capture(fixture.label)
	# Existing production material factory, fixed specimen and framing on both refs.
	# Keep the star outside the close-up so night readability is judged against sky.
	map.ship.hide()
	frame_at(planet.position + (-toward_star * 0.55 + tangent + Vector3.UP * 0.25).normalized() * radius * 8.0,planet.position)
	await settle()
	for button in map.markers.values(): button.hide()
	await capture("dark-nebula")
	var gas_data: Dictionary = map.visual_data.planets[0].duplicate(true)
	gas_data.type = "gas_giant"
	gas_data.rotation = 0.0
	var gas: Node3D = Planets.build(gas_data,map.settings)
	gas.position = planet.position
	map.world.add_child(gas)
	planet.hide()
	frame_at(gas.position + (toward_star * 0.3 + tangent + Vector3.UP * 0.35).normalized() * radius * 8.0,gas.position)
	await settle()
	for button in map.markers.values(): button.hide()
	await capture("gas-giant")
	gas.free()
	planet.show()
	map.ship.show()
	map.feedback.show()
	map.feedback.set_process(true)
	for orbit in map.orbit_nodes.values(): orbit.show()
	# A second overview includes the production asteroid formation and PoI rings.
	map.camera.transform = overview
	map.camera.fov = map.settings.field_of_view
	await settle()
	await capture("asteroids-pois")
	check(map.visual_root.get_node("AsteroidFields").get_child_count() == 1 and map.selection_rings.size() == map.markers.size(),"Asteroid formation and PoI rings survive calibration")
	if not baseline: check(map.objects[-100].material_override.get_shader_parameter("map_corona_visibility") == true,"Map corona is gated by its real projected source")
	check(not map.world.get_node("SunLight").shadow_enabled,"No star shadow maps")
	if not baseline:
		check(map.sun_lens.effect == null or map.sun_lens.effect.get("SampleCount") == 20,"Android lens sample budget stays at twenty")
		for body in map.planet_nodes.values():
			var material: ShaderMaterial = body.get_node("Surface").material_override
			check(material.get_shader_parameter("stellar_lighting_enabled") == true and material.get_shader_parameter("stellar_position") == map.objects[-100].position,"Every planet uses the physical star direction")
		var asteroids: MultiMesh = map.visual_root.get_node("AsteroidFields").get_child(0).multimesh
		check(not asteroids.mesh.material.rim_enabled and asteroids.instance_count > 0,"Asteroid materials and low-cost MultiMesh layout remain intact")
		if DisplayServer.get_name() != "headless" and map.sun_lens.effect != null:
			await RenderingServer.frame_post_draw
			var sun: Node3D = map.objects[-100]
			var unobstructed: float = pixel_mean(map.viewport.get_texture().get_image(),sun.global_position)
			var blocker := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 3.0
			sphere.height = 6.0
			blocker.mesh = sphere
			var opaque := StandardMaterial3D.new()
			opaque.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			opaque.albedo_color = Color.BLACK
			blocker.material_override = opaque
			blocker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			blocker.position = sun.position + (map.camera.position-sun.position).normalized() * 6.0
			map.world.add_child(blocker)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var occluded: float = pixel_mean(map.viewport.get_texture().get_image(),sun.global_position)
			check(occluded < unobstructed * 0.35,"Opaque foreground geometry still occludes the real solar flare")
			blocker.free()
		# Offscreen AND behind-camera guards remain in the existing lens adapter.
		var sun: Node3D = map.objects[-100]
		var old_position: Vector3 = sun.position
		sun.position = map.camera.position + map.camera.basis.z * 10.0
		await settle()
		check(map.sun_lens.effect == null or not map.sun_lens.effect.enabled,"Behind-camera source cannot produce flares")
		sun.position = old_position
		await settle()
	if DisplayServer.get_name() != "headless":
		# Neutral opaque probe: identical material and world surface patches with
		# the star centered, then entirely outside the frustum. No lens contribution.
		map.sun_lens.disable()
		for child in map.visual_root.get_children(): child.visible = child.name == "Sun"
		map.destination_root.hide()
		map.ship.hide()
		map.background.hide()
		for button in map.markers.values(): button.hide()
		var specimen: Dictionary = map.visual_data.planets[0].duplicate(true)
		specimen.radius = 1.0 / 1.5
		specimen.type = "barren"
		specimen.rotation = 0.0
		var calibration = map.settings.duplicate()
		calibration.clouds_enabled = false
		calibration.atmospheres_enabled = false
		var probe: Node3D = Planets.build(specimen,calibration)
		probe.position = Vector3(10,0,0)
		map.world.add_child(probe)
		var material: ShaderMaterial = probe.get_node("Surface").material_override
		for index in range(1,6): material.set_shader_parameter("color_%d" % index,Color(0.38,0.38,0.38))
		material.set_shader_parameter("specular_strength",0.0)
		material.set_shader_parameter("rim_fill",0.0)
		if not baseline: material.set_shader_parameter("stellar_rim_intensity",0.0)
		for fixture in [{"label":"source-visible","at":Vector3(0,0,30),"target":Vector3.ZERO,"fov":55.0},
			{"label":"source-offscreen","at":Vector3(10,0,8),"target":probe.position,"fov":22.0}]:
			map.camera.fov = fixture.fov
			frame_at(fixture.at,fixture.target)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var image: Image = map.viewport.get_texture().get_image()
			var day: float = pixel_mean(image,probe.position + Vector3(-0.6,0,0.8))
			var night: float = pixel_mean(image,probe.position + Vector3(0.6,0,0.8))
			metrics[fixture.label] = {"day":day,"night":night,"contrast":day/maxf(night,0.0001)}
			check(day > night * 1.5 and night > 0.01,"Sunward surface is brighter without crushing night detail")
		var visible: Dictionary = metrics["source-visible"]
		var offscreen: Dictionary = metrics["source-offscreen"]
		check(absf(visible.day-offscreen.day) < 0.10 and absf(visible.night-offscreen.night) < 0.10,"World-space illumination survives camera panning without the lens compositor")
		if not baseline: check(offscreen.contrast > 3.2 and offscreen.night > 0.04,"Calibrated day/night contrast preserves readable reflected fill")
		probe.free()
	var volume_root = map.visual_root.get_node("StellarShafts")
	check(volume_root.get_child_count() == 1,"One continuous scattering-field draw")
	check(volume_root.field.global_position == map.objects[-100].global_position,"Global medium originates at the physical star")
	var extent: Vector3 = volume_root.material.get_shader_parameter("field_extent")
	check(extent.x > map.settings.system_bounds.end.length(),"Field fades beyond the outer navigable corner")
	check(volume_root.find_children("*","CollisionObject3D",true,false).is_empty(),"Volumes cannot intercept PoI input")
	for record in volume_root.records:
		var expected: Vector3 = (record.body.global_position-map.objects[-100].global_position).normalized()
		check(record.axis.dot(expected) > 0.999,"Shadow extends away from physical star")
		var original_mesh: Mesh = record.volume.mesh
		var original: Transform3D = record.volume.global_transform
		volume_root._update_geometry()
		check(record.volume.mesh == original_mesh and record.volume.global_transform == original,"Static bodies reuse geometry and transforms")
		var position: Vector3 = record.body.position
		record.body.position += Vector3(0.2,0,0)
		volume_root._update_geometry()
		check(record.position == record.body.global_position and record.volume.mesh == original_mesh,"Moved body updates orientation without reallocating shared mesh")
		record.body.position = position
		volume_root._update_geometry()
	check(Save.encode(host.state) == saved,"Camera, lighting and visual quality never alter persisted state or RNG streams")
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	var output := FileAccess.open("res://.godot/testlogs/lighting-" + ("before" if baseline else "after") + "-" + RenderingServer.get_current_rendering_method() + ".json",FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics,"  "))
	host.free()
	await process_frame
	print("Star-system lighting: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
