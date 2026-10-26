extends SubViewportContainer
# UI-only model preview. Its world, camera and rotation never touch the star map.
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
var profile: Resource
var model: Node3D
var overlay: Control

func _ready() -> void:
 stretch = true
 custom_minimum_size.y = 110
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 var viewport = SubViewport.new()
 viewport.size = Vector2i(640,110)
 viewport.own_world_3d = true
 viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
 viewport.transparent_bg = false
 add_child(viewport)
 var world = Node3D.new()
 viewport.add_child(world)
 var environment = WorldEnvironment.new()
 environment.environment = Environment.new()
 environment.environment.background_mode = Environment.BG_COLOR
 environment.environment.background_color = Color("091f2c")
 environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 environment.environment.ambient_light_color = Color("a4c2d7")
 environment.environment.ambient_light_energy = 0.7
 world.add_child(environment)
 model = Models.ship(profile)
 world.add_child(model)
 var radius := 0.1
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
  for i in range(8): radius = maxf(radius,mesh.to_global(mesh.mesh.get_aabb().get_endpoint(i)).length())
 var camera = Camera3D.new()
 camera.fov = 38
 world.add_child(camera)
 camera.position = Vector3(0,0.6,3.3)*radius
 camera.look_at(Vector3.ZERO)
 var light = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-35,-30,0)
 light.light_energy = 1.7
 world.add_child(light)
 overlay = Control.new()
 overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
 add_child(overlay)
 overlay.draw.connect(_draw_sensor)
 overlay.resized.connect(overlay.queue_redraw)

func _process(delta: float) -> void:
 if is_instance_valid(model) and is_visible_in_tree(): model.rotate_y(delta*0.3)

func _draw_sensor() -> void:
 var center: Vector2 = overlay.size*0.5
 var extent := Vector2(52,42)
 var cyan := Color("76b9cc")
 overlay.draw_arc(center,40,0,TAU,64,Color(0.3,0.7,0.8,0.4),1,true)
 for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
  var at: Vector2 = center+extent*corner
  overlay.draw_line(at,at-Vector2(corner.x*18,0),cyan,1.5,true)
  overlay.draw_line(at,at-Vector2(0,corner.y*18),cyan,1.5,true)
 for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
  overlay.draw_line(center+direction*45,center+direction*55,Color("ef6479"),1.5,true)
