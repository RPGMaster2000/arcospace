extends HFlowContainer
# Exploration only: ship starting reserves plus effective pending adjustments.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const POSITIVE = Color("13743a")
const NEGATIVE = Color("b32232")
const FAMILY_COLORS = {"materials":Color("f0c9c6"), "synthesizer":Color("f0c9c6"),
	"energy":Color("cbdff4"), "reactor":Color("cbdff4"),
	"crew":Color("d4e9c5"), "quarters":Color("d4e9c5")}
var overlay: CanvasLayer
var entries: Dictionary = {}

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
			box.bg_color = FAMILY_COLORS.get(key, Color("f2f4f7"))
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
			label.add_theme_color_override("font_color", Color("202c3e"))
			row.add_child(label)
		button.pressed.connect(func(): overlay.show_text(button.tooltip_text))
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
	entry.tooltip_text = Presentation.meaning(key) + ("\n" + detail if not detail.is_empty() else "")

func starting_resource(state: Resource, key: String) -> void:
	var base: int = int(state.ship().get(key))
	var final: int = state.starting_value(state.ship(), key)
	var delta: int = final - base
	put(key, str(base), "Ship starting reserve: %d. Effective pending adjustment: %+d. Next battle starts at %d before turn income.\nThese are next-battle values, not a live exploration stockpile. Resource penalties cap at half the base reserve; bonuses add independently.\nPending bonuses %+d; penalties %d." % [base, delta, final, int(state.pending_bonuses.get(key, 0)), int(state.pending_penalties.get(key, 0))], "%+d" % delta if delta else "", delta < 0)

func exploration(state: Resource) -> void:
	put("hull", "%d/%d" % [state.hull, state.ship().hull_capacity], state.ship().ship_name)
	starting_resource(state, "shields")
	put("salvage", str(state.salvage))
	for pair in [["materials", "synthesizer"], ["energy", "reactor"], ["crew", "quarters"]]:
		starting_resource(state, pair[0])
		var key: String = pair[1]
		var base: int = int(state.ship().get(key))
		var delta: int = state.production(key) - base
		put(key, "%d/t" % base, "Production per player turn: %d. Base %d, expedition improvements %+d. Combat-only changes reset after battle." % [state.production(key), base, delta], "%+d" % delta if delta else "", delta < 0)
	var boost: int = clampi(state.modifier_value("emergency_jump_charge"), 0, state.ship().ftl_turns)
	var offline: int = maxi(0, state.modifier_value("emergency_jump_offline"))
	var detail: String = "Next battle: %d starting charge (ship target %d), disabled for %d turns. Normal turn charging resumes once enabled. Offline duration uses the longest pending penalty; charge is retained." % [boost, state.ship().ftl_turns, offline]
	if offline > 0:
		put("jump", "", detail, "Disabled -%d" % offline, true, "Boost +%d" % boost if boost else "")
	elif boost > 0:
		put("jump", "", detail, "Boost +%d" % boost)
	else:
		put("jump", "Nominal", detail)
