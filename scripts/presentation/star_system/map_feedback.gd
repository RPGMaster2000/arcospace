extends Node3D
# Scene-local, reusable map feedback only; no navigation decisions or gameplay RNG.
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const Sfx = preload("res://scripts/audio/sfx.gd")
var camera: Camera3D
var canvas: Control
var player_marker: Control
var ship: Node3D
var identification: MeshInstance3D
var pulse: MeshInstance3D
var pulse_motion: Tween
var engine_audio: AudioStreamPlayer
var engine_level := 0.0
var moving := false
var tactical := false
var suppressed := false
var locator_phase := 0.0
var offscreen := false
@export var arrow_margin := Vector4(28, 90, 28, 180)
var direction_arrow: Control
var exclusion_regions: Callable
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
 direction_arrow = Control.new()
 direction_arrow.name = "PlayerDirectionArrow"
 direction_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
 direction_arrow.z_index = 18
 direction_arrow.draw.connect(func():
  direction_arrow.draw_circle(Vector2.ZERO,16,Color(0.01,0.04,0.08,0.85))
  direction_arrow.draw_colored_polygon(PackedVector2Array([Vector2(14,0),Vector2(-9,-8),Vector2(-4,0),Vector2(-9,8)]),Color("a7efff")))
 canvas.add_child(direction_arrow)
 identification = Models.ring(self,0.65,Color(0.3,0.85,1.0,0.5))
 identification.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 identification.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 identification.material_override.no_depth_test = true
 identification.material_override.render_priority = 21
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
 player_marker.visible = not tactical and not camera.is_position_behind(ship.position)
 identification.visible = not tactical
 player_marker.position = camera.unproject_position(ship.position)
 var heading: Vector2 = camera.unproject_position(ship.position+ship.basis.x)-player_marker.position
 player_marker.rotation = heading.angle()+PI*0.5
 identification.position.y = -0.22
 locator_phase = fmod(locator_phase + delta * 0.65,1.0)
 var depth := maxf(0.1,-camera.to_local(ship.global_position).z)
 var pixel_radius := depth * tan(deg_to_rad(camera.fov * 0.5)) * 24.0 / maxf(1.0,canvas.size.y)
 identification.scale = Vector3.ONE * maxf(1.0,pixel_radius/0.65) * (1.0+locator_phase*0.35)
 identification.material_override.albedo_color = Color(0.3,0.85,1.0,0.2+(1.0-locator_phase)*0.35)
 update_direction(camera.unproject_position(ship.global_position),camera.is_position_behind(ship.global_position))
 engine_level = move_toward(engine_level,(0.12 if tactical else 1.0) if moving else 0.0,delta*5.0)
 if engine_audio.playing:
  engine_audio.volume_db = lerpf(-60,engine_volume,engine_level)
  if not moving and engine_level <= 0.0: engine_audio.stop()

# Pure screen geometry with hysteresis. Large bottom/top insets protect the
# existing action/status bars; the arrow never receives pointer events.
func update_direction(projected: Vector2, behind: bool = false) -> void:
 var viewport := Rect2(Vector2.ZERO,canvas.size)
 var inset := 36.0 if offscreen else 12.0
 offscreen = behind or not viewport.grow(-inset).has_point(projected)
 direction_arrow.visible = offscreen and not tactical and not suppressed
 if not direction_arrow.visible: return
 var safe := Rect2(Vector2(arrow_margin.x,arrow_margin.y),canvas.size-Vector2(arrow_margin.x+arrow_margin.z,arrow_margin.y+arrow_margin.w))
 if OS.has_feature("android"):
  var window := Vector2(DisplayServer.window_get_size())
  var safe_area := DisplayServer.get_display_safe_area()
  if window.x > 0 and window.y > 0:
   var scale := canvas.size/window
   var usable := Rect2(Vector2(safe_area.position)*scale,Vector2(safe_area.size)*scale)
   if usable.has_area(): safe = safe.intersection(usable.grow(-20))
 var center := safe.get_center()
 var direction := projected-center
 if behind: direction = -direction
 if direction.length_squared() < 0.001: direction = Vector2.UP
 var half := safe.size * 0.5
 var extent := minf(half.x/maxf(0.001,absf(direction.x)),half.y/maxf(0.001,absf(direction.y)))
 var desired := center + direction * extent
 var obstacles: Array = exclusion_regions.call() if exclusion_regions.is_valid() else []
 var best := desired
 if obstacles.any(func(rect): return rect.grow(20).has_point(desired)):
  var best_distance := INF
  for step in range(25):
   var t := float(step)/24.0
   for at in [Vector2(lerpf(safe.position.x,safe.end.x,t),safe.position.y),Vector2(lerpf(safe.position.x,safe.end.x,t),safe.end.y),Vector2(safe.position.x,lerpf(safe.position.y,safe.end.y,t)),Vector2(safe.end.x,lerpf(safe.position.y,safe.end.y,t))]:
    if obstacles.any(func(rect): return rect.grow(20).has_point(at)): continue
    var distance: float = at.distance_squared_to(desired)
    if distance < best_distance:
     best_distance = distance
     best = at
  if best_distance == INF:
   direction_arrow.hide()
   return
 direction_arrow.position = best
 direction_arrow.rotation = (projected-best).angle() if not behind else direction.angle()
 direction_arrow.queue_redraw()

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
 if is_instance_valid(direction_arrow): direction_arrow.queue_free()
 if is_instance_valid(player_marker): player_marker.queue_free()
 if is_instance_valid(player_marker): player_marker.queue_free()
