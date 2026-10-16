extends HFlowContainer
# Exploration only: ship starting reserves plus effective pending adjustments.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const POSITIVE = Color("8ce4ad")
const NEGATIVE = Color("ffacb5")
const FAMILY_COLORS = {"materials":Color("3b252c"), "synthesizer":Color("3b252c"),
	"energy":Color("20354d"), "reactor":Color("20354d"),
	"crew":Color("253c30"), "quarters":Color("253c30")}
var overlay: CanvasLayer
var entries: Dictionary = {}
var markup = RegEx.create_from_string("\\[.*?\\]")

func _ready() -> void:
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 2)
	overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(overlay)

func put(key: String, value: String, detail: String = "", adjustment: String = "", negative: bool = false, extra_bonus: String = "") -> void:
	if not entries.has(key):
		var button = Button.new()
		button.custom_minimum_size.y = 48
		button.add_theme_font_override("font", Presentation.UI_FONT)
		button.add_theme_font_size_override("font_size", 20)
		Presentation.action(button)
		for style in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = button.get_theme_stylebox(style).duplicate()
			box.bg_color = FAMILY_COLORS.get(key, Color("192b3c"))
			box.border_color = box.bg_color.lightened(.32)
			if style == "hover": box.bg_color = box.bg_color.lightened(.08)
			box.content_margin_left = 8
			box.content_margin_right = 8
			box.content_margin_top = 2
			box.content_margin_bottom = 2
			button.add_theme_stylebox_override(style, box)
		# Button text retains sizing/accessibility; child labels color each adjustment.
		for color in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
			button.add_theme_color_override(color, Color.TRANSPARENT)
		var row = HBoxContainer.new()
		row.name = "Values"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 0)
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		for part in ["Base", "Adjustment", "Bonus"]:
			var label = Label.new()
			label.name = part
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_override("font", Presentation.UI_FONT)
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color("edf3fa"))
			row.add_child(label)
		button.pressed.connect(func(): overlay.show_text(button.get_meta("description", button.tooltip_text)))
		entries[key] = button
		add_child(button)
	var entry: Button = entries[key]
	var base: String = Presentation.icon(key, get_theme_default_font()) + (" " + value if not value.is_empty() else "")
	var suffix: String = " " + adjustment if not adjustment.is_empty() else ""
	var bonus: String = " · " + extra_bonus if not extra_bonus.is_empty() else ""
	entry.text = base + suffix + bonus
	entry.get_node("Values/Base").text = base
	entry.get_node("Values/Adjustment").text = suffix
	entry.get_node("Values/Adjustment").add_theme_color_override("font_color", NEGATIVE if negative else POSITIVE)
	entry.get_node("Values/Bonus").text = bonus
	entry.get_node("Values/Bonus").add_theme_color_override("font_color", POSITIVE)
	entry.set_meta("description", detail)
	entry.tooltip_text = markup.sub(detail, "", true)

func heading(key: String, name: String) -> String:
	return "[font_size=28][b]%s %s[/b][/font_size]" % [Presentation.icon(key, get_theme_default_font()), name]

func colored_delta(delta: int) -> String:
	if delta == 0: return ""
	return "[color=#%s]%+d[/color]" % [(NEGATIVE if delta < 0 else POSITIVE).to_html(false), delta]

func starting_resource(state: Resource, key: String, production: String = "") -> void:
	var base: int = int(state.ship().get(key))
	var final: int = state.starting_value(state.ship(), key)
	var delta: int = final - base
	var name: String = state.LABELS[key]
	var value: String = str(base)
	var detail: String = heading(key, name) + "\n\n"
	if not production.is_empty():
		value = "+%d/t · %d %s" % [state.production(production), base, name]
		detail += "[b]%s[/b]  +%d / turn\n" % [state.LABELS[production], state.production(production)]
		detail += "[b]Next battle[/b]  %d %s = [b]%d[/b]\n[color=#b8c9d9]Before turn income[/color]" % [base, colored_delta(delta), final]
		if int(state.pending_penalties.get(key, 0)) < 0:
			detail += "\nPenalty capped at 50% of base."
	else:
		detail += "[b]Next battle[/b]  %d %s = [b]%d[/b]\nAbsorbs damage first. Resets each battle." % [base, colored_delta(delta), final]
	put(key, value, detail, "%+d" % delta if delta else "", delta < 0)

func exploration(state: Resource) -> void:
	put("hull", "%d/%d" % [state.hull, state.ship().hull_capacity], heading("hull", "Hull") + "\n\n[b]%d / %d[/b]\nCarries between battles.\nExcess → temporary plating." % [state.hull, state.ship().hull_capacity])
	starting_resource(state, "shields")
	put("salvage", str(state.salvage), heading("salvage", "Salvage") + "\n\n[b]%d[/b]\nRepairs · Cards · Supplies · Production" % state.salvage)
	for pair in [["materials", "synthesizer"], ["energy", "reactor"], ["crew", "quarters"]]:
		starting_resource(state, pair[0], pair[1])
	var boost: int = clampi(state.modifier_value("emergency_jump_charge"), 0, state.ship().ftl_turns)
	var offline: int = maxi(0, state.modifier_value("emergency_jump_offline"))
	var detail: String = heading("jump", "Emergency Jump") + "\n\n[b]Next battle[/b]\nCharge  [b]%d / %d[/b]\nOffline  [b]%d turns[/b]\nCombat escape; separate from system travel." % [boost, state.ship().ftl_turns, offline]
	if offline > 0:
		put("jump", "", detail, "Disabled -%d" % offline, true, "Boost +%d" % boost if boost else "")
	elif boost > 0:
		put("jump", "", detail, "Boost +%d" % boost)
	else:
		put("jump", "Nominal", detail)
