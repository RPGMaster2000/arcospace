extends VBoxContainer
# Read-only encounter facts. Build controls once; resize and content updates preserve identity.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
const Text = preload("res://scripts/ui/expedition_text.gd")
const COMPACT_HEIGHT := 600.0

var compact := false
var _enemy: Resource
var _level := 1
var _modifier := 0
var _pending := ""
var _pursuit := false
var _boss := false
var _fonts: Array = []
var _section_styles: Array[StyleBoxFlat] = []
var _section_columns: Array[VBoxContainer] = []
var _defenses: Dictionary = {}
var _reserves: Dictionary = {}
var _name_label: Label
var _contact: Label
var _systems_caption: Label
var _profile_caption: Label
var _role: Label
var _profile: Label
var _conditions: Button
var _mechanical_summary: Label
var _effects: RichTextLabel
var _boss_notice: Label
var _overlay: CanvasLayer


func _ready() -> void:
	get_viewport().size_changed.connect(_apply_layout)


func _label(value: String, small: int, large: int, color := Color("c6d7e3")) -> Label:
	var node := Label.new()
	node.text = value
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font", Presentation.UI_FONT)
	node.add_theme_color_override("font_color", color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fonts.append([node, small, large])
	return node


func _section(caption: String) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := Presentation.style(Color("59869a"))
	style.bg_color = Color("132b3c")
	panel.add_theme_stylebox_override("panel", style)
	_section_styles.append(style)
	add_child(panel)
	var column := VBoxContainer.new()
	_section_columns.append(column)
	panel.add_child(column)
	column.add_child(_label(caption, 13, 14, Color("59869a").lightened(0.3)))
	return column


static func modifier_summary(kind: int) -> String:
	if kind in Modifiers.STORMS:
		return "%s effects ×2 / ×½ for %d rounds; both ships." % [Modifiers.storm_family(kind).capitalize(), Modifiers.ACTIVE_ROUNDS]
	match kind:
		1: return "%d%% chance / ship: %d damage, Shields first." % [roundi(Modifiers.ASTEROID_CHANCE * 100), Modifiers.ASTEROID_DAMAGE]
		3: return "Both ships' Shields offline for %d rounds." % Modifiers.ACTIVE_ROUNDS
		4: return "%d%% initial hit rate; sensors drift each round." % (100 - Modifiers.NEBULA_START)
		5: return "Tier 2 draw chance ×%.0f for both hands." % Modifiers.TEMPORAL_DROP_MULTIPLIER
	return "No environmental modifier."


func configure(enemy: Resource, level: int, modifier: int, pending: String, pursuit: bool, boss: bool) -> void:
	_enemy = enemy
	_level = level
	_modifier = modifier
	_pending = pending
	_pursuit = pursuit
	_boss = boss
	if _name_label == null:
		_build()
	_refresh_content()
	_apply_layout()


func _build() -> void:
	_name_label = _label("", 28, 34, Color("f0f4f7"))
	add_child(_name_label)
	_contact = _label("", 16, 20, Color("ff9da9"))
	add_child(_contact)
	var systems := _section("ENEMY SYSTEMS")
	_systems_caption = systems.get_child(0)
	var defenses := HBoxContainer.new()
	defenses.add_theme_constant_override("separation", 12)
	systems.add_child(defenses)
	for key in ["hull_capacity", "shields"]:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		defenses.add_child(column)
		var value := _label("", 20, 22)
		column.add_child(value)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("dd8596") if key == "hull_capacity" else Color("6cc4ea")
		bar.add_theme_stylebox_override("fill", fill)
		column.add_child(bar)
		_defenses[key] = [value, bar]
	var reserves := HBoxContainer.new()
	reserves.add_theme_constant_override("separation", 10)
	systems.add_child(reserves)
	for pair in [["materials", Color("ef9da8")], ["energy", Color("8fc5ff")], ["crew", Color("98ddb0")]]:
		var item := _label("", 18, 18, pair[1])
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		reserves.add_child(item)
		_reserves[pair[0]] = item
	var profile := _section("TACTICAL PROFILE")
	_profile_caption = profile.get_child(0)
	_role = _label("", 22, 22, Color.WHITE)
	profile.add_child(_role)
	_profile = _label("", 18, 20)
	profile.add_child(_profile)
	_conditions = Button.new()
	_conditions.name = "ModifierDetails"
	_conditions.custom_minimum_size.y = 44
	_conditions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_conditions.add_theme_font_override("font", Presentation.UI_FONT)
	_conditions.tooltip_text = "Tap for modifier description"
	Presentation.action(_conditions)
	_conditions.pressed.connect(_show_modifier_rules)
	add_child(_conditions)
	_mechanical_summary = _label("", 18, 18)
	add_child(_mechanical_summary)
	_overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(_overlay)
	_effects = RichTextLabel.new()
	_effects.name = "EntryEffects"
	_effects.bbcode_enabled = true
	_effects.fit_content = true
	_effects.scroll_active = false
	_effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effects.add_theme_font_override("normal_font", Presentation.UI_FONT)
	_effects.add_theme_font_size_override("normal_font_size", 18)
	_effects.add_theme_font_size_override("bold_font_size", 18)
	add_child(_effects)
	_boss_notice = _label("Mandatory · Victory or EMP Pulse required.", 16, 18, Color("ff9da9"))
	add_child(_boss_notice)


func _refresh_content() -> void:
	_name_label.text = _enemy.ship_name
	_contact.text = ("⚠ SUBLIGHT INTERCEPTION" if _pursuit else "⚠ HOSTILE · DANGER") + " · %s · Lv %d" % [_enemy.subtitle, _level]
	for key in _defenses:
		var value: int = _enemy.get(key)
		_defenses[key][0].text = ("Hull" if key == "hull_capacity" else "Shields") + "  %d / %d" % [value, value]
		_defenses[key][1].max_value = maxi(1, value)
		_defenses[key][1].value = value
	for pair in [["materials", "synthesizer"], ["energy", "reactor"], ["crew", "quarters"]]:
		_reserves[pair[0]].text = "%s +%d/t · %d" % [Presentation.icon(pair[0], Presentation.UI_FONT), _enemy.get(pair[1]), _enemy.get(pair[0])]
	_role.text = _enemy.role
	_profile.text = _enemy.summary if not _enemy.summary.is_empty() else "No additional verified profile."
	var tint: Color = Modifiers.storm_color(_modifier) if _modifier in Modifiers.STORMS else [Color("90abba"), Color("d9a45a"), Color.WHITE, Color("ffab67"), Color("bca3ed"), Color("74d8db")][mini(_modifier, 5)]
	_conditions.add_theme_color_override("font_color", tint.lightened(0.2))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := Presentation.style(tint, state == "pressed")
		style.set_content_margin_all(4)
		_conditions.add_theme_stylebox_override(state, style)
	_mechanical_summary.text = modifier_summary(_modifier)
	_mechanical_summary.add_theme_color_override("font_color", tint.lightened(0.3))
	_effects.text = "Entry: " + Text.highlight_outcome(Text.effect_indicators(_pending))
	_boss_notice.visible = _boss


func _apply_layout() -> void:
	if _enemy == null or not is_inside_tree():
		return
	compact = _pursuit or get_viewport_rect().size.y < COMPACT_HEIGHT
	add_theme_constant_override("separation", 2 if compact else 6)
	for entry in _fonts:
		entry[0].add_theme_font_size_override("font_size", entry[1] if compact else entry[2])
	for style in _section_styles:
		style.set_content_margin_all(4 if compact else 8)
	for column in _section_columns:
		column.add_theme_constant_override("separation", 2 if compact else 4)
	for defense in _defenses.values():
		defense[1].custom_minimum_size.y = 10 if compact else 12
	_systems_caption.visible = not compact
	_profile_caption.visible = not (_pursuit and compact)
	_profile_caption.text = "TACTICAL · " + _enemy.role if compact else "TACTICAL PROFILE"
	_role.visible = not compact
	_conditions.text = Presentation.icon(Presentation.modifier_key(_modifier), Presentation.UI_FONT) + "  " + Modifiers.NAMES[_modifier]
	if compact:
		_conditions.text += "\n" + modifier_summary(_modifier)
	_conditions.add_theme_font_size_override("font_size", 17 if compact else 22)
	_mechanical_summary.visible = not compact


func _show_modifier_rules() -> void:
	_overlay.show_text("[b]%s[/b]\n\n%s" % [Modifiers.NAMES[_modifier], Modifiers.description(_modifier)])
