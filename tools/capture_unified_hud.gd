extends SceneTree
var host: Control
var prefix := "before"
func _initialize(): call_deferred("run")
func shot(name: String):
 await create_timer(1.1).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_webp("res://docs/unified_hud_screenshots/"+prefix+"-"+name+".webp")
func run():
 if not OS.get_cmdline_user_args().is_empty(): prefix=OS.get_cmdline_user_args()[0]
 host=load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled=false
 host.rules=host.rules.duplicate()
 host.rules.debug_seed=1042
 host.rules.log_rolls=false
 root.add_child(host)
 var battle := -1
 var poi := -1
 for i in range(host.state.encounters.size()):
  if host.state.encounters[i].kind=="battle": battle=i
  else: poi=i
 host.state.encounters[poi].poi=load("res://encounters/mining_operation.tres")
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.content_scale_size=dimensions
  root.size=dimensions
  host.show_system()
  await shot("overview-%d"%dimensions.x)
  host.map_destination=poi
  host.show_poi(poi)
  await shot("poi-%d"%dimensions.x)
  host.map_destination=battle
  host.show_battle_preview(battle)
  await shot("combat-%d"%dimensions.x)
  host.show_system()
  host.state.pending_destination=battle
  host.state.chasedown_index=host.state.encounters.size()
  var entry: Dictionary=host.state.encounters[battle].duplicate()
  entry.merge({"chasedown":true,"response":-1,"completed":false},true)
  host.state.encounters.append(entry)
  host._show_chasedown()
  await shot("chasedown-%d"%dimensions.x)
  host.state.encounters.pop_back()
  host.state.chasedown_index=-1
 host.free()
 quit()
