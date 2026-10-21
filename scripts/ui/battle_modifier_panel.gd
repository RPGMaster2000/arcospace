extends Button
# RESPONSIBILITY: Present live modifier facts and the existing full rules. No timer or combat state.
## TUNE: Compact two-line strip above the hand, with the existing HUD font scale.
@export var panel_max_width: float = 1000.0
@export var panel_height: float = 48.0
@export var panel_font_size: int = 14
@export var panel_side_padding: float = 140.0
@export_range(0.0, 1.0) var background_opacity: float = 0.5
@export var edge_fade_width: float = 24.0
@export var text_padding: float = 8.0
@export var bar_height: float = 28.0
@export var visual_offset_y: float = -10.0
var details: CanvasLayer
var current_rules: String = ""


func _ready() -> void:
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	$Text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Text.add_theme_font_size_override("font_size", panel_font_size)
	var background := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "focus"]:
		self.add_theme_stylebox_override(state, background)
	resized.connect(queue_redraw)
	self.pressed.connect(show_details)
	details = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(details)


func fit_panel(board_size: Vector2, safe_inset: float = 0, hand_top: float = 414) -> void:
	var width: float = minf(panel_max_width, board_size.x - 2 * (panel_side_padding + safe_inset))
	self.set_anchors_preset(Control.PRESET_TOP_LEFT)
	self.position = Vector2((board_size.x - width) * 0.5, hand_top - panel_height - 6)
	self.size = Vector2(width, panel_height)
	$Text.position = Vector2(10, 2 + visual_offset_y)
	$Text.size = Vector2(width - 20, panel_height - 4)


func refresh(modifier: Node, round_number: int) -> void:
	self.visible = true
	$Text.text = compact_status(modifier, round_number)
	self.tooltip_text = "Battle modifier · Tap for full rules"
	current_rules = (
		"[b]%s[/b]\n\n%s" % [modifier.NAMES[modifier.kind], modifier.description(modifier.kind)]
	)
	$Progress.value = modifier.meter_value(round_number)
	queue_redraw()


func _draw() -> void:
	if not has_node("Text"):
		return
	var font: Font = $Text.get_theme_font("font")
	var text_width: float = minf(
		font.get_string_size($Text.text, HORIZONTAL_ALIGNMENT_LEFT, -1, panel_font_size).x,
		$Text.size.x
	)
	var half_width: float = minf(text_width * 0.5 + text_padding, size.x * 0.5 - edge_fade_width)
	var left: float = size.x * 0.5 - half_width
	var right: float = size.x * 0.5 + half_width
	var top: float = (size.y - bar_height) * 0.5 + visual_offset_y
	var tint := Color(0.025, 0.07, 0.10, background_opacity)
	draw_rect(Rect2(left, top, right - left, bar_height), tint)
	_fade_edge(left - edge_fade_width, left, top, Color(tint, 0.0), tint)
	_fade_edge(right, right + edge_fade_width, top, tint, Color(tint, 0.0))


func _fade_edge(left: float, right: float, top: float, start: Color, finish: Color) -> void:
	draw_polygon(
		PackedVector2Array(
			[
				Vector2(left, top),
				Vector2(right, top),
				Vector2(right, top + bar_height),
				Vector2(left, top + bar_height)
			]
		),
		PackedColorArray([start, finish, finish, start])
	)


static func compact_status(modifier: Node, round_number: int) -> String:
	var name: String = modifier.NAMES[modifier.kind].to_upper()
	var remaining: int = maxi(0, modifier.ends_round - round_number)
	var wait_rounds: int = maxi(0, modifier.next_round - round_number)
	match modifier.kind:
		0:
			return "◇  DEEP SPACE · No environmental modifier"
		1:
			return "◆  %s · Asteroid impact in %d rounds" % [name, wait_rounds]
		2:
			return (
				(
					"ϟ  %s · Energy effects %s · %d rounds left"
					% [name, "doubled" if modifier.ion_factor == 2.0 else "halved", remaining]
				)
				if modifier.active
				else "ϟ  %s · Next storm in %d rounds" % [name, wait_rounds]
			)
		3:
			return (
				("☀  %s · Shields disabled · %d rounds left" % [name, remaining])
				if modifier.active
				else "☀  %s · Shields online · Flare in %d rounds" % [name, wait_rounds]
			)
		4:
			return "◇  %s · Targeting accuracy: %d%%" % [name, 100 - modifier.miss_rate]
		5:
			return (
				"◈  %s · Uncommon card chance %s"
				% [
					name,
					(
						"doubled"
						if modifier.TEMPORAL_DROP_MULTIPLIER == 2.0
						else "multiplied by %.0f" % modifier.TEMPORAL_DROP_MULTIPLIER
					)
				]
			)
	return ""


func show_details() -> void:
	details.show_text(current_rules)
