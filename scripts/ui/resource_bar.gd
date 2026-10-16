extends HFlowContainer
# Same presentation for persistent expedition values and live combat values.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
var overlay: CanvasLayer
var entries: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 2)
	overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(overlay)

func put(key: String, value: String, detail: String = "", icon_key: String = "") -> void:
	if not entries.has(key):
		var button = Button.new()
		button.custom_minimum_size.y = 48
		button.add_theme_font_override("font", Presentation.UI_FONT)
		button.add_theme_font_size_override("font_size", 20)
		Presentation.action(button)
		for style in ["normal", "hover", "pressed", "disabled"]:
			var box: StyleBoxFlat = button.get_theme_stylebox(style).duplicate()
			box.content_margin_left = 8
			box.content_margin_right = 8
			box.content_margin_top = 2
			box.content_margin_bottom = 2
			button.add_theme_stylebox_override(style, box)
		button.pressed.connect(func(): overlay.show_text(button.tooltip_text))
		entries[key] = button
		add_child(button)
	var entry: Button = entries[key]
	entry.text = Presentation.icon(key if icon_key.is_empty() else icon_key, get_theme_default_font()) + " " + value
	entry.tooltip_text = Presentation.meaning(key) + ("\n" + detail if not detail.is_empty() else "")

func exploration(state: Resource) -> void:
	put("hull", "%d/%d" % [state.hull, state.ship().hull_capacity], state.ship().ship_name)
	put("salvage", str(state.salvage))
	put("travel", "%d/%d" % [state.ftl_charge, state.required_ftl_charge])
	for key in state.PRODUCTION:
		put(key, "%d/t" % state.production(key), "Expedition production; combat changes reset after battle.")
	for key in state.RESOURCES + ["shields"]:
		put(key, "Next %d" % state.starting_value(state.ship(), key), "NEXT BATTLE START, before turn income. This is a preview, not a live expedition stockpile.")
	put("hazard", "Next effects" + (" •" if state.pending_description() != "None" else " —"), "Pending effects: " + state.pending_description() + "\nStarting combat resources (before turn income):\n" +
		"Materials %d · Energy %d · Crew %d · Shields %d\nResource penalties cap at half the ship's base starting value. Bonuses add together; Emergency Jump offline uses the longest duration." % [state.starting_value(state.ship(), "materials"), state.starting_value(state.ship(), "energy"), state.starting_value(state.ship(), "crew"), state.starting_value(state.ship(), "shields")])

func combat(board: Node) -> void:
	put("hull", "%d/%d" % [board.player_hull, board.player_hull_capacity])
	put("shields", "OFF" if board.modifier.shields_disabled() else str(board.player_shields))
	put("salvage", str(board.salvage))
	for pair in [["materials", "synthesizer"], ["energy", "reactor"], ["crew", "quarters"]]:
		put(pair[0], "%d (+%d)" % [board.get("player_" + pair[0]), board.get("player_" + pair[1])], "%s: %d per player turn. Parentheses show production, not stored resources." % [Presentation.meaning(pair[1]).get_slice(" —", 0), board.get("player_" + pair[1])])
	put("jump", "%d/%d%s" % [board.ftl.charge, board.ftl.charge_target, " OFF" if board.ftl.disabled_turns > 0 else ""], "Offline turns: %d" % board.ftl.disabled_turns)
	var condition: String = Modifiers.NAMES[board.modifier.kind]
	if board.modifier.kind in [1, 2, 3]:
		condition += " · %s %dt" % ["active" if board.modifier.active else "in", maxi(0, (board.modifier.ends_round if board.modifier.active else board.modifier.next_round) - board.turn_number)]
	elif board.modifier.kind == 4:
		condition += " · %d%% hit" % (100 - board.modifier.miss_rate)
	put("hazard", condition, Modifiers.description(board.modifier.kind) + "\n" + board.modifier.status_text(board.turn_number), Presentation.modifier_key(board.modifier.kind))
