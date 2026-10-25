extends SceneTree
const Data = preload("res://scripts/presentation/star_system/visual_system.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
 for i in range(8): await process_frame
func capture(name: String) -> void:
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.godot/testlogs/refinement-"+name+".png")
func run() -> void:
 var map = preload("res://scenes/star_system_3d.tscn").instantiate()
 map.player_profile = preload("res://ships/player/endeavour.tres")
 root.add_child(map)
 var entries: Array = []
 var kinds = ["mining_operation","research_station","quarantined_colony","spatial_anomaly","derelict_starship","battle"]
 for i in range(6): entries.append({"index":i,"name":"Encounter %d" % i,"text":"Encounter","tooltip":"Existing destination","model_kind":kinds[i],"color":[Color.ORANGE,Color.CYAN,Color.LIGHT_GREEN,Color.VIOLET,Color.SLATE_GRAY,Color.INDIAN_RED][i],"completed":false})
 entries[5].profile = preload("res://ships/enemy/marauder.tres")
 entries.append({"index":-2,"name":"Trading Outpost","text":"Outpost","tooltip":"Outpost","model_kind":"trading_outpost","color":Color.TURQUOISE,"completed":false})
 var seeds: Dictionary = {}
 for seed_value in range(1,100):
  var data: Dictionary = Data.generate(seed_value,1,entries,map.settings)
  if not seeds.has(data.planets.size()): seeds[data.planets.size()] = seed_value
 for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1680,720)]:
  root.size = dimensions
  map.configure(entries,-1,0.15,seeds[4])
  await settle()
  var marker = map.markers[0]
  var bounds: Vector2 = marker.size
  var position: Vector2 = marker.position
  var available: Color = marker.get_theme_color("font_color")
  marker.set_state(false,true,false)
  check(marker.get_theme_color("font_disabled_color")==available,"Temporary blocking preserves category color")
  check(not marker.completed and marker.unavailable,"Temporary blocking is separate from completion")
  marker.set_state(true,false,false)
  check(marker.get_theme_color("font_color")!=available,"Completion is visibly subdued")
  check(marker.priority()==0,"Completed marker has lowest priority")
  marker.set_state(false,false,true)
  check(marker.get_theme_stylebox("normal").shadow_size>0 and marker.priority()==2,"Selection has restrained glow and highest priority")
  check(marker.size==bounds and marker.position==position,"Highlight never scales or repositions touch bounds")
  for state in ["normal","hover","pressed","focus","disabled"]:
   check(marker.get_theme_stylebox(state).bg_color.a==0.5,"All marker states preserve half-opacity background")
  check(marker.get_theme_color("font_color").a==1.0,"Icon opacity remains independent")
  marker.set_state(false,false,false)
  marker.grab_focus()
  check(marker.highlighted(),"Keyboard focus highlights marker")
  marker.release_focus()
  entries[0].completed = true
  map.configure(entries,-1,0.15,seeds[4])
  map.camera.cancel()
  map.camera.overview(map.settings,true)
  map._select_destination(1)
  await settle()
  check(map.markers[0].completed and map.markers[1].selected,"Actual map propagates completion and selection")
  check(map.markers[1].z_index>map.markers[0].z_index,"Selected marker draws above completed marker")
  await capture("states-%d" % dimensions.x)
  # A deliberately crowded projection must retain anchors and deterministic hit tests.
  var original: Vector3 = map.objects[5].position
  map.objects[5].position = map.objects[1].position+Vector3(0.4,0,0)
  await settle()
  check(map.markers[5].secondary,"Secondary overlap reduces border emphasis")
  var selected_marker = map.markers[1]
  var anchor: Vector2 = selected_marker.position+selected_marker.anchor_point
  var claims := 0
  for other in map.markers.values():
   if not other.disabled and other._has_point(anchor-other.position): claims += 1
  check(claims==1,"Crowded markers resolve one model tap")
  await capture("crowded-%d" % dimensions.x)
  map.objects[5].position = original
  map._block_markers()
  await settle()
  check(not map.markers[1].completed,"Gesture blocking never marks an encounter completed")
  map._end_pinch()
  map.overview()
  await create_timer(0.9).timeout
  check(map.selected_index==-1,"Overview clears selected presentation")
  entries[0].completed = false
 map.run_seed = seeds[2]
 map.configure(entries,-1,0.5,seeds[2]+10000)
 map._select_destination(1)
 await settle()
 await capture("two-planets")
 map.run_seed = seeds[4]
 map.settings = map.settings.duplicate(true)
 map.settings.background_strength = 1
 map.settings.background_layers[0].opacity = 0.7
 map.configure(entries,-1,0.5,seeds[4]+20000)
 await settle()
 await capture("bright")
 map.settings.background_strength = 0
 map.configure(entries,-1,0.5,seeds[4]+30000)
 await settle()
 await capture("dark")
 map.travel(1)
 await process_frame
 check(map.markers[1].selected,"Destination activation highlights immediately")
 await capture("travel")
 map.free()
 print("Star map readability: %d checks, %d failures" % [checks,failures])
 quit(1 if failures else 0)
