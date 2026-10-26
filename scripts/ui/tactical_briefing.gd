extends VBoxContainer
# Read-only tactical UI; the expedition retains all entry and gameplay decisions.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Preview = preload("res://scripts/ui/enemy_sensor_preview.gd")

func label(value: String, font_size: int = 17, color := Color("c6d7e3")) -> Label:
 var node = Label.new()
 node.text = value
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 node.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
 node.add_theme_font_override("font",Presentation.UI_FONT)
 node.add_theme_font_size_override("font_size",font_size)
 node.add_theme_color_override("font_color",color)
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return node

func section(parent: Node, caption: String, tint := Color("59869a")) -> VBoxContainer:
 var panel = PanelContainer.new()
 panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 var style = Presentation.style(tint)
 style.bg_color = Color("132b3c")
 style.content_margin_left = 12
 style.content_margin_right = 12
 style.content_margin_top = 5
 style.content_margin_bottom = 5
 panel.add_theme_stylebox_override("panel",style)
 parent.add_child(panel)
 var column = VBoxContainer.new()
 column.add_theme_constant_override("separation",3)
 panel.add_child(column)
 column.add_child(label(caption,13,tint.lightened(0.3)))
 return column

func configure(enemy: Resource, level: int, modifier: int, pending: String, pursuit: bool, boss: bool) -> void:
 add_theme_constant_override("separation",3)
 add_child(label("SUBLIGHT INTERCEPTION" if pursuit else "HOSTILE CONTACT DETECTED",13,Color("ed7777")))
 var heading = HBoxContainer.new()
 add_child(heading)
 var name_label = label(enemy.ship_name,28,Color("f0f4f7"))
 name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
 heading.add_child(name_label)
 var danger = label("DANGER",15,Color("ff9da9"))
 danger.autowrap_mode = TextServer.AUTOWRAP_OFF
 danger.custom_minimum_size.x = 70
 var badge = PanelContainer.new()
 var badge_style = Presentation.style(Color("be586a"))
 badge_style.bg_color = Color("42212c")
 badge.add_theme_stylebox_override("panel",badge_style)
 badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
 badge.add_child(danger)
 heading.add_child(badge)
 add_child(label("%s · Level %d" % [enemy.subtitle,level],16))
 var sensors = section(self,"TARGETING SENSORS                                      HOSTILE")
 var preview = Preview.new()
 preview.name = "EnemySensorPreview"
 preview.profile = enemy
 sensors.add_child(preview)
 var columns = HBoxContainer.new()
 columns.add_theme_constant_override("separation",8)
 add_child(columns)
 var systems = section(columns,"SHIP SYSTEMS")
 for key in ["hull_capacity","shields"]:
  var value: int = enemy.get(key)
  systems.add_child(label(("Hull" if key == "hull_capacity" else "Shields")+"     %d / %d" % [value,value]))
  var bar = ProgressBar.new()
  bar.show_percentage = false
  bar.custom_minimum_size.y = 7
  bar.max_value = maxi(1,value)
  bar.value = value
  var fill = StyleBoxFlat.new()
  fill.bg_color = Color("dd8596") if key == "hull_capacity" else Color("6cc4ea")
  bar.add_theme_stylebox_override("fill",fill)
  systems.add_child(bar)
 systems.add_child(label("Materials %d · Energy %d · Crew %d\nProduction %d / %d / %d" % [enemy.materials,enemy.energy,enemy.crew,enemy.synthesizer,enemy.reactor,enemy.quarters],15))
 var profile = section(columns,"TACTICAL PROFILE")
 profile.add_child(label(enemy.role,18,Color.WHITE))
 profile.add_child(label(enemy.summary if not enemy.summary.is_empty() else "No additional verified profile.",16))
 var modifiers = preload("res://scripts/combat_modifier.gd")
 var tint: Color = modifiers.storm_color(modifier) if modifier in modifiers.STORMS else Color("c79751")
 var conditions = Button.new()
 conditions.name = "ModifierDetails"
 conditions.text = Presentation.icon(Presentation.modifier_key(modifier),Presentation.UI_FONT)+"  "+modifiers.NAMES[modifier]
 conditions.custom_minimum_size.y = 44
 conditions.add_theme_font_override("font",Presentation.UI_FONT)
 conditions.add_theme_font_size_override("font_size",17)
 Presentation.action(conditions)
 conditions.add_theme_color_override("font_color",tint.lightened(0.2))
 conditions.add_theme_stylebox_override("normal",Presentation.style(tint))
 conditions.tooltip_text = "Tap for modifier description"
 add_child(conditions)
 var overlay = preload("res://scripts/ui/info_overlay.gd").new()
 add_child(overlay)
 conditions.pressed.connect(func(): overlay.show_text("[b]"+conditions.text+"[/b]\n\n"+modifiers.description(modifier)))
 add_child(label("Entry effects: "+pending,16,Color("e8a3aa")))
 if boss: add_child(label("Mandatory contact · Resolve by victory or EMP Pulse.",16))
