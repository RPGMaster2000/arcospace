extends Control
# Overview-only layout and introduction typography. Reuses the screen's actual controls.
signal settled
var owner_screen: Control
var panels: Array[Control] = []
var reserved: Array[Rect2] = []
var resources: VBoxContainer
var status: VBoxContainer
var utilities: HBoxContainer
var hull_bar: ProgressBar
var identifier: Label
var title: Label
var subtitle: Label
var active := false
var originals: Dictionary = {}
var blocked_buttons: Dictionary = {}
var motion: Tween
var revision := 0
var system_name := ""
var system_number := 1

func _ready() -> void:
 set_anchors_and_offsets_preset(PRESET_FULL_RECT)
 mouse_filter = MOUSE_FILTER_IGNORE
 z_index = 100
 for corner in range(5):
  var panel := PanelContainer.new()
  var style := StyleBoxFlat.new()
  style.bg_color = Color(0.025,0.055,0.085,0.8)
  style.set_corner_radius_all(8)
  style.set_content_margin_all(5)
  panel.add_theme_stylebox_override("panel",style)
  add_child(panel)
  panels.append(panel)
  panel.minimum_size_changed.connect(func(): layout.call_deferred())
 identifier = Label.new()
 identifier.add_theme_font_size_override("font_size",20)
 panels[0].add_child(identifier)
 resources = VBoxContainer.new()
 resources.add_theme_constant_override("separation",2)
 panels[1].add_child(resources)
 status = VBoxContainer.new()
 status.add_theme_constant_override("separation",2)
 panels[2].add_child(status)
 hull_bar = ProgressBar.new()
 hull_bar.custom_minimum_size.y = 4
 hull_bar.show_percentage = false
 var fill := StyleBoxFlat.new()
 fill.bg_color = Color("6dc7d7")
 hull_bar.add_theme_stylebox_override("fill",fill)
 hull_bar.mouse_filter = MOUSE_FILTER_IGNORE
 utilities = HBoxContainer.new()
 utilities.add_theme_constant_override("separation",4)
 panels[4].add_child(utilities)
 title = Label.new()
 title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 title.add_theme_font_size_override("font_size",48)
 title.add_theme_color_override("font_outline_color",Color("03101d"))
 title.add_theme_constant_override("outline_size",4)
 title.mouse_filter = MOUSE_FILTER_IGNORE
 add_child(title)
 subtitle = Label.new()
 subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 subtitle.add_theme_font_size_override("font_size",22)
 subtitle.add_theme_color_override("font_outline_color",Color("03101d"))
 subtitle.add_theme_constant_override("outline_size",3)
 subtitle.mouse_filter = MOUSE_FILTER_IGNORE
 add_child(subtitle)
 resized.connect(layout)
 hide()

func move_control(control: Control, parent: Node) -> void:
 if not originals.has(control): originals[control] = [control.get_parent(),control.get_index()]
 control.reparent(parent)

func set_overview(enabled: bool) -> void:
 if active == enabled: return
 active = enabled
 if enabled:
  show()
  var bar = owner_screen.resource_bar
  # Snapshot sibling indices before removing any controls from a shared container.
  for control in [bar]+bar.entries.values()+[owner_screen.jump_button,owner_screen.deck_button,owner_screen.legend,owner_screen.settings_button]:
   originals[control] = [control.get_parent(),control.get_index()]
  move_control(bar,self) # Keeps heartbeat and its existing info overlay active.
  bar.position = Vector2(-1000,-1000)
  for key in ["salvage","materials","energy","crew"]: move_control(bar.entries[key],resources)
  move_control(bar.entries.hull,status)
  status.add_child(hull_bar)
  var row := HBoxContainer.new()
  row.name = "ShieldEmp"
  status.add_child(row)
  for key in ["shields","jump"]: move_control(bar.entries[key],row)
  bar.entries.jump.text = "EMP " + bar.entries.jump.text
  bar.entries.jump.get_node("Values/Base").text = "EMP " + bar.entries.jump.get_node("Values/Base").text
  for key in bar.entries:
   var button: Button = bar.entries[key]
   button.add_theme_font_size_override("font_size",17)
   for label in button.get_node("Values").get_children(): label.add_theme_font_size_override("font_size",17)
  move_control(owner_screen.jump_button,panels[3])
  owner_screen.jump_button.set_anchors_and_offsets_preset(PRESET_TOP_LEFT)
  for button in [owner_screen.deck_button,owner_screen.legend,owner_screen.settings_button]: move_control(button,utilities)
  owner_screen.ui.hide()
  refresh()
 else:
  cancel()
  # Restore in original sibling order so the focused screens keep their layout.
  var controls: Array = originals.keys()
  controls.sort_custom(func(a,b): return originals[a][1] < originals[b][1])
  for control in controls:
   if not is_instance_valid(control): continue
   var saved: Array = originals[control]
   if not is_instance_valid(saved[0]):
    control.get_parent().remove_child(control)
    control.queue_free()
    continue
   control.reparent(saved[0])
   saved[0].move_child(control,mini(saved[1],saved[0].get_child_count()-1))
  originals.clear()
  if hull_bar.get_parent()!=null: hull_bar.get_parent().remove_child(hull_bar)
  var row = status.get_node_or_null("ShieldEmp")
  if row != null: row.free()
  owner_screen.jump_button.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
  var emp: Button = owner_screen.resource_bar.entries.jump
  emp.text = emp.text.trim_prefix("EMP ")
  emp.get_node("Values/Base").text = emp.get_node("Values/Base").text.trim_prefix("EMP ")
  for button in owner_screen.resource_bar.entries.values():
   button.add_theme_font_size_override("font_size",20)
   for label in button.get_node("Values").get_children(): label.add_theme_font_size_override("font_size",20)
  hide()
  owner_screen.ui.show()
 layout()

