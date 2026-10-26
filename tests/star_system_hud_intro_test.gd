extends SceneTree
var checks := 0
var failures := 0
func check(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize(): call_deferred("run")
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.godot/testlogs/corner-"+name+".png")
func run():
 var host = load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled = false
 host.play_system_intro = true
 host.rules = host.rules.duplicate()
 host.rules.debug_seed = 1042
 host.rules.log_rolls = false
 root.add_child(host)
 var map = host.star_map
 var hud = host.screen.overview_hud
 check(host.deck_button.disabled and host.jump_button.disabled,"Gameplay HUD actions blocked during intro")
 check(host.phase==host.Phase.INTRO and not map.interactive,"New-system introduction locks navigation from initialization")
 check(map.camera.viewing==&"introduction" and map.camera.position.length()<24,"First visible camera is close to sun")
 var saved_before: String = JSON.stringify(load("res://scripts/persistence/expedition_save.gd").encode(host.state))
 var rng: int = host.state.rng.state
 var ship: Vector3 = map.ship.position
 map.travel(0)
 check(not map.traveling,"Intro cannot initiate travel")
 await process_frame
 await capture("close")
 await create_timer(0.7).timeout
 check(hud.title.modulate.a>0 and hud.subtitle.modulate.a==0,"Title appears before subtitle")
 await capture("title")
 await create_timer(1.0).timeout
 check(hud.subtitle.modulate.a>0,"Subtitle follows one second later")
 check(not map.interactive and hud.panels[0].modulate.a==0,"HUD and input stay hidden during pullback")
 await capture("subtitle")
 await create_timer(2.6).timeout
 await capture("reveal")
 await create_timer(1.0).timeout
 check(host.phase==host.Phase.OVERVIEW and map.interactive,"One completed reveal unlocks overview")
 check(map.camera.zoom_scale==map.camera.zoom_target and map.camera.viewing==&"overview","Final zoom and target agree")
 for planet in map.visual_data.planets:
  for i in range(16):
   var at: Vector3 = map.VisualSystem.orbit_point(planet,TAU*i/16.0)
   check(Rect2(Vector2.ZERO,map.size).encloses(Rect2(map.camera.unproject_position(at),Vector2.ONE)),"Computed overview contains orbital extent")
 var final: Transform3D = map.camera.transform
 await create_timer(0.3).timeout
 check(map.camera.transform.is_equal_approx(final),"No post-intro snap or second overview motion")
 check(JSON.stringify(load("res://scripts/persistence/expedition_save.gd").encode(host.state))==saved_before,"Intro leaves complete save payload unchanged")
 check(host.state.rng.state==rng and map.ship.position==ship,"Introduction changes neither ship position nor gameplay RNG")
 check(not host.screen.ui.visible and hud.visible,"Overview has corner HUD rather than top bar")
 check(hud.utilities.get_child_count()==5,"One ordered Deck Reference Settings minus plus group")
 check(hud.utilities.get_child(3).text=="−" and hud.utilities.get_child(4).text=="+","Existing zoom controls moved, not duplicated")
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size=dimensions
  for frame in range(16): await process_frame
  check(map.get_global_rect()==root.get_visible_rect(),"Full-screen viewport "+str(dimensions))
  var regions = hud.regions()
  for a in range(hud.panels.size()):
   if not hud.panels[a].visible: continue
   check(root.get_visible_rect().encloses(hud.panels[a].get_global_rect()),"Corner fits viewport")
   for b in range(a+1,hud.panels.size()):
    if not hud.panels[b].visible: continue
    check(not hud.panels[a].get_global_rect().intersects(hud.panels[b].get_global_rect()),"Corner groups do not overlap")
  for key in ["materials","energy","crew"]:
   check(host.resource_bar.entries[key].get_parent()==hud.resources,"Same resource button and adjustments reused")
  check(host.resource_bar.entries.hull.get_parent()==hud.status,"Same repair interaction reused")
  await capture("hud-%d" % dimensions.x)
 # Exercise computed framing across visual seeds, orbital extents and aspect ratios.
 var entries: Array = []
 for index in range(6): entries.append({"index":index,"model_kind":["gas_giant","research_station","mining_operation","spatial_anomaly","derelict_starship","battle"][index]})
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size=dimensions
  for frame in range(4): await process_frame
  for number in range(1,16):
   var data: Dictionary = map.VisualSystem.generate(1000+number,number,entries,map.settings)
   var points: Array[Vector3] = []
   for planet in data.planets:
    for i in range(32): points.append(map.VisualSystem.orbit_point(planet,TAU*i/32.0))
   for at in data.anchors.values():
    for offset in [Vector3(3,3,3),Vector3(-3,-3,-3)]: points.append(at+offset)
   points.append(Vector3(3,3,3))
   points.append(Vector3(-3,-3,-3))
   map.camera.fit_system(points,map.settings)
   for point in points:
    check(not map.camera.is_position_behind(point) and Rect2(Vector2.ZERO,map.size).has_point(map.camera.unproject_position(point)),"Seeded orbital and PoI extents fit overview")
 check(host.state.rng.state==rng,"Framing sweep does not consume expedition RNG")
 # Save resume is presentation-only: no new persistent fields and no introduction replay.
 var data = {"state":host.state,"battle":{}}
 host.free()
 var resumed = load("res://scenes/expedition.tscn").instantiate()
 resumed.persistence_enabled=false
 resumed.resume_data=data
 root.add_child(resumed)
 check(resumed.phase==resumed.Phase.OVERVIEW and not resumed.star_map.introducing,"Continue restores overview without replay")
 resumed._introduce_system()
 await create_timer(0.15).timeout
 resumed._cancel_presentation()
 resumed.phase=resumed.Phase.OVERVIEW
 check(resumed.star_map.interactive and resumed.screen.overview_hud.panels[0].modulate.a==1,"Cancellation restores input and full HUD opacity")
 resumed.star_map.free()
 resumed.star_map=null
 resumed.show_system()
 for frame in range(4): await process_frame
 check(resumed.screen.overview_hud.utilities.get_child_count()==5,"Map replacement releases obsolete zoom controls")
 resumed.state.hull=0
 resumed.show_system()
 check(resumed.ui.visible and not resumed.screen.overview_hud.active,"Expedition defeat preserves its return screen")
 resumed.free()
 print("Corner HUD and introduction: %d checks, %d failures" % [checks,failures])
 quit(failures)
