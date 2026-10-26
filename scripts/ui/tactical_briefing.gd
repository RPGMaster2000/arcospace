extends VBoxContainer
# Read-only tactical facts. The controller owns entry, outcomes and combat state.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
var compact := false

const Text = preload("res://scripts/ui/expedition_text.gd")

func label(value: String, font_size: int = 20, color := Color("c6d7e3")) -> Label:
 var node = Label.new()
 node.text = value
 node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 node.add_theme_font_override("font",Presentation.UI_FONT)
 node.add_theme_font_size_override("font_size",font_size)
 node.add_theme_color_override("font_color",color)
 node.mouse_filter = Control.MOUSE_FILTER_IGNORE
 return node

func section(caption: String, tint := Color("59869a")) -> VBoxContainer:
 var panel = PanelContainer.new()
 var style = Presentation.style(tint)
 style.bg_color = Color("132b3c")
 style.set_content_margin_all(4 if compact else 8)
 panel.add_theme_stylebox_override("panel",style)
 add_child(panel)
 var column = VBoxContainer.new()
 column.add_theme_constant_override("separation",2 if compact else 4)
 panel.add_child(column)
 if not caption.is_empty(): column.add_child(label(caption,13 if compact else 14,tint.lightened(0.3)))
 return column

static func modifier_summary(kind: int) -> String:
 if kind in Modifiers.STORMS:
  return "%s effects ×2 / ×½ for %d rounds; both ships." % [Modifiers.storm_family(kind).capitalize(),Modifiers.ACTIVE_ROUNDS]
 match kind:
  1: return "%d%% chance / ship: %d damage, Shields first." % [roundi(Modifiers.ASTEROID_CHANCE*100),Modifiers.ASTEROID_DAMAGE]
  3: return "Both ships' Shields offline for %d rounds." % Modifiers.ACTIVE_ROUNDS
  4: return "%d%% initial hit rate; sensors drift each round." % (100-Modifiers.NEBULA_START)
  5: return "Tier 2 draw chance ×%.0f for both hands." % Modifiers.TEMPORAL_DROP_MULTIPLIER
 return "No environmental modifier."

func configure(enemy: Resource, level: int, modifier: int, pending: String, pursuit: bool, boss: bool) -> void:
 compact = pursuit or get_viewport_rect().size.y < 600
 add_theme_constant_override("separation",2 if compact else 6)
 add_child(label(enemy.ship_name,28 if compact else 34,Color("f0f4f7")))
 add_child(label(("⚠ SUBLIGHT INTERCEPTION" if pursuit else "⚠ HOSTILE · DANGER")+" · %s · Lv %d" % [enemy.subtitle,level],16 if compact else 20,Color("ff9da9")))
 var systems = section("" if compact else "ENEMY SYSTEMS")
 var defenses = HBoxContainer.new()
 defenses.add_theme_constant_override("separation",12)
 systems.add_child(defenses)
 for key in ["hull_capacity","shields"]:
  var column = VBoxContainer.new()
  column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  defenses.add_child(column)
  var value: int = enemy.get(key)
  column.add_child(label(("Hull" if key == "hull_capacity" else "Shields")+"  %d / %d" % [value,value],20 if compact else 22))
  var bar = ProgressBar.new()
  bar.show_percentage = false
  bar.custom_minimum_size.y = 10 if compact else 12
  bar.max_value = maxi(1,value)
  bar.value = value
  var fill = StyleBoxFlat.new()
  fill.bg_color = Color("dd8596") if key == "hull_capacity" else Color("6cc4ea")
  bar.add_theme_stylebox_override("fill",fill)
  column.add_child(bar)
 var reserves = HBoxContainer.new()
 reserves.add_theme_constant_override("separation",10)
 systems.add_child(reserves)
 for pair in [["materials","synthesizer",Color("ef9da8")],["energy","reactor",Color("8fc5ff")],["crew","quarters",Color("98ddb0")]]:
  var item = label("%s +%d/t · %d" % [Presentation.icon(pair[0],Presentation.UI_FONT),enemy.get(pair[1]),enemy.get(pair[0])],18,pair[2])
  item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
  reserves.add_child(item)
 var profile = section("" if pursuit and compact else ("TACTICAL · "+enemy.role if compact else "TACTICAL PROFILE"))
 if not compact: profile.add_child(label(enemy.role,22,Color.WHITE))
 profile.add_child(label(enemy.summary if not enemy.summary.is_empty() else "No additional verified profile.",18 if compact else 20))
 var tint: Color = Modifiers.storm_color(modifier) if modifier in Modifiers.STORMS else [Color("90abba"),Color("d9a45a"),Color.WHITE,Color("ffab67"),Color("bca3ed"),Color("74d8db")][mini(modifier,5)]
 var conditions = Button.new()
 conditions.name = "ModifierDetails"
 conditions.text = Presentation.icon(Presentation.modifier_key(modifier),Presentation.UI_FONT)+"  "+Modifiers.NAMES[modifier]
 conditions.custom_minimum_size.y = 44
 conditions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 conditions.add_theme_font_override("font",Presentation.UI_FONT)
 conditions.add_theme_font_size_override("font_size",22)
 Presentation.action(conditions)
 conditions.add_theme_color_override("font_color",tint.lightened(0.2))
 conditions.add_theme_stylebox_override("normal",Presentation.style(tint))
 conditions.tooltip_text = "Tap for modifier description"
 for state in ["normal","hover","pressed","disabled"]:
  var style = Presentation.style(tint,state=="pressed")
  style.set_content_margin_all(4)
  conditions.add_theme_stylebox_override(state,style)
 add_child(conditions)
 if compact:
  conditions.text += "\n"+modifier_summary(modifier)
  conditions.add_theme_font_size_override("font_size",17)
 else: add_child(label(modifier_summary(modifier),18,tint.lightened(0.3)))
 var overlay = preload("res://scripts/ui/info_overlay.gd").new()
 add_child(overlay)
 conditions.pressed.connect(func(): overlay.show_text("[b]"+conditions.text+"[/b]\n\n"+Modifiers.description(modifier)))
 var effects = RichTextLabel.new()
 effects.name = "EntryEffects"
 effects.bbcode_enabled = true
 effects.fit_content = true
 effects.scroll_active = false
 effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
 effects.add_theme_font_override("normal_font",Presentation.UI_FONT)
 effects.add_theme_font_size_override("normal_font_size",18)
 effects.add_theme_font_size_override("bold_font_size",18)
 effects.text = "Entry: "+Text.highlight_outcome(Text.effect_indicators(pending))
 add_child(effects)
 if boss: add_child(label("Mandatory · Victory or EMP Pulse required.",16 if compact else 18,Color("ff9da9")))
