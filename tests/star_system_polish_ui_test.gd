extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, message: String):
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize(): call_deferred("run")
func run():
 var host = load("res://scenes/expedition.tscn").instantiate()
 host.persistence_enabled = false
 host.rules = host.rules.duplicate()
 host.rules.debug_seed = 1042
 host.rules.log_rolls = false
 root.add_child(host)
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size = dimensions
  host.show_system()
  await create_timer(0.9).timeout
  for n in range(16): await process_frame
  var screen = host.screen
  var map = host.star_map
  check(screen.title.text==map.visual_data.name,"Header shows generated astronomical name only")
  check(screen.jump_button.get_parent()==screen.overview_hud.panels[3],"FTL lives in floating upper-right panel")
  check(screen.jump_button.disabled==not host.state.can_jump(),"FTL legality remains authoritative")
  check(root.get_visible_rect().encloses(screen.heading_row.get_global_rect()),"Header fits viewport")
  var previous: Control
  for control in screen.heading_row.get_children():
   if previous != null: check(previous.get_global_rect().end.x<=control.get_global_rect().position.x+1,"Header controls do not overlap")
   previous = control
  check(map.clip_contents and map.get_global_rect()==root.get_visible_rect(),"Map occupies viewport with HUD exclusion regions")
  var tag = map.markers[0]
  var original: Vector2 = tag.position
  tag.position = Vector2(0,-tag.size.y)
  check(not tag._has_point(tag.size*0.5),"Off-map clipped marker cannot intercept input")
  tag.position = original
  check(screen.overview_hud.utilities.get_child_count()==5 and not map.zoom_controls.visible,"Zoom controls fit map")
  var before: float = map.camera.zoom_target
  screen.overview_hud.utilities.get_child(4).pressed.emit()
  check(map.camera.zoom_target>before,"Plus button uses existing bounded zoom")
  map.camera.zoom_by(9999)
  check(map.camera.zoom_target==map.settings.maximum_zoom,"Zoom buttons retain max calibration")
  map.camera.zoom_by(0.00001)
  check(map.camera.zoom_target==map.settings.minimum_zoom,"Zoom retains min calibration")
  map.camera.zoom_target = map.settings.default_zoom
  map.camera.zoom_scale = map.settings.default_zoom
  host.state.ftl_access = true
  host.show_system()
  check(host.jump_button.disabled==not host.state.can_jump(),"Ready and boss states preserve eligibility")
  await create_timer(0.9).timeout
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.godot/testlogs/polish-overview-%d.png" % dimensions.x)
 host.show_poi(0) if host.state.encounters[0].kind=="poi" else host.show_battle_preview(0)
 check(host.screen.header.get_node("TextBacking").color.a==0,"PoI headline backing is transparent")
 host.state.start_upgrade_event(2)
 host.show_outcome()
 var modal = host.card_management
 modal.select_card(modal.gallery.cards[0])
 for dimensions in [Vector2i(960,540),Vector2i(1280,720),Vector2i(1680,720)]:
  root.size = dimensions
  for n in range(20): await process_frame
  check(modal.details.get_child_count()==2,"Upgrade preview contains only heading and upgraded card")
  var portrait = modal.details.get_child(1)
  check(portrait.get_global_rect().end.y <= modal.details_scroll.get_global_rect().end.y+1,"Entire upgrade card fits available height")
  check(portrait.card_scale<=1.2,"Upgrade enlargement stays modest")
  check(modal.footer.get_global_rect().end.y <= root.get_visible_rect().end.y,"Upgrade actions stay visible")
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.godot/testlogs/polish-upgrade-%d.png" % dimensions.x)
 host.free()
 print("Star system polish UI: %d checks, %d failures" % [checks,failures])
 quit(failures)
