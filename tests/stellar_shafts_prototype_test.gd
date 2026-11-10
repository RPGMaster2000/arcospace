extends SceneTree
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
	var views := [{"name":"centered","at":Vector3(4,15,26),"target":Vector3(4,0,0)},
		{"name":"offscreen","at":Vector3(8,3,7),"target":Vector3(8,0,0)},
		{"name":"oblique","at":Vector3(18,12,5),"target":Vector3(12,0,0)},
		{"name":"backlit","at":Vector3(22,3,2),"target":Vector3(10,0,0)}]
	var initial: Transform3D = shafts.records[0].volume.global_transform
	for view in views:
		map.camera.frame(view.at,view.target,0.0,&"prototype")
		map.sun_lens.update(true,map.viewport,map.camera,map.objects[-100],map.visual_data.star_color)
		check(shafts.records[0].volume.global_transform == initial,"Camera motion does not rotate world-space shafts")
		if view.name == "offscreen":
			var sun_right: Vector2 = map.camera.unproject_position(map.objects[-100].position + map.camera.basis.x*2.52)
			check(sun_right.x < 0.0,"Physical sun disc is completely offscreen in the planet fixture")
		for enabled in [false,true]:
			shafts.visible = enabled
			for frame in range(8): await process_frame
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/shafts-prototype")
				root.get_texture().get_image().save_png("res://.godot/testlogs/shafts-prototype/"+view.name+("-after-" if enabled else "-before-")+RenderingServer.get_current_rendering_method()+".png")
	var mesh: Mesh = shafts.records[0].volume.mesh
	map.camera.frame(Vector3(13,10,11),Vector3(10,0,0),0.2,&"prototype_motion")
	for frame in range(40):
		await process_frame
		check(shafts.records[0].volume.global_transform == initial and shafts.records[0].volume.mesh == mesh,"Camera transition never rotates or reallocates world geometry")
	print("Stellar shafts prototype: %d failures" % failures)
	map.free()
	quit(failures)
