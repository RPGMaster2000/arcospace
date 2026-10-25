extends SceneTree
const Marker = preload("res://scripts/presentation/star_system/poi_marker.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok:
  failures += 1
  push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var map = preload("res://scenes/star_system_3d.tscn").instantiate()
 map.player_profile = preload("res://ships/player/endeavour.tres")
 root.add_child(map)
 var entries: Array = []
 var index := 0
 for kind in Marker.ICONS:
  var symbol: String = Marker.ICONS[kind]
  check(Marker.EMOJI_FONT.has_char(symbol.unicode_at(0)),"Bundled emoji glyph exists for "+kind)
  check(Marker.icon_for(kind)==symbol,"Preferred emoji does not fall back: "+kind)
  if kind=="unknown": continue
  entries.append({"index":index,"name":kind,"text":kind,"tooltip":kind,"color":Color.CYAN,"completed":false,"model_kind":kind})
  index += 1
 # Exercise state/layout without adding any new gameplay encounter.
 var marker = Marker.new()
 marker.style_tag(Color.ORANGE)
 marker.set_label("Acubens IV",Marker.icon_for("mining_operation"),true)
 root.add_child(marker)
 var bounds: Vector2 = marker.size
 marker.set_state(false,false,true)
 check(marker.priority()==3,"Explicit selection outranks hover/focus")
 check(marker.get_theme_stylebox("normal").border_width_left==3,"Selection has strong outer border")
 check(marker.get_theme_stylebox("disabled").border_color==Color("b8faff"),"Disabled input retains unmistakable cyan selection")
 check(marker.get_theme_stylebox("normal").bg_color.a==0.5,"Stronger selection fill retains half opacity")
 check(marker.get_theme_stylebox("normal").bg_color.g>0.2,"Selection brightens background color")
 marker.set_state(false,true,true)
 check(marker.selected and not marker.completed and not marker.completion_badge.visible,"Travel blocking retains selection and never grants completion")
 marker.set_state(true,false,false)
 check(marker.completion_badge.visible,"Completed encounter displays prominent independent badge")
 check(marker.completion_badge.modulate.a==1.0,"Completion badge remains fully opaque")
 check(not marker.completion_badge.get_rect().intersects(marker.planet_name.get_rect()),"Completion badge never overlaps the planet name")
 check(marker.size==bounds and marker.get_theme_font_size("font_size")==28,"State changes preserve fixed marker/icon size")
 check(marker.self_modulate.a==1.0 and marker.self_modulate.r<1.0,"Completion dims category icon without fading content alpha")
 check(not marker.clip_contents,"Outer badge and pointer are not clipped")
 marker.set_state(false,false,false)
 check(not marker.completion_badge.visible and marker.self_modulate==Color.WHITE,"Available state clears completion presentation")
 for dimensions in [Vector2i(1280,720),Vector2i(960,540),Vector2i(1680,720)]:
  root.size = dimensions
  var grid := GridContainer.new()
  grid.columns = 6
  grid.position = Vector2(48,48)
  grid.add_theme_constant_override("h_separation",32)
  grid.add_theme_constant_override("v_separation",40)
  root.add_child(grid)
  for i in range(entries.size()):
   var entry: Dictionary = entries[i]
   var tag = Marker.new()
   tag.style_tag([Color.ORANGE,Color.CYAN,Color.LIGHT_GREEN][i%3])
   tag.set_label("Acubens IV",Marker.icon_for(entry.model_kind),i%2==0)
   tag.anchor_point = Vector2(tag.size.x*0.5,tag.size.y+12)
   tag.set_state(i%3==2,i%3==1,i%3==1)
   grid.add_child(tag)
  marker.hide()
  for frame in range(8): await process_frame
  if DisplayServer.get_name()!="headless":
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://.godot/testlogs/poi-emojis-%d.png" % dimensions.x)
  grid.free()
 marker.free()
 map.free()
 print("PoI iconography: %d checks; %d emoji mappings; %d failures" % [checks,Marker.ICONS.size(),failures])
 quit(1 if failures else 0)
