extends SceneTree
# Rendered regression: checks actual pixels, not just CPU node transforms.
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func picture() -> Image:
 for i in range(3): await process_frame
 await RenderingServer.frame_post_draw
 return root.get_texture().get_image()
func difference(a: Image, b: Image) -> float:
 var total := 0.0
 for y in range(0,a.get_height(),2):
  for x in range(0,a.get_width(),2):
   var first := a.get_pixel(x,y)
   var second := b.get_pixel(x,y)
   total += absf(first.r-second.r)+absf(first.g-second.g)+absf(first.b-second.b)
 return total/(a.get_width()*a.get_height()*0.75)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 if DisplayServer.get_name()=="headless":
  print("Space parallax pixel checks: skipped without a rendering device")
  quit()
  return
 root.size = Vector2i(960,540)
 var camera := Camera3D.new()
 root.add_child(camera)
 camera.fov = 29
 camera.current = true
 var settings = preload("res://scripts/presentation/star_system/map_settings.gd").new()
 settings.background_layers.clear()
 settings.background_strength = 0
 settings.stardust_density = 160
 var environment = preload("res://scripts/presentation/star_system/space_environment.gd").new()
 root.add_child(environment)
 var rng := RandomNumberGenerator.new()
 rng.seed = 982
 environment.configure(camera,settings,rng)
 for layer in environment.dust: layer.hide()
 var sky: Image = await picture()
 var stationary_sky: Image = await picture()
 check(difference(sky,stationary_sky)==0,"Distant stars remain stable with a stationary camera")
 camera.position += Vector3(3,0,0)
 var moved_sky: Image = await picture()
 var sky_error := difference(sky,moved_sky)
 check(sky_error>0.00001,"Distant starfield must show subtle parallax during camera pan: %f" % sky_error)
 check(settings.starfield_parallax/70.0 < settings.stardust_parallax/14.0,"Distant-star angular motion is weaker than nearby point motion")
 var sky_material: ShaderMaterial = environment.sky.material_override
 sky_material.set_shader_parameter("parallax",0.0)
 camera.position = Vector3.ZERO
 var infinite_sky: Image = await picture()
 camera.position.x = 3
 var infinite_pan: Image = await picture()
 check(difference(infinite_sky,infinite_pan)<0.0001,"Zero starfield parallax remains a supported calibration setting")
 sky_material.set_shader_parameter("parallax",settings.starfield_parallax)
 var distant := MeshInstance3D.new()
 distant.mesh = BoxMesh.new()
 distant.mesh.size = Vector3.ONE*10
 distant.position = Vector3(3,0,-100)
 var red := StandardMaterial3D.new()
 red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 red.albedo_color = Color.RED
 distant.material_override = red
 root.add_child(distant)
 var behind_sphere: Image = await picture()
 var center := behind_sphere.get_pixel(480,270)
 check(center.r>center.g+0.2,"Sky must not occlude objects beyond its geometric radius")
 distant.free()
 environment.sky.hide()
 for layer in environment.dust: layer.show()
 camera.position = Vector3.ZERO
 var dots: Image = await picture()
 var still: Image = await picture()
 check(difference(dots,still)==0,"White points remain pixel-stable while stationary")
 camera.position.x = 3
 var panned: Image = await picture()
 var pan_error := difference(dots,panned)
 check(pan_error>0.00001,"White points visibly move under camera pan: %f" % pan_error)
 camera.position.z = 2
 var zoomed: Image = await picture()
 check(difference(panned,zoomed)>0.00001,"White points show depth change during zoom")
 print("Space parallax pixels: sky pan difference %.8f; debris pan difference %.8f; %d failures" % [sky_error,pan_error,failures])
 environment.free()
 # Isolate procedural nebulae, galaxies and replacement PNG-style textures.
 for kind in range(3):
  camera.transform = Transform3D.IDENTITY
  var layer = preload("res://scripts/presentation/star_system/sky_layer.gd").new()
  layer.kind = mini(kind,1)
  layer.angular_position = Vector2(180,0)
  layer.apparent_size = Vector2(45,30)
  layer.opacity = 0.8
  if kind==2:
   var image := Image.create(4,4,false,Image.FORMAT_RGBA8)
   for y in range(4):
    for x in range(4): image.set_pixel(x,y,Color(x/3.0,y/3.0,0.5,0.8))
   layer.texture = ImageTexture.create_from_image(image)
  settings.background_layers.assign([layer])
  settings.background_strength = 1.0
  settings.stardust_enabled = false
  var backdrop = preload("res://scripts/presentation/star_system/space_environment.gd").new()
  root.add_child(backdrop)
  rng.seed = 982
  backdrop.configure(camera,settings,rng)
  backdrop.sky.hide()
  var original: Image = await picture()
  var idle: Image = await picture()
  check(difference(original,idle)==0,"Celestial layer remains stationary without camera movement: %d" % kind)
  camera.position.x = 3
  var translated: Image = await picture()
  check(difference(original,translated)<0.0001,"Zero-parallax celestial layer follows the current render camera without lag: %d" % kind)
  backdrop.layers[0].material_override.set_shader_parameter("sky_parallax",0.15)
  var parallax_start: Image = await picture()
  camera.position.x = 6
  var parallax_end: Image = await picture()
  check(difference(parallax_start,parallax_end)>0.00001,"Celestial layer supports smooth optional parallax: %d" % kind)
  camera.rotate_y(0.05)
  var turned: Image = await picture()
  check(difference(parallax_end,turned)>0.00001,"Celestial layer responds to camera orientation: %d" % kind)
  var settled: Image = await picture()
  check(difference(turned,settled)==0,"Celestial layer does not jitter after camera stops: %d" % kind)
  backdrop.free()
 camera.transform = Transform3D.IDENTITY
 var world_quad := MeshInstance3D.new()
 world_quad.mesh = QuadMesh.new()
 world_quad.mesh.size = Vector2(2,2)
 world_quad.position.z = -5
 var world_material := ShaderMaterial.new()
 world_material.shader = preload("res://shaders/cosmic_layer.gdshader")
 world_material.set_shader_parameter("billboard",true)
 world_material.set_shader_parameter("use_texture",true)
 world_material.set_shader_parameter("tint",Color.RED)
 world_material.set_shader_parameter("opacity",1.0)
 var white := Image.create(2,2,false,Image.FORMAT_RGBA8)
 white.fill(Color.WHITE)
 world_material.set_shader_parameter("source_texture",ImageTexture.create_from_image(white))
 world_quad.material_override = world_material
 root.add_child(world_quad)
 var world_visible: Image = await picture()
 check(world_visible.get_pixel(480,270).r>0.5,"Encounter celestial objects retain normal world-space rendering")
 world_quad.position.x = 10
 var world_moved: Image = await picture()
 var moved_center := world_moved.get_pixel(480,270)
 check(absf(moved_center.r-moved_center.g)<0.1,"Encounter celestial objects remain anchored to their world position")
 world_quad.free()
 print("Celestial layer pixel checks: %d failures" % failures)
 camera.free()
 quit(1 if failures else 0)
