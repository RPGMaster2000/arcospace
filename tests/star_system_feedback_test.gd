extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void:
 # Retained exploration-mode regression.
 var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
 regression_rules.game_mode = "exploration"
 call_deferred("run")
func run():
 var host = load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled = false
 root.add_child(host)
 for n in range(12): await process_frame
 var map = host.star_map
 var feedback = map.feedback
 check(feedback.identification != null and feedback.engines.get_child_count()==3,"Player has identification ring, exhaust and one local light")
 var rng_before: int = host.state.rng.state
 var at: Vector3 = map.objects[0].position
 feedback.acknowledge(at,1.0,Color.CYAN)
 var pulse_id: int = feedback.pulse.get_instance_id()
 await create_timer(0.15).timeout
 check(feedback.pulse.visible and feedback.pulse.scale.x > 0.7,"Selection ring expands")
 feedback.acknowledge(at,1.0,Color.CYAN)
 check(feedback.pulse.get_instance_id()==pulse_id,"Repeated selection reuses one pulse")
 await create_timer(0.6).timeout
 check(not feedback.pulse.visible,"Pulse fades and cleans up")
 feedback.set_travel(true)
 await create_timer(0.15).timeout
 check(feedback.engine_level>0.5 and feedback.engine_audio.playing,"Travel brightens engines and plays quiet loop")
 feedback.set_travel(false,true)
 await create_timer(0.3).timeout
 check(not feedback.engine_audio.playing and feedback.engine_level==0,"Arrival fades engine loop out")
 for key in map.orbit_nodes:
  var planet = map.visual_data.planets[key]
  if planet.encounter != -1:
   map._select_destination(planet.encounter)
   check(is_equal_approx(map.orbit_nodes[key].material_override.get_shader_parameter("line_color").a,0.7),"Selected orbit alpha is 0.7")
 feedback.set_travel(true)
 map.set_active(false)
 check(not feedback.engine_audio.playing,"Hidden map stops engine audio")
 check(host.state.rng.state == rng_before,"Feedback consumes no gameplay RNG")
 host.free()
 print("Star system feedback: %d checks, %d failures" % [checks,failures])
 quit(failures)
