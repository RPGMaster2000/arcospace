extends RefCounted
## Fits two ship identities and a dedicated, event-driven round readout.
const SkinTheme = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const GradientShader = preload("res://shaders/battle_header_gradient.gdshader")

var player: Label
var enemy: Label
var turn: Label
var round_label: Label
var player_info: Button
var _backdrops: Dictionary = {}
var _owner := ""


func _init(board: Control, open_player: Callable) -> void:
	player = board.get_node("PlayerIdentity")
	enemy = board.get_node("ModeLabel")
	turn = board.get_node("TurnLabel")
	round_label = turn.get_node("Round")
	var palette := SkinTheme.DEFAULT
	for label in [player, enemy, turn]:
		var tint := palette.friendly if label == player else (palette.hostile if label == enemy else palette.edge)
		_backdrops[label] = _backdrop(label, -1.0 if label == player else (1.0 if label == enemy else 0.0))
		_style_ink(label)
		label.add_theme_color_override("font_color", tint.lightened(0.22))
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if label == turn:
			_style_ink(round_label)
			round_label.add_theme_color_override("font_color", palette.muted)
			continue
		var subtitle: Label = label.get_node("Subtitle")
		_style_ink(subtitle)
		subtitle.clip_text = true
		subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		subtitle.add_theme_color_override("font_color", palette.text)
		subtitle.add_theme_font_size_override("font_size", 14)
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if label == player else HORIZONTAL_ALIGNMENT_RIGHT
	player_info = Button.new()
	player_info.name = "PlayerIdentityButton"
	player_info.accessibility_name = "Open player ship and battle systems"
	player_info.tooltip_text = "Player ship and battle systems"
	player_info.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent := StyleBoxEmpty.new()
	for state in ["normal", "disabled", "hover", "pressed", "hover_pressed"]:
		player_info.add_theme_stylebox_override(state, transparent)
	player_info.add_theme_stylebox_override("focus", SkinTheme.frame("focus", palette.friendly))
	player.add_child(player_info)
	player_info.pressed.connect(open_player)


func update(data: Dictionary) -> void:
	player.text = data.player_name
	player.get_node("Subtitle").text = data.player_subtitle
	enemy.text = data.enemy_name
	enemy.get_node("Subtitle").text = data.enemy_subtitle
	enemy.tooltip_text = "%s\n%s" % [enemy.text, data.enemy_subtitle]
	player_info.tooltip_text = "%s\n%s\nOpen player ship and battle systems" % [player.text, data.player_subtitle]
	round_label.text = "ROUND %d" % data.turn_number
	var outcome: String = data.winner
	var owner: String = data.current_actor
	var state := owner
	if data.get("emp_pending", false):
		state = "emp"
		turn.text = "EMP PULSE"
	elif not outcome.is_empty():
		state = outcome + "_result"
		turn.text = {"player":"YOU WIN", "enemy":"ENEMY WINS", "draw":"DRAW"}.get(outcome, "")
	else:
		turn.text = "YOUR TURN" if owner == "player" else "ENEMY TURN"
	if state == _owner: return
	var palette := SkinTheme.DEFAULT
	var tint: Color = {"player":palette.friendly,"enemy":palette.hostile,"emp":palette.shield,
		"player_result":palette.reward,"enemy_result":palette.hostile,"draw_result":palette.muted}.get(state, palette.edge)
	turn.add_theme_color_override("font_color", tint.lightened(0.24))
	if not _owner.is_empty(): Motion.reveal(turn, palette.selection_seconds)
	_owner = state


func fit(width: float, left: float, right: float, top: float) -> void:
	var skin := SkinTheme.DEFAULT
	var turn_width := clampf(width * 0.17, 115, 166)
	var center := width * 0.5
	var side_width := maxf(104, minf(325, minf(center - left, right - center) - turn_width * 0.5 - skin.section_gap))
	var pad: float = skin.compact_padding
	var height := 55.0
	for label in [player, enemy]:
		label.position = Vector2(left if label == player else right - side_width, top)
		label.size = Vector2(side_width, 29)
		label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		label.add_theme_font_size_override("font_size", 18 if side_width < 200 else 21)
		var backdrop: ColorRect = _backdrops[label]
		backdrop.offset_left = -2 * pad
		backdrop.offset_right = 2 * pad
		backdrop.offset_top = -top
		backdrop.offset_bottom = height - 29 + 2 * pad
		var subtitle: Label = label.get_node("Subtitle")
		subtitle.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		subtitle.position = Vector2(0, 33)
		subtitle.size = Vector2(side_width, 16)
	player_info.position = Vector2(-pad, 0)
	player_info.size = Vector2(side_width + 2 * pad, height)
	turn.position = Vector2(center - turn_width * 0.5, top + 24)
	turn.size = Vector2(turn_width, 24)
	turn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn.add_theme_font_size_override("font_size", 17)
	var turn_backdrop: ColorRect = _backdrops[turn]
	turn_backdrop.offset_left = -turn_width * 0.46
	turn_backdrop.offset_right = turn_width * 0.46
	turn_backdrop.offset_top = -24 - top
	turn_backdrop.offset_bottom = 3 * pad
	round_label.position = Vector2(0, -17)
	round_label.size = Vector2(turn_width, 15)


func _backdrop(host: Label, direction: float) -> ColorRect:
	var skin := SkinTheme.DEFAULT
	var gradient := ShaderMaterial.new()
	gradient.shader = GradientShader
	gradient.set_shader_parameter("shade", Color(skin.surface_depth, skin.header_opacity))
	gradient.set_shader_parameter("direction", direction)
	gradient.set_shader_parameter("horizontal_fade", skin.header_horizontal_fade)
	gradient.set_shader_parameter("vertical_fade", skin.header_vertical_fade)
	var panel := ColorRect.new()
	panel.material = gradient
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	host.add_child(panel, false, Node.INTERNAL_MODE_FRONT)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return panel


func _style_ink(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", SkinTheme.DEFAULT.surface_depth)
	label.add_theme_constant_override("outline_size", 2)
