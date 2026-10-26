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
 await create_timer(0.9).timeout
 for i in range(8): await process_frame
func capture(name: String):
 if DisplayServer.get_name()=="headless": return
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://.godot/testlogs/focus-"+name+".png")
func run():
 var host = load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled=false
 host.rules=host.rules.duplicate()
 host.rules.debug_seed=1042
 host.rules.log_rolls=false
 root.add_child(host)
 await settle()
 var map = host.star_map
 var hud_id: int = host.screen.overview_hud.get_instance_id()
 var back_id: int = host.return_button.get_instance_id()
 var return_connections: int = host.return_button.pressed.get_connections().size()
 var original_rng: int = host.state.rng.state
 var planet_index: int = map.visual_data.assignments.keys()[0]
 var poi = load("res://encounters/mining_operation.tres")
 host.state.encounters[planet_index]={"kind":"poi","poi":poi,"title":poi.title,"completed":false,"charge_awarded":false}
 host.map_destination=planet_index
 host.show_system()
 await create_timer(0.9).timeout
 var overview: Transform3D = map.camera.transform
 await capture("overview")
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size=dimensions
  host.show_poi(planet_index)
  check(host.screen.focus_transition,"Panel fade guards input immediately")
  check(not host.screen.allows_activation(),"Actions blocked during focus fade")
  await settle()
  check(host.screen.compact_focus and not host.heading_row.visible and host.resource_bar.position.x<0,"No legacy resource bar in focus")
  check(host.screen.overview_hud.visible and host.screen.overview_hud.focused and not map.interactive and not map.zoom_controls.visible,"Persistent HUD visible; exploration gestures suspended")
  check(host.return_button.get_parent()==host.screen and host.return_button.text=="Back","Existing Back control reused in upper-left")
  check(root.get_visible_rect().encloses(host.return_button.get_global_rect()),"Back is visible")
  check(host.return_button.get_instance_id()==back_id,"No duplicate Back controls")
  check(host.screen.sidebar.size.x<=820 and host.screen.sidebar.size.x>root.get_visible_rect().size.x*0.30,"Right panel is compact and capped on wide screens")
  check(host.header.title.get_theme_font_size("font_size")==30,"Larger category-colored PoI heading")
  check(host.screen.scroll.get_global_rect().end.y<=root.get_visible_rect().end.y,"Scrollable panel stays in viewport")
  for button in host.approach_buttons:
   check(button.requirement_only or button.heading.get_theme_font_size("font_size")==20,"Compact option typography")
  await capture("planet-%d" % dimensions.x)
  host.return_button.pressed.emit()
  await settle()
  check(map.camera.transform.is_equal_approx(overview),"Back preserves existing overview camera transform")
  check(host.screen.overview_hud.active and host.screen.overview_hud.get_instance_id()==hud_id,"Back restores same overview HUD")
  check(host.return_button.get_parent()==host.header.get_node("Overlay"),"Back returns to its original owner")
 # Existing authoritative balances are displayed without a second transaction implementation.
 host.state.salvage=37
 host.state.hull=20
 map.configured_seed=-9999
 host.state.service={"kind":"service","poi":load("res://encounters/trading_outpost.tres"),"title":"Trading Outpost","completed":false}
 host.show_system()
 host.map_destination=host.state.SERVICE_INDEX
 host.show_outpost()
 await settle()
 check(host.outpost_screen.get_child(0).text.contains("37"),"Outpost shows authoritative Salvage balance")
 check(host.outpost_screen.buttons[0].details.text.contains("20/"),"Repair option retains current Hull")
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size=dimensions
  await settle()
  check(root.get_visible_rect().encloses(host.screen.sidebar.get_global_rect()),"Outpost panel fits each landscape size")
  check(root.get_visible_rect().encloses(host.return_button.get_global_rect()),"Outpost Back stays visible")
  await capture("outpost-%d" % dimensions.x)
 await capture("outpost")
 var repair_cost: int = host.state.service_cost(0,2)
 host.outpost_screen.buttons[0].pressed.emit()
 host.outpost_screen.selector.value=2
 await settle()
 await capture("outpost-purchase")
 host.outpost_screen.confirm_button.pressed.emit()
 await settle()
 check(host.state.hull==22 and host.state.salvage==37-repair_cost,"Existing purchase path commits repair and exact cost once")
 host.state.pending_choice="resource"
 host.state.choice_amount=2
 host.show_outcome()
 await settle()
 check(host.screen.compact_focus and host.return_button.disabled,"Mandatory non-card rewards remain in Focus Mode and cannot be skipped")
 host.state.navigation_origin=host.state.SERVICE_INDEX
 var codec = load("res://scripts/persistence/expedition_save.gd").new()
 var restored = codec.decode(codec.encode(host.state),host.rules)
 check(restored!=null,"Pending resource reward remains compatible with existing save codec")
 var resumed = load("res://scenes/expedition.tscn").instantiate()
 resumed.persistence_enabled=false
 resumed.resume_data={"state":restored,"battle":{}}
 root.add_child(resumed)
 await settle()
 check(resumed.screen.compact_focus and resumed.star_map!=null and resumed.return_button.disabled,"Resume rebuilds focused model without exposing global HUD or skipping reward")
 resumed.free()
 host._attribute("energy")
 await settle()
 check(host.state.pending_choice.is_empty(),"Existing attribute selection resolves mandatory choice")
 var long_poi = poi.duplicate(true)
 long_poi.description="A detailed location description remains readable in the existing scroll area.\n".repeat(20)
 long_poi.approaches.append(long_poi.approaches[0])
 host.state.encounters[planet_index].poi=long_poi
 host.map_destination=planet_index
 host.show_poi(planet_index)
 await settle()
 check(host.scroll.get_v_scroll_bar().max_value>host.scroll.get_v_scroll_bar().page,"Long description and extra options scroll")
 check(host.return_button.get_global_rect().position.y<140,"Back remains pinned above scrolling content")
 await capture("long")
 var paid = poi.approaches[0].duplicate(true)
 paid.salvage_cost=3
 check(host.approach_text(paid).contains("Available: %d" % host.state.salvage),"Paid option shows authoritative available balance")
 var station_index := 0
 for key in map.markers:
  if key>=0 and not map.visual_data.assignments.has(key) and host.state.encounters[key].kind=="poi":
   station_index=key
   break
 host.state.encounters[station_index].poi=load("res://encounters/research_station.tres")
 host.map_destination=station_index
 host.show_poi(station_index)
 await settle()
 await capture("station")
 for visit in range(5):
  host.show_system()
  await settle()
  host.show_poi(planet_index)
  await settle()
 check(host.return_button.pressed.get_connections().size()==return_connections,"Repeated visits do not duplicate return signals")
 check(host.state.rng.state==original_rng,"Presentation consumes no expedition RNG")
 host.show_system()
 await create_timer(0.9).timeout
 await capture("return")
 check(map.camera.viewing==&"overview","Existing overview camera is restored")
 host.show_poi(station_index)
 await settle()
 host.screen.hide_for_battle()
 check(not host.return_button.is_visible_in_tree() and not host.screen.focus_backing.visible,"Battle hides both floating Back and focused panel")
 host.free()
 print("Compact PoI focus: %d checks, %d failures" % [checks,failures])
 quit(failures)