func refresh() -> void:
 identifier.text = "%02d | %s" % [system_number,system_name]
 layout.call_deferred()

func layout() -> void:
 if not active: return
 var inset := Vector4(12,12,12,12)
 if OS.has_feature("android"):
  var safe: Rect2i = DisplayServer.get_display_safe_area()
  var window: Vector2i = DisplayServer.window_get_size()
  if window.x>0 and window.y>0 and safe.size.x>0:
   var ratio := size/Vector2(window)
   inset += Vector4(safe.position.x*ratio.x,safe.position.y*ratio.y,(window.x-safe.end.x)*ratio.x,(window.y-safe.end.y)*ratio.y)
 for panel in panels: panel.reset_size()
 panels[0].position = Vector2(inset.x,inset.y)
 panels[1].position = Vector2(inset.x,panels[0].position.y+panels[0].size.y+4)
 panels[2].position = Vector2(size.x-panels[2].size.x-inset.z,inset.y)
 panels[3].position = Vector2(inset.x,size.y-panels[3].size.y-inset.w)
 panels[4].position = size-panels[4].size-Vector2(inset.z,inset.w)
 title.position = Vector2(0,size.y*0.38)
 title.size = Vector2(size.x,70)
 subtitle.position = Vector2(0,size.y*0.38+76)
 subtitle.size = Vector2(size.x,36)
 reserved.clear()
 for panel in panels: reserved.append(panel.get_global_rect().grow(4))

func regions() -> Array[Rect2]:
 return reserved if active else []

func prepare_introduction(name_value: String, number: int) -> void:
 cancel()
 system_name = name_value
 system_number = number
 title.text = name_value.to_upper()
 subtitle.text = "SYSTEM %02d" % number
 title.modulate.a = 0
 subtitle.modulate.a = 0
 title.show()
 subtitle.show()
 for panel in panels:
  panel.modulate.a = 0
  panel.mouse_filter = MOUSE_FILTER_IGNORE
 for panel in panels:
  for button in panel.find_children("*","BaseButton",true,false):
   blocked_buttons[button] = [button.disabled,button.focus_mode]
   button.disabled = true
   button.focus_mode = Control.FOCUS_NONE
 mouse_filter = MOUSE_FILTER_STOP
 layout()

func introduce(duration: float) -> bool:
 var request: int = revision
 motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
 motion.tween_property(title,"modulate:a",1.0,0.6).set_delay(duration*0.08)
 motion.tween_property(subtitle,"modulate:a",1.0,0.5).set_delay(duration*0.28)
 motion.chain().tween_interval(maxf(0.0,duration*0.78-(duration*0.28+0.5)))
 motion.chain().tween_property(title,"modulate:a",0.0,duration*0.12)
 motion.parallel().tween_property(subtitle,"modulate:a",0.0,duration*0.12)
 for i in range(panels.size()):
  motion.parallel().tween_property(panels[i],"modulate:a",1.0,duration*0.06).set_delay(i*duration*0.0125+duration*0.12)
 motion.chain().tween_callback(settled.emit)
 await settled
 if request != revision or not is_inside_tree(): return false
 title.hide()
 subtitle.hide()
 restore_input()
 mouse_filter = MOUSE_FILTER_IGNORE
 for panel in panels: panel.mouse_filter = MOUSE_FILTER_STOP
 return true

func restore_input() -> void:
 for button in blocked_buttons:
  if is_instance_valid(button):
   button.disabled = blocked_buttons[button][0]
   button.focus_mode = blocked_buttons[button][1]
 blocked_buttons.clear()

func cancel() -> void:
 restore_input()
 revision += 1
 if motion and motion.is_valid(): motion.kill()
 if is_instance_valid(title):
  title.hide()
  subtitle.hide()
 for panel in panels:
  panel.modulate.a = 1
  panel.mouse_filter = MOUSE_FILTER_STOP
 mouse_filter = MOUSE_FILTER_IGNORE
 settled.emit()

func _exit_tree() -> void:
 cancel()
 if is_instance_valid(hull_bar) and hull_bar.get_parent()==null: hull_bar.free()

func attach_zoom(map: Control) -> void:
 if not active: return
 map.external_zoom_controls = true
 var buttons: Array = map.zoom_controls.get_children()
 for button in buttons: originals[button] = [button.get_parent(),button.get_index()]
 for button in buttons: move_control(button,utilities)
 layout.call_deferred()
