extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func picture() -> Image:
 for i in range(3): await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func run() -> void:
 if DisplayServer.get_name()=="headless":
  print("Orbit visibility: skipped without rendering device")
  quit()
  return
 root.size = Vector2i(960,540)
 var environment := WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color.BLACK
 root.add_child(environment)
 var camera := Camera3D.new()
 camera.fov = 29
 root.add_child(camera)
 var settings = preload("res://scripts/presentation/star_system/map_settings.gd").new()
 var data = {"distance":8.0,"eccentricity":0.2,"inclination":0.0,"orientation":0.5}
 var orbit = preload("res://scripts/presentation/star_system/planet_models.gd").orbit(data,settings)
 root.add_child(orbit)
 for distance in [20.0,60.0,100.0]:
  for elevation in [1.0,5.0,25.0,65.0,89.0]:
   var angle: float = deg_to_rad(elevation)
   camera.position = Vector3(0,sin(angle),cos(angle))*distance
   camera.look_at(Vector3.ZERO)
   var image: Image = await picture()
   var visible_pixels := 0
   for y in range(0,540,2):
    for x in range(0,960,2):
     if image.get_pixel(x,y).g>0.08: visible_pixels += 1
   check(visible_pixels>30,"Orbit stays rendered at %.0f degrees / %.0f distance (%d pixels)" % [elevation,distance,visible_pixels])
 orbit.free()
 var map = preload("res://scenes/star_system_3d.tscn").instantiate()
 root.add_child(map)
 map.player_profile = preload("res://ships/player/endeavour.tres")
 map.configure([], -1,0.1,94)
 for child in map.visual_root.get_children():
  if not child.name.begins_with("Orbit"): child.hide()
 map.ship.hide()
 map.visual_root.hide()
 var sky_only: Image = await picture()
 map.visual_root.show()
 var with_sky: Image = await picture()
 map.background.hide()
 var without_sky: Image = await picture()
 var orbit_pixels := 0
 var visible_over_sky := 0
 for y in range(540):
  for x in range(960):
   var color := without_sky.get_pixel(x,y)
   if color.g>0.06 and color.b>color.r*1.1:
    orbit_pixels += 1
    if with_sky.get_pixel(x,y).g>sky_only.get_pixel(x,y).g+0.01: visible_over_sky += 1
 check(visible_over_sky>100,"Orbit ribbons stay visible with the distant sky enabled (%d pixels)" % visible_over_sky)
 check(map.background.sky.material_override.render_priority==-128,"Distant sky draws before all transparent map objects")
 check(orbit_pixels>100,"Orbit ribbons render inside the actual map SubViewport (%d pixels)" % orbit_pixels)
 with_sky.save_png("res://.godot/testlogs/orbits-with-sky.png")
 without_sky.save_png("res://.godot/testlogs/orbits-without-sky.png")
 var sun = map.objects[-100]
 check(sun.custom_aabb.size==Vector3.ONE*18.0,"Sun has rotation-safe billboard culling bounds")
 check(sun.material_override.render_priority==10,"Sun has stable transparency ordering above background layers")
 sun.show()
 map.background.show()
 map.camera.viewing = &"test"
 var start: Vector3 = map.camera.position
 for step in range(-8,9):
  map.camera.position = start+Vector3(step*0.7,0,step*0.4)
  var sun_image: Image = await picture()
  var point: Vector2 = map.camera.unproject_position(Vector3.ZERO)
  point *= Vector2(sun_image.get_size())/Vector2(map.viewport.size)
  var color := sun_image.get_pixel(clampi(roundi(point.x),0,959),clampi(roundi(point.y),0,539))
  check(color.r>0.3 and color.g>0.1,"Sun remains visible during camera movement: %d" % step)
 map.free()
 environment.free()
 camera.free()
 print("Orbit/sun visibility: 15 rendered angle/zoom cases and 17 sun camera poses, %d failures" % failures)
 quit(1 if failures else 0)
