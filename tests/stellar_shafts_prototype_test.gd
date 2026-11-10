extends SceneTree
const Fixture = preload("res://tests/stellar_scattering_fixture.gd")
const Shafts = preload("res://scripts/presentation/star_system/stellar_shafts.gd")
const Planets = preload("res://scripts/presentation/star_system/planet_models.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var map = preload("res://scenes/star_system_3d.tscn").instantiate()
	root.add_child(map)
	map.player_profile = preload("res://ships/player/endeavour.tres")
	map.run_seed = 1042
	map.configure([],-1,0.1,1042)
	for frame in range(12): await process_frame
	map.set_process(false)
	map.camera.set_process(false)
	map.camera.fov = 38.0
	for node in map.visual_root.get_children(): node.visible = node.name == "Sun"
	map.destination_root.hide()
	map.ship.hide()
	map.feedback.hide()
	map.feedback.set_process(false)
	map.background.hide()
	var settings = map.settings.duplicate()
	var planet = Planets.build({"index":0,"radius":0.8,"type":"terrestrial","material_seed":42,"rotation":0.0},settings)
	planet.position = Vector3(8,0,0)
	map.world.add_child(planet)
	var shafts = Shafts.new()
	map.world.add_child(shafts)
	shafts.configure(map.objects[-100],2.52,[planet],Color(0.8,0.85,1.0))
	var views := [{"name":"centered","at":Vector3(0,15,26),"target":Vector3.ZERO},
		{"name":"offscreen","at":Vector3(8,3,7),"target":Vector3(8,0,0)},
		{"name":"oblique","at":Vector3(18,12,5),"target":Vector3(12,0,0)},
		{"name":"backlit","at":Vector3(22,3,2),"target":Vector3(10,0,0)}]
	# A large outer planet casts a corridor near the navigation boundary.
	var outer = Planets.build({"index":1,"radius":1.1,"type":"barren","material_seed":43,"rotation":0.0},settings)
	outer.position = Vector3(28,0,0)
	map.world.add_child(outer)
	shafts.free()
	shafts = Shafts.new()
	map.world.add_child(shafts)
	shafts.configure(map.objects[-100],2.52,[planet,outer],Color(0.8,0.85,1.0))
	views.append({"name":"outer-offscreen","at":Vector3(29,10,18),"target":Vector3(30,0,0)})
	var initial: Transform3D = shafts.records[0].volume.global_transform
	for view in views:
		map.camera.frame(view.at,view.target,0.0,&"prototype")
		map.sun_lens.update(true,map.viewport,map.camera,map.objects[-100],map.visual_data.star_color)
		check(shafts.records[0].volume.global_transform == initial,"Camera motion does not rotate world-space shafts")
		if view.name == "centered":
			check(map.camera.unproject_position(map.objects[-100].position).distance_to(Vector2(map.viewport.size)*0.5) < 1.0,"Prototype source is exactly centered")
		if view.name in ["offscreen","outer-offscreen"]:
			var sun_right: Vector2 = map.camera.unproject_position(map.objects[-100].position + map.camera.basis.x*2.52)
			check(sun_right.x < 0.0,"Physical sun disc is completely offscreen in the planet fixture")
		for enabled in [false,true]:
			Fixture.apply(shafts,enabled)
			for frame in range(8): await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/shafts-prototype")
				root.get_texture().get_image().save_png("res://.godot/testlogs/shafts-prototype/"+view.name+("-after-" if enabled else "-before-")+RenderingServer.get_current_rendering_method()+".png")
	if DisplayServer.get_name() != "headless":
		var metrics := []
		for revised in [false,true]:
			Fixture.apply(shafts,revised)
			shafts.material.set_shader_parameter("body_count",2)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var shadowed: Image = map.viewport.get_texture().get_image()
			shafts.material.set_shader_parameter("body_count",0)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var clear: Image = map.viewport.get_texture().get_image()
			var point := Vector3(34,0,0)
			var lit: float = Fixture.patch(map,clear,point)
			var blocked: float = Fixture.patch(map,shadowed,point)
			metrics.append({"lit":lit,"shadow":blocked,"contrast":(lit-blocked)/lit})
			check(lit > 0.02 and blocked < lit-0.001,"Outermost offscreen-sun corridor remains illuminated and visibly shadowed")
			check(blocked > lit*0.35,"Corridor retains scattered light rather than becoming an opaque cutout")
		print("Outer-field PR54/revised metrics: "+JSON.stringify(metrics))
		check(metrics[1].contrast > metrics[0].contrast*1.3,"Revised outer corridor has materially stronger relative contrast than PR54")
		check(metrics[1].lit < metrics[0].lit*0.98 and metrics[1].lit > metrics[0].lit*0.65,"Outer medium gently dims without collapsing into darkness")
		Fixture.apply(shafts,true)
		# Identical translated cameras compare inner and outer unoccluded medium.
		map.camera.frame(Vector3(9,10,18),Vector3(10,0,0),0.0,&"inner_falloff")
		var inner_values := []
		for revised in [false,true]:
			Fixture.apply(shafts,revised)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			inner_values.append(Fixture.patch(map,map.viewport.get_texture().get_image(),Vector3(14,0,0)))
		var inner: float = inner_values[1]
		print("PR54/revised inner medium: "+JSON.stringify(inner_values))
		check(metrics[1].lit/inner < metrics[0].lit/inner_values[0]*0.99,"Revised radial falloff dims outer light more than inner light")
		check(metrics[1].lit < inner*0.95 and metrics[1].lit > inner*0.45,"Outer system is dimmer than inner system while retaining readable light")
		print("Inner/outer medium luminance: %f / %f" % [inner,metrics[1].lit])
		map.camera.frame(Vector3(45,10,18),Vector3(46,0,0),0.0,&"beyond_playable_rim")
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var beyond: float = Fixture.patch(map,map.viewport.get_texture().get_image(),Vector3(50,0,0))
		check(beyond < metrics[1].lit*0.75,"Scattering becomes less prominent beyond meaningful gameplay space")
		print("Beyond-rim medium luminance: %f" % beyond)
		shafts.material.set_shader_parameter("body_count",2)

	var mesh: Mesh = shafts.records[0].volume.mesh
	map.camera.frame(Vector3(13,10,11),Vector3(10,0,0),0.2,&"prototype_motion")
	for frame in range(40):
		await process_frame
		check(shafts.records[0].volume.global_transform == initial and shafts.records[0].volume.mesh == mesh,"Camera transition never rotates or reallocates world geometry")
	print("Stellar shafts prototype: %d failures" % failures)
	map.free()
	quit(failures)
