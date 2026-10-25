extends SceneTree
const Data = preload("res://scripts/presentation/star_system/visual_system.gd")
const Settings = preload("res://scripts/presentation/star_system/map_settings.gd")
const Planets = preload("res://scripts/presentation/star_system/planet_models.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(12): await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/planets-"+name+".png")
func run() -> void:
	var map = preload("res://scenes/star_system_3d.tscn").instantiate()
	map.player_profile = preload("res://ships/player/endeavour.tres")
	root.add_child(map)
	check(map.camera.fov==22.0,"Map overview uses a compressed low-FOV presentation")
	check(map.world.get_node("SunLight") is OmniLight3D,"Map is lit from the central sun")
	check(map.world.get_node("SunLight").position==Vector3.ZERO,"Sun light is centered on the orbital focus")
	check(map.world.find_children("*","DirectionalLight3D",true,false).is_empty(),"No unrelated directional map light")
	var entries: Array = []
	for i in range(6):
		entries.append({"index":i,"name":"Encounter %d" % i,"text":"Destination","tooltip":"Existing encounter","color":Color.CORNFLOWER_BLUE,"completed":false,"model_kind":["mining_operation","research_station","gas_giant","quarantined_colony","derelict_starship","battle"][i]})
	entries[5].profile = preload("res://ships/enemy/marauder.tres")
	entries.append({"index":-2,"name":"Trading Outpost","text":"Trading Outpost","tooltip":"Service","color":Color.CORNFLOWER_BLUE,"completed":false,"model_kind":"trading_outpost"})
	var seeds: Dictionary = {}
	for seed_value in range(1,500):
		var generated: Dictionary = Data.generate(seed_value,1,entries,map.settings)
		if not seeds.has(generated.planets.size()): seeds[generated.planets.size()] = seed_value
		if generated.planets.size()==4 and not seeds.has("dense_four"):
			var sky_rng = Data.random_for(seed_value,1,"background")
			sky_rng.randf_range(1,99)
			if sky_rng.randf()>=0.3: seeds["dense_four"] = seed_value
		for p in generated.planets:
			if p.eccentricity>0.16 and abs(p.inclination)>deg_to_rad(10) and not seeds.has("tilted"): seeds["tilted"] = seed_value
			if p.type=="gas_giant" and p.radius>0.78 and not seeds.has("giant"): seeds["giant"] = seed_value
	check(seeds.has(2) and seeds.has(3) and seeds.has(4),"Representative two/three/four planet seeds")
	for count in [2,3,4]:
		for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1680,720)]:
			root.size = dimensions
			map.run_seed = seeds[count]
			map.configure(entries,-1,0.04,seeds[count])
			await settle()
			check(map.planet_nodes.size()==count,"Generated planet count")
			check(map.objects.size()==8 and map.markers.size()==7,"Only six encounters and independent service are interactive")
			for p in map.visual_data.planets:
				if p.encounter>=0:
					check(map.objects[p.encounter]==map.planet_nodes[p.index],"Single planetary representation")
				else:
					check(not map.objects.values().has(map.planet_nodes[p.index]),"Decorative planets are not destinations")
			for i in map.markers:
				check(map.objects.has(i),"Stable destination identity")
			await capture("%d-%d" % [count,dimensions.x])
	for special in ["tilted","giant"]:
		check(seeds.has(special),"Seeded representative "+special)
		if seeds.has(special):
			map.run_seed = seeds[special]
			map.configure(entries,-1,0.04,seeds[special])
			await settle()
			await capture(special)
	map.run_seed = seeds[4]
	map.configure(entries,-1,0.04,seeds[4])
	await settle()
	if DisplayServer.get_name() != "headless":
		var start: int = Time.get_ticks_usec()
		for frame in range(30): await process_frame
		print("Four-planet software render mean frame: %.2f ms; draw calls: %d" % [(Time.get_ticks_usec()-start)/30000.0,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	map.camera.frame(map.ship.position+Vector3(1.5,1.5,2.2),map.ship.position,0.0,&"ftl")
	map.configure(entries,-1,0.04,seeds[4]+123456)
	check(map.background.origin==map.camera.position,"Rebuild records dust reference after restoring overview, not the prior cinematic")
	# Both imported surfaces and the explicit legacy fallback can build every type.
	var specimen: Dictionary = map.visual_data.planets[0].duplicate(true)
	for kind in Data.TYPES:
		specimen.type = kind
		var planet = Planets.build(specimen,map.settings)
		map.world.add_child(planet)
		check(planet.get_node("Surface").material_override.shader.resource_path.ends_with("body.gdshader"),"Imported material "+kind)
		await settle()
		planet.free()
	var reduced = map.settings.duplicate()
	reduced.imported_planets = false
	reduced.stardust_enabled = false
	var fallback = Planets.build(specimen,reduced)
	check(fallback.get_node("Surface").material_override.shader.resource_path=="res://shaders/planet_surface.gdshader","Existing shader fallback retained")
	fallback.free()
	var Models = preload("res://scripts/presentation/star_system/destination_models.gd")
	for kind in ["trading_outpost","mining_operation","derelict_starship","pirate_debris_field","research_station","distress_signal","quarantined_colony","gas_giant","spatial_anomaly","unstable_wormhole","radiation_nebula"]:
		var model = Models.build({"model_kind":kind},Data.random_for(44,1,kind))
		map.world.add_child(model)
		check(model.get_child_count()>0,"Recognizable procedural model "+kind)
		await settle()
		if kind in ["unstable_wormhole","spatial_anomaly","trading_outpost"]: await capture(kind)
		model.free()
	var custom_settings = map.settings.duplicate(true)
	custom_settings.stardust_enabled = false
	var layer = preload("res://scripts/presentation/star_system/sky_layer.gd").new()
	var image = Image.create(2,2,false,Image.FORMAT_RGBA8)
	image.fill(Color(1,1,1,0.5))
	layer.texture = ImageTexture.create_from_image(image)
	custom_settings.background_layers.assign([layer])
	var replacement_sky = preload("res://scripts/presentation/star_system/space_environment.gd").new()
	map.world.add_child(replacement_sky)
	replacement_sky.configure(map.camera,custom_settings,Data.random_for(44,1,"texture"))
	check(replacement_sky.layers[0].material_override.get_shader_parameter("use_texture"),"Texture replacement uses existing shader")
	check(replacement_sky.dust.is_empty(),"Reduced quality disables dust completely")
	replacement_sky.free()
	var scene = PackedScene.new()
	var replacement_root = Node3D.new()
	replacement_root.name = "ReplacementModel"
	scene.pack(replacement_root)
	replacement_root.free()
	var replacement = Models.build({"model_kind":"research_station"},Data.random_for(1,1,"replacement"),scene)
	check(replacement.name=="ReplacementModel","PackedScene model replacement has no gameplay dependency")
	replacement.free()
	check(map.ship.scale.is_equal_approx(Vector3.ONE*0.175),"Star-map player ship is half its previous size")
	check(map.objects[-100].mesh.size==Vector2(18,18),"Star-map sun is 50 percent larger")
	check(map.objects[-100].material_override.get_shader_parameter("core_scale")==2.0,"Map sun uses a stronger central core")
	for planet in map.planet_nodes.values():
		check(planet.scale.is_equal_approx(Vector3.ONE*1.5),"Star-map planets are 50 percent larger")
	check(map.objects[5].scale.is_equal_approx(Vector3.ONE*0.275),"Star-map enemy ship is half its previous size")
	check(map.objects[-2].scale.is_equal_approx(Vector3.ONE*0.5),"Star-map station is half its previous size")
	var old_zoom: float = map.camera.zoom_scale
	map.camera.zoom_scale = 1.0
	map.camera.zoom_target = 1.0
	await settle()
	check(map.markers[5].compact and map.markers[5].text=="⚔","Zoomed-out enemy PoI uses its relevant icon")
	for index in map.visual_data.assignments:
		check(map.markers[index].text==map.visual_data.planets[map.visual_data.assignments[index]].name,"Planet label contains only its name")
		check(not map.markers[index].compact,"Planet names remain names at wide zoom")
	var marker = map.markers[5]
	var anchor: Vector3 = map.objects[5].position
	check(marker.position.y+marker.size.y<map.camera.unproject_position(anchor).y,"PoI label stays above its object")
	map.objects[5].position += Vector3(200,0,0)
	await settle()
	check(marker.position.x>map.size.x,"Offscreen labels are not clamped or relocated to other slots")
	map.objects[5].position = anchor
	map.camera.zoom_scale = 3.0
	map.camera.zoom_target = 3.0
	await settle()
	check(not map.markers[5].compact and map.markers[5].text==entries[5].name,"Close zoom restores the PoI name")
	var at_rest: Vector2 = marker.position
	await settle()
	check(marker.position.is_equal_approx(at_rest),"Labels do not hop between alternative positions")
	map.camera.zoom_scale = old_zoom
	map.camera.zoom_target = old_zoom
	await settle()
	var relative: Vector3 = map.background.sky.position
	var layer_relative: Vector3 = map.background.layers[0].position
	var dust_relative: Vector3 = map.background.dust[0].position
	map.camera.position += Vector3(3,0,0)
	check(map.background.sky.position==relative,"Sky translation is computed from the render camera in the shader")
	check(map.background.layers[0].position.is_equal_approx(layer_relative),"Distant layers have no late CPU transform updates")
	check(map.background.layers[0].material_override.get_shader_parameter("camera_relative"),"Distant layers use the render camera in their shader")
	check(map.background.dust[0].position==dust_relative,"Dust has no late CPU transform updates")
	var near_material: ShaderMaterial = map.background.dust[0].multimesh.mesh.material
	var far_material: ShaderMaterial = map.background.dust[1].multimesh.mesh.material
	check(near_material.get_shader_parameter("parallax")>far_material.get_shader_parameter("parallax"),"Nearby white points have stronger parallax than distant points")
	var dust_orientation: Basis = map.background.dust[0].basis
	var camera_orientation: Basis = map.camera.basis
	var fragment: Transform3D = map.background.dust[0].multimesh.get_instance_transform(0)
	map.camera.rotate_y(0.1)
	check(map.background.dust[0].basis.is_equal_approx(dust_orientation),"Debris orientation stays anchored during camera turns")
	check(map.background.dust[0].multimesh.get_instance_transform(0)==fragment,"Camera updates never regenerate fragments")
	check(map.background.dust[0].multimesh.mesh.size.x>=0.03 and map.background.dust[0].multimesh.mesh.size.x<0.1,"Debris uses small antialiased star-like dots")
	var settled_transform: Transform3D = map.background.dust[0].transform
	check(map.background.dust[0].transform==settled_transform,"Stationary camera produces no debris jitter")
	map.camera.basis = camera_orientation
	map.set_active(false)
	check(map.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not map.background.is_processing(),"No inactive GPU/background loop")
	map.set_active(true)
	var target: int = map.visual_data.assignments.keys()[0] if not map.visual_data.assignments.is_empty() else 0
	for p in map.visual_data.planets:
		check(map.ship.position.distance_to(p.position)>p.radius*1.5+1.0,"Initial selected ship avoids planet surfaces")
	var arrival: Array = []
	map.arrived.connect(func(i): arrival.append(i))
	map.travel(target)
	await create_timer(0.15).timeout
	check(arrival==[target],"Planet/standalone arrival fires once")
	check(map.ship.position.distance_to(map.objects[target].position)>float(map.objects[target].get_meta("radius",0.0))+0.7,"Safe ship clearance")
	map.focus(target)
	await create_timer(0.9).timeout
	await capture("planet-focus")
	map.overview()
	map.focus(5)
	await create_timer(0.9).timeout
	await capture("ship-focus")
	var normal_settings = map.settings
	for quality in ["dark-reduced","bright-nebula"]:
		map.settings = normal_settings.duplicate(true)
		map.settings.stardust_enabled = quality != "dark-reduced"
		map.settings.clouds_enabled = quality != "dark-reduced"
		map.settings.atmospheres_enabled = quality != "dark-reduced"
		map.settings.imported_planets = quality != "dark-reduced"
		if quality == "dark-reduced": map.settings.background_layers.clear()
		else:
			map.run_seed = seeds["dense_four"]
			map.settings.background_strength = 1.0
			map.settings.background_layers[0].opacity = 0.45
			map.settings.background_layers[0].angular_position = Vector2(180,-50)
		check(Data.generate(seeds[4],1,entries,map.settings)==Data.generate(seeds[4],1,entries,normal_settings),"Quality changes do not reshuffle the cosmetic system")
		map.configure(entries,-1,0.04,seeds[4]+100000+quality.hash())
		await settle()
		check(map.planet_nodes.size()==4,"Quality never changes planet count")
		if quality == "dark-reduced": check(map.background.dust.is_empty() and map.background.layers.is_empty(),"Reduced quality removes decorative passes")
		await capture(quality)
	for phenomenon in ["radiation_nebula", "spatial_anomaly", "unstable_wormhole"]:
		entries[4].model_kind = phenomenon
		map.configured_seed += 1
		map.configure(entries,-1,0.04,seeds[4])
		check(map.objects[4].scale.is_equal_approx(Vector3.ONE*1.5),"Space phenomenon is 50 percent larger: "+phenomenon)
	entries[4].model_kind = "derelict_starship"
	map.free()
	# Codec and gameplay random streams remain untouched by visual reconstruction.
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = seeds[4]
	host.rules.log_rolls = false
	root.add_child(host)
	var Save = preload("res://scripts/persistence/expedition_save.gd")
	var before: Dictionary = Save.encode(host.state)
	var visual: Dictionary = host.star_map.visual_data.duplicate(true)
	await settle()
	await capture("expedition-overview")
	host.star_map.configured_seed += 1 # Exercise a full rebuild, not the refresh fast path.
	host._show_star_map(false)
	check(Save.encode(host.state)==before,"Cosmetics do not change any saved state or RNG stream")
	var restored = Save.new().decode(before)
	check(Data.generate(restored.seed_used,restored.system_number,entries,host.star_map.settings).name==visual.name,"Display name reconstructs from version 1 save")
	check(restored.system_name==host.state.system_name,"Stored authoritative name preserved")
	var resumed = preload("res://scenes/expedition.tscn").instantiate()
	resumed.persistence_enabled = false
	resumed.resume_data = {"state":restored}
	root.add_child(resumed)
	check(resumed.star_map.visual_data==visual,"Complete cosmetic configuration reconstructs from old-format save")
	resumed.free()
	if not host.star_map.visual_data.assignments.is_empty():
		var index: int = host.star_map.visual_data.assignments.keys()[0]
		host.map_destination = index
		host.show_poi(index)
		await create_timer(0.9).timeout
		check(host.screen.model_space.visible and host.grid.columns==1,"Planet focus keeps existing right approach UI")
		check(host.header.get_node("TextBacking").color.a>=0.9,"Existing header backing protects text over bright planets")
		await capture("expedition-poi")
	host.free()
	await process_frame
	print("Planet presentation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
