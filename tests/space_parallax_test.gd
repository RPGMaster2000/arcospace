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
 camera.position += Vector3(3,0,0)
 var moved_sky: Image = await picture()
 var sky_error := difference(sky,moved_sky)
 check(sky_error<0.0001,"Distant starfield must not jitter or translate during camera pan: %f" % sky_error)
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
 print("Space parallax pixels: sky pan error %.8f; debris pan difference %.8f; %d failures" % [sky_error,pan_error,failures])
 environment.free()
 camera.free()
 quit(1 if failures else 0)
