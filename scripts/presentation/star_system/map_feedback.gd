extends Node3D
# Scene-local, reusable map feedback only; no navigation decisions or gameplay RNG.
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
var camera: Camera3D
var canvas: Control
var player_marker: Control
var ship: Node3D
var engines: Node3D
var identification: MeshInstance3D
var pulse: MeshInstance3D
var pulse_motion: Tween
var engine_audio: AudioStreamPlayer
var engine_level := 0.0
var moving := false
var engine_volume := -32.0

func _ready() -> void:
 player_marker = Control.new()
 player_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
 player_marker.z_index = 18
 player_marker.draw.connect(func():
  player_marker.draw_circle(Vector2.ZERO,9,Color(0.01,0.04,0.08,0.6))
  player_marker.draw_arc(Vector2.ZERO,9,0,TAU,24,Color(0.3,0.85,1.0,0.65),1.2,true)
  player_marker.draw_colored_polygon(PackedVector2Array([Vector2(0,-6),Vector2(-4,4),Vector2(0,2),Vector2(4,4)]),Color("a7efff")))
 canvas.add_child(player_marker)
 engines = Node3D.new()
 add_child(engines)
 identification = Models.ring(self,0.65,Color(0.3,0.85,1.0,0.5))
 identification.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 identification.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 identification.material_override.no_depth_test = true
 identification.material_override.render_priority = 21
 for z in [-0.16,0.16]:
  var mesh := CylinderMesh.new()
  mesh.top_radius = 0.09
  mesh.bottom_radius = 0.02
  mesh.height = 1.0
  mesh.radial_segments = 8
  mesh.cap_top = false
  mesh.cap_bottom = false
  var jet := Models.part(engines,mesh,Color(0.25,0.8,1.0,0.7),Vector3(-0.55,0,z))
  jet.rotation.z = -PI*0.5
  var exhaust := ShaderMaterial.new()
  exhaust.shader = preload("res://shaders/map_exhaust.gdshader")
  exhaust.render_priority = 20
  jet.material_override = exhaust
 var light := OmniLight3D.new()
 light.position.x = -0.25
 light.light_color = Color("54bfff")
 light.light_energy = 0.55
 light.omni_range = 1.5
 light.shadow_enabled = false
 engines.add_child(light)
 pulse = Models.ring(get_parent(),1.0,Color.WHITE)
 pulse.name = "SelectionPulse"
 pulse.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 pulse.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 pulse.material_override.no_depth_test = true
 pulse.material_override.render_priority = 12
 pulse.hide()
 engine_audio = AudioStreamPlayer.new()
 engine_audio.bus = &"SFX"
 add_child(engine_audio)

func set_travel(active: bool, arrival: bool = false) -> void:
 moving = active
 if active:
  Sfx.play(&"map_departure",self)
  var service = get_node_or_null("/root/Sfx")
  var event: Resource = service.catalog.find_event(&"map_engine") if service != null else null
  if event != null and event.enabled and not event.streams.is_empty() and event.streams[0] != null:
   var stream: AudioStream = event.streams[0].duplicate()
   if stream is AudioStreamWAV:
    stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    stream.loop_begin = 0
    stream.loop_end = stream.data.size() / (4 if stream.stereo else 2)
   elif stream is AudioStreamOggVorbis or stream is AudioStreamMP3: stream.loop = true
   engine_audio.stream = stream
   engine_volume = event.volume_db
   engine_audio.volume_db = -60
   engine_audio.pitch_scale = event.pitch_scale
   engine_audio.play()
 elif arrival:
  Sfx.play(&"map_arrival",self)

func acknowledge(at: Vector3, radius: float, tint: Color) -> void:
 if pulse_motion and pulse_motion.is_valid(): pulse_motion.kill()
 pulse.position = at + Vector3(0,-radius*0.3,0)
 pulse.scale = Vector3.ONE*maxf(0.5,radius*0.7)
 pulse.material_override.albedo_color = Color(tint,0.85)
 pulse.show()
 pulse_motion = create_tween().set_parallel(true)
 pulse_motion.tween_property(pulse,"scale",Vector3.ONE*maxf(1.7,radius*1.9),0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
 pulse_motion.tween_property(pulse.material_override,"albedo_color:a",0.0,0.5)
 pulse_motion.chain().tween_callback(pulse.hide)

func _process(delta: float) -> void:
 if not is_instance_valid(ship): return
 position = ship.position
 player_marker.visible = not camera.is_position_behind(ship.position)
 player_marker.position = camera.unproject_position(ship.position)
 var heading: Vector2 = camera.unproject_position(ship.position+ship.basis.x)-player_marker.position
 player_marker.rotation = heading.angle()+PI*0.5
 engines.basis = ship.basis.orthonormalized()
 identification.position.y = -0.22
 engine_level = move_toward(engine_level,1.0 if moving else 0.0,delta*5.0)
 engines.visible = visible
 for node in engines.get_children():
  if node is MeshInstance3D:
   # Keep the nozzle fixed while extending only the tail away from the ship.
   var length: float = lerpf(0.32,3.6,engine_level)
   node.scale.y = length
   node.position.x = -0.25-length*0.5
   node.material_override.set_shader_parameter("opacity",0.28+engine_level*0.55)
 if engine_audio.playing:
  engine_audio.volume_db = lerpf(-60,engine_volume,engine_level)
  if not moving and engine_level <= 0.0: engine_audio.stop()

func cancel() -> void:
 var service = get_node_or_null("/root/Sfx") if is_inside_tree() else null
 if service != null: service.stop_scope(get_instance_id())
 moving = false
 engine_level = 0.0
 if is_instance_valid(engine_audio): engine_audio.stop()
 if pulse_motion and pulse_motion.is_valid(): pulse_motion.kill()
 if is_instance_valid(pulse): pulse.hide()

func _exit_tree() -> void:
 cancel()
 if is_instance_valid(pulse): pulse.queue_free()
 if is_instance_valid(player_marker): player_marker.queue_free()
