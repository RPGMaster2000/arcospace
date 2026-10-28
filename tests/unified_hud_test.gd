extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
 # Retained exploration-mode regression.
 var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
 regression_rules.game_mode = "exploration"
 call_deferred("run")
func check(ok: bool, message: String):
 checks+=1
 if not ok:
  failures+=1
  push_error(message)
func settle():
 for i in range(24): await process_frame
func run():
 var host=load("res://scenes/expedition.tscn").instantiate()
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
 var hud=host.screen.overview_hud
 var bar=host.resource_bar
 var identities: Array=bar.entries.values()
 var rng: int=host.state.rng.state
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720),Vector2i(1560,720)]:
  root.content_scale_size=dimensions
  root.size=dimensions
  host.show_system()
  await settle()
  check(hud.panels[0].size.y<65,"Single-line economy strip")
  check(hud.resources.get_child_count()==4,"All four economy controls reused")
  check(hud.panels[0].get_global_rect().end.x<hud.panels[3].global_position.x,"Economy does not overlap FTL")
  check(hud.panels[2].global_position.y>root.get_visible_rect().size.y*0.6,"Ship status lower left")
  check(hud.panels[3].global_position.x>root.get_visible_rect().size.x*0.6,"FTL upper right")
  for panel in [hud.panels[0],hud.panels[2],hud.panels[3],hud.panels[4]]:
   check(root.get_visible_rect().encloses(panel.get_global_rect()),"HUD fits screen "+str(dimensions))
  for mode in ["poi","preview"]:
   host.map_destination=poi if mode=="poi" else battle
   if mode=="poi": host.show_poi(poi)
   else: host.show_battle_preview(battle)
   await settle()
   check(hud.visible and hud.active and hud.focused,"Persistent edge HUD in "+mode)
   check(not hud.panels[3].is_visible_in_tree() and not hud.panels[4].is_visible_in_tree(),"Exploration controls hidden")
   check(not host.heading_row.visible and not host.resource_bar.get_global_rect().intersects(root.get_visible_rect()),"Legacy bar stays offscreen")
   for panel in [hud.panels[0],hud.panels[2]]:
    check(not panel.get_global_rect().intersects(host.screen.sidebar.get_global_rect()),"HUD clears contextual panel")
    check(not panel.get_global_rect().intersects(host.return_button.get_global_rect()),"HUD clears Back")
   check(host.return_button.is_visible_in_tree(),"Back remains accessible")
   if mode=="preview":
    check(host.view.find_child("EnemySensorPreview",true,false)==null,"No duplicate enemy viewport")
    check(host.scroll.get_v_scroll_bar().max_value<=host.scroll.get_v_scroll_bar().page+1,"Tactical panel does not scroll "+str(dimensions))
   else:
    var map=host.star_map
    var mouse=InputEventMouseMotion.new()
    mouse.relative=Vector2(8,-12)
    map.orbit_pointer=-1
    map._focus_input(mouse)
    check(map.orbit_velocity.is_equal_approx(Vector2(-0.48,-0.72)),"Mouse horizontal unchanged, vertical inverted")
    var touch=InputEventScreenDrag.new()
    touch.index=0
    touch.relative=Vector2(-8,12)
    map.orbit_pointer=0
    map._focus_input(touch)
    check(map.orbit_velocity.is_equal_approx(Vector2(0.48,0.72)),"Touch horizontal unchanged, vertical inverted")
    for button in host.approach_buttons:
     if button.disabled:
      check(button.requirement_only and not button.details.visible,"Locked option conceals outcomes")
  check(identities==bar.entries.values(),"Same controls across focus transitions")
  host.show_system()
  await settle()
  check(hud.panels[3].visible and hud.panels[4].visible,"Overview restores utilities")
 # All modifiers and authored enemy profiles, including larger elite hulls.
 root.content_scale_size=Vector2i(960,540)
 root.size=Vector2i(960,540)
 host.state.pending_bonuses = {"materials":3,"energy":5,"crew":2,"shields":4,"emp_pulse_charge":3}
 host.state.pending_penalties = {"energy":-3,"shields":-4,"emp_pulse_offline":2}
 var profiles: Array=preload("res://scripts/ships/ship_library.gd").ENEMIES.duplicate()
 profiles.append(load("res://ships/enemy/marauder_vanguard.tres"))
 profiles.append(load("res://ships/enemy/sentinel_dreadnought.tres"))
 for enemy in profiles:
  host.state.encounters[battle].enemy_data=enemy
  for modifier in range(8):
   host.state.encounters[battle].modifier=modifier
   host.state.encounters[battle].mandatory_boss=true
   host.map_destination=battle
   host.show_battle_preview(battle)
   await settle()
   check(host.scroll.get_v_scroll_bar().max_value<=host.scroll.get_v_scroll_bar().page+1,"Fits: %s modifier %d"%[enemy.ship_name,modifier])
   var button=host.view.find_child("ModifierDetails",true,false)
   button.pressed.emit()
   var overlay=button.get_parent().find_children("*","CanvasLayer",true,false)[0]
   check(overlay.shade.visible and overlay.body.text.contains(host.state.Modifiers.description(modifier)),"Full modifier description opens")
   overlay.dismiss()
 # Interception keeps the persistent HUD and four authoritative response choices.
 host.show_system()
 host.state.pending_bonuses = {"materials":3,"energy":5,"crew":2,"shields":4,"emp_pulse_charge":3}
 host.state.pending_penalties = {"energy":-3,"shields":-4,"emp_pulse_offline":2}
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.content_scale_size=dimensions
  root.size=dimensions
  host.state.pending_destination=battle
  host.state.chasedown_index=host.state.encounters.size()
  var entry: Dictionary=host.state.encounters[battle].duplicate()
  entry.merge({"chasedown":true,"response":-1,"completed":false},true)
  host.state.encounters.append(entry)
  host._show_chasedown()
  await settle()
  check(host.scroll.get_v_scroll_bar().max_value<=host.scroll.get_v_scroll_bar().page+1,"Chasedown and entry effects fit "+str(dimensions))
  check(hud.focused and hud.panels[0].visible and hud.panels[2].visible,"Chasedown essential HUD persists")
  check(not hud.panels[2].get_global_rect().intersects(host.screen.sidebar.get_global_rect()),"Stacked EMP status clears tactical panel")
  for marker in host.star_map.markers.values(): check(not marker.visible,"Exploration PoI labels hidden in focus")
  for planet in host.star_map.planet_nodes.values(): check(not planet.get_node("OverviewName").visible,"Planet labels hidden in focus")
  check(not host.star_map.focus_orbit_enabled,"Chasedown camera is fixed")
  check(host.star_map.ship.basis.x.normalized().dot(host.star_map.tactical_enemy.basis.x.normalized())>0.99,"Pursuit shares travel direction")
  check(bar.entries.jump.get_node("Values/Base").text.contains("EMP"),"EMP status labeled explicitly")
  host.state.encounters.pop_back()
  host.state.chasedown_index=-1
  host.show_system()
  await settle()
  check(hud.panels[0].get_global_rect().end.x<hud.panels[3].global_position.x,"Stacked economy modifiers clear FTL")
 check(host.state.rng.state==rng,"HUD and camera leave gameplay RNG unchanged")
 host.free()
 print("Unified HUD: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
