extends SceneTree
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func settle():
 await create_timer(1.0).timeout
func capture(name: String):
 if DisplayServer.get_name() == "headless": return
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_webp("res://docs/tactical_focus_screenshots/"+name+".webp")
func run():
 var host = load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled = false
 host.rules = host.rules.duplicate()
 host.rules.debug_seed = 1042
 host.rules.log_rolls = false
 root.add_child(host)
 await settle()
 var map = host.star_map
 var rng_before: int = host.state.rng.state
 var battle_index := -1
 var poi_index := -1
 for i in range(host.state.encounters.size()):
  if host.state.encounters[i].kind == "battle": battle_index = i
  elif host.state.encounters[i].kind == "poi": poi_index = i
 host.map_destination = poi_index
 host.state.encounters[poi_index].poi = load("res://encounters/mining_operation.tres")
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size = dimensions
  host.show_poi(poi_index)
  await settle()
  check(host.screen.sidebar.size.x < root.get_visible_rect().size.x*0.43,"Normal panel <=42%")
  check(not host.header.get_node("Overlay/Caption").visible,"No redundant category heading")
  check(map.focus_orbit_enabled,"Normal focus permits camera orbit")
  for button in host.approach_buttons:
   if button.disabled:
    check(button.requirement_only and not button.details.visible,"Locked outcome concealed")
  await capture("normal-%d" % dimensions.x)
  var camera_before: Transform3D = map.camera.transform
  map.orbit_velocity = Vector2(0.2,0)
  await create_timer(0.2).timeout
  check(not map.camera.transform.is_equal_approx(camera_before),"Orbit moves camera")
  var saved_ship: Transform3D = map.ship.transform
  var enemy_node: Node3D = map.objects[battle_index]
  var saved_enemy: Transform3D = enemy_node.transform
  host.map_destination = battle_index
  host.show_battle_preview(battle_index)
  await settle()
  check(map.tactical_enemy == enemy_node,"Actual existing enemy model reused")
  check(map.orbit_index == -1 and not map.focus_orbit_enabled,"No orbit in tactical mode")
  check(map.camera.viewing == &"tactical","Tactical framing active")
  var preview = host.view.find_child("EnemySensorPreview",true,false)
  var left_basis: Basis = enemy_node.basis
  var preview_basis: Basis = preview.model.basis
  await create_timer(0.2).timeout
  check(enemy_node.basis.is_equal_approx(left_basis),"Cinematic enemy is not rotated by UI")
  check(not preview.model.basis.is_equal_approx(preview_basis),"Right-side sensor ship rotates independently")
  check(preview.overlay.get_parent()==preview,"Reticle belongs to right UI preview")
  check(host.screen.sidebar.size.x < root.get_visible_rect().size.x*0.53,"Tactical panel <=52%")
  check(host.return_button.is_visible_in_tree(),"Back accessible")
  await capture("hostile-%d" % dimensions.x)
  host.show_system()
  await settle()
  check(enemy_node.transform.is_equal_approx(saved_enemy),"Enemy transform restored")
  check(map.tactical_snapshot.is_empty(),"Temporary tactical state cleared")
 check(host.state.rng.state == rng_before,"Presentation does not consume expedition RNG")
 # Reuse every registered enemy model, including both larger elite hulls.
 var profiles: Array = preload("res://scripts/ships/ship_library.gd").ENEMIES.duplicate()
 profiles.append(load("res://ships/enemy/marauder_vanguard.tres"))
 profiles.append(load("res://ships/enemy/sentinel_dreadnought.tres"))
 for profile in profiles:
  host.state.encounters[battle_index].enemy_data = profile
  map.configured_seed = -9999
  host.show_system()
  host.map_destination = battle_index
  host.show_battle_preview(battle_index)
  await settle()
  var point: Vector2 = map.camera.unproject_position(map.tactical_enemy.position)
  check(point.x>0 and point.x<map.size.x*0.5 and point.y>80 and point.y<map.size.y,"Enemy %s framed left" % profile.ship_name)
  check(map.ship.position.distance_to(map.tactical_enemy.position)>0.5,"Ships stay separated")
  var fits := true
  for mesh in map.tactical_enemy.find_children("*","MeshInstance3D",true,false):
   if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
   var bounds: AABB = mesh.mesh.get_aabb()
   for corner in range(8):
    var screen_point: Vector2 = map.camera.unproject_position(mesh.to_global(bounds.get_endpoint(corner)))
    fits = fits and screen_point.x>0 and screen_point.x<map.size.x*0.5 and screen_point.y>80 and screen_point.y<map.size.y
  check(fits,"Visible enemy geometry fits left viewing region: " + profile.ship_name)
  if profile.model_scene != null: await capture(profile.resource_path.get_file().get_basename())
 map.overview()
 # Every modifier remains authoritative, with a fixed, visible combat action.
 root.size = Vector2i(960,540)
 for kind in range(8):
  host.state.encounters[battle_index].modifier = kind
  host.map_destination = battle_index
  host.show_battle_preview(battle_index)
  await create_timer(0.27).timeout
  var entry = host.screen.sidebar.get_node("CombatEntry")
  check(root.get_visible_rect().encloses(entry.get_global_rect()),"Combat action visible for modifier %d" % kind)
  check(host.state.encounters[battle_index].modifier == kind,"Modifier identity unchanged")
 host.show_system()
 await settle()
 # Interception presentation uses the existing profile, never a second gameplay encounter.
 host.state.pending_destination = battle_index
 host.state.chasedown_index = host.state.encounters.size()
 var encounter: Dictionary = host.state.encounters[battle_index].duplicate()
 encounter.merge({"chasedown":true,"response":-1,"completed":false},true)
 host.state.encounters.append(encounter)
 host._show_chasedown()
 await settle()
 check(map.tactical_temporary,"Unmapped interceptor has one scene-local model")
 check(map.orbit_index == -1 and not map.focus_orbit_enabled,"Pursuit disables manual orbit")
 check(map.ship.basis.x.normalized().dot(map.tactical_enemy.basis.x.normalized())>0.99,"Pursuit ships share heading")
 await capture("chasedown")
 map.overview()
 await settle()
 check(map.tactical_snapshot.is_empty() and not is_instance_valid(map.tactical_enemy),"Interceptor presentation cleaned")
 host.queue_free()
 await process_frame
 print("Tactical focus: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
