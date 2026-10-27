extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize(): call_deferred("run")
func run():
 var host = load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled = false
 root.add_child(host)
 var first: Transform3D = host.star_map.camera.transform
 for i in range(12):
  await process_frame
  check(host.star_map.viewport.size==Vector2i(host.size),"Every visible frame uses final map bounds")
 check(host.star_map.camera.transform.is_equal_approx(first),"First camera transform is the settled default, with no initial zoom")
 check(host.star_map.viewport.size == Vector2i(host.size),"Viewport fits usable map before navigation")
 check(is_equal_approx(host.star_map.camera.zoom_scale,host.star_map.camera.zoom_target),"Fitted overview zoom initialized synchronously")
 var giant = load("res://scripts/presentation/star_system/destination_models.gd").build({"model_kind":"gas_giant"},RandomNumberGenerator.new())
 check(giant.get_node("Surface").mesh is SphereMesh,"Standalone gas giant is a sphere, not a station")
 check(giant.get_node("Surface").material_override.shader == preload("res://third_party/naejimer_planets/materials/gaseous.tres").shader,"Gas giant uses shared gaseous material")
 giant.free()
 var state = host.state
 state.encounters[0] = {"kind":"poi","poi":host.rules.pois[0],"title":"Origin","completed":false,"charge_awarded":false}
 state.encounters[1] = {"kind":"poi","poi":host.rules.pois[1],"title":"Destination","completed":false,"charge_awarded":false}
 state.navigation_origin = 0
 state.rules = state.rules.duplicate()
 state.rules.chasedown_chance = 1.0
 check(state.begin_travel(1,0.0) and state.travel_destination == -1,"Interception immediately cancels authoritative command")
 state.stop_intercepted_travel([1.25,0.0,-2.75])
 var Save = load("res://scripts/persistence/expedition_save.gd")
 var encoded = Save.encode(state)
 encoded.encounters[state.chasedown_index].intercept_position[0] = 9
 check(state.intercepted_position()[0]==1.25,"Save snapshot cannot mutate authoritative stop")
 encoded.encounters[state.chasedown_index].intercept_position[0] = 1.25
 var restored = Save.new().decode(encoded,state.rules)
 check(restored != null and restored.intercepted_position()==[1.25,0.0,-2.75],"Version 1 round-trip preserves actual stop")
 encoded.encounters[state.chasedown_index].erase("intercept_position")
 encoded.travel_destination = 1
 var legacy = Save.new().decode(encoded,state.rules)
 check(legacy == null,"Modern save rejects contradictory travel while an interception is unresolved")
 encoded.encounters[state.chasedown_index].intercept_position = ["bad",0,0]
 check(Save.new().decode(encoded,state.rules)==null,"Malformed optional coordinates are rejected")
 state._complete_encounter(state.chasedown_index)
 check(state.travel_destination == -1 and state.can_visit(1),"Completion unlocks fresh explicit travel")
 host.free()
 paused = true
 var entering = load("res://scenes/expedition.tscn").instantiate()
 entering.persistence_enabled = false
 root.add_child(entering)
 var entry_camera: Transform3D = entering.star_map.camera.transform
 for frame in range(6):
  await process_frame
  check(entering.star_map.viewport.size==Vector2i(entering.size),"Paused menu reveal already has final map bounds")
  check(entering.star_map.camera.transform.is_equal_approx(entry_camera),"Paused reveal cannot snap camera on resume")
 paused = false
 entering.free()
 print("Star system polish correctness: %d checks, %d failures" % [checks,failures])
 quit(failures)
