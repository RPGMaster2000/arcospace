extends SceneTree
# Check combat-time authored scales, conservative geometry enclosure (including hit
# movement), projected footprint and camera margins for every model/arena/ratio.
const Ships = preload("res://scripts/ships/ship_library.gd")
const Board3D = preload("res://scenes/board_3d.tscn")
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
 checks += 1
 if not value:
  failures += 1
  push_error(message)
func inspect(model: Node3D, camera: Camera3D, viewport: SubViewport):
 var shield:MeshInstance3D=model.get_node("Shield")
 var body:Node3D=model.get_node("Body")
 var max_radius := 0.0
 for part in body.find_children("*","MeshInstance3D",true,false):
  if part.mesh == null: continue
  for corner in range(8):
   var point:Vector3=part.to_global(part.mesh.get_aabb().get_endpoint(corner))
   for shake in [-0.08,0.08]:
    var displaced:Vector3=point+model.global_basis*Vector3(0,shake,0)
    max_radius=maxf(max_radius,shield.to_local(displaced).length())
 check(max_radius<=0.901,"Geometry and hit movement remain inside shield: "+model.scene_file_path+" radius="+str(max_radius))
 var basis:Basis=shield.global_basis
 var right:Vector3=camera.global_basis.x
 var up:Vector3=camera.global_basis.y
 var width := 2*Vector3(right.dot(basis.x),right.dot(basis.y),right.dot(basis.z)).length()
 var height := 2*Vector3(up.dot(basis.x),up.dot(basis.y),up.dot(basis.z)).length()
 check(width >= 3.8 and width <= 4.65,"Comparable shield width: "+model.scene_file_path)
 check(height >= 2.1 and height <= 2.6,"Comparable shield height: "+model.scene_file_path)
 check(absf(width*height-9.89)<0.08,"Uniform projected footprint area: "+model.scene_file_path)
 var visible:=Rect2(Vector2.ZERO,viewport.size)
 for i in range(32):
  var angle:=TAU*i/32.0
  for j in range(17):
   var polar:=PI*j/16.0
   var point:=shield.to_global(Vector3(sin(polar)*cos(angle),cos(polar),sin(polar)*sin(angle)))
   check(not camera.is_position_behind(point) and visible.has_point(camera.unproject_position(point)),"Shield fits viewscreen")
func run():
 var profiles:Array=[]
 profiles.append_array(Ships.PLAYERS)
 profiles.append_array(Ships.ENEMIES)
 profiles.append(load("res://ships/enemy/marauder_vanguard.tres"))
 profiles.append(load("res://ships/enemy/sentinel_dreadnought.tres"))
 var render := DisplayServer.get_name() != "headless"
 for index in range(profiles.size()):
  var profile:Resource=profiles[index]
  # One rendered comparison per profile; geometry validation covers every arena.
  for field in range(7 if not render else 1):
   var view=Board3D.instantiate()
   view.setup_settings={"player_ship":index%6,"enemy_data":profile,"modifier":field if field<6 else 0}
   if field==6:
    view.normal_battlefield=load("res://scenes/battlefield_planetary_orbit.tscn")
   view.get_node("BattleEffects").enabled=false
   view.get_node("ModifierDisplay").cinematic_enabled=false
   root.size=Vector2i(1280,720)
   root.add_child(view)
   view.enemy_timer.stop()
   for dims in [Vector2i(1280,720),Vector2i(1560,720),Vector2i(1680,720)]:
    root.size=dims
    for frame in range(3):await process_frame
    view.enemy_timer.stop()
    var viewport:SubViewport=view.get_node("BattleView/Viewport")
    var field_node:Node3D=viewport.get_node("Battlefield")
    var camera:Camera3D=field_node.get_node("Camera3D")
    for side in ["PlayerShip","EnemyShip"]:
     var model:Node3D=field_node.get_node(side)
     model.set_process(false)
     inspect(model,camera,viewport)
    if render:
     await RenderingServer.frame_post_draw
     DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
     root.get_texture().get_image().save_png("res://.godot/testlogs/shield-fit-%02d-%d.png"%[index,dims.x])
   view.free()
 print("Shield fit: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
