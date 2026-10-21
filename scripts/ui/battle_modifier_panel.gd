extends Button
# RESPONSIBILITY: Present live modifier facts and the existing full rules. No timer or combat state.
## TUNE: Compact two-line strip above the hand, with the existing HUD font scale.
@export var panel_max_width: float = 1000.0
@export var panel_height: float = 48.0
@export var panel_font_size: int = 18
@export var panel_side_padding: float = 140.0
var details: CanvasLayer
var current_rules: String = ""


func _ready() -> void:
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	$Text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$Text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Text.add_theme_font_size_override("font_size", panel_font_size)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.025, 0.07, 0.10, 0.88)
	background.border_color = Color(0.35, 0.62, 0.75, 0.55)
	background.set_border_width_all(1)
	background.set_corner_radius_all(6)
	for state in ["normal", "hover", "pressed", "focus"]:
		self.add_theme_stylebox_override(state, background)
	self.pressed.connect(show_details)
	details = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(details)


func fit_panel(board_size: Vector2, safe_inset: float = 0, hand_top: float = 414) -> void:
	var width: float = minf(panel_max_width, board_size.x - 2 * (panel_side_padding + safe_inset))
	self.set_anchors_preset(Control.PRESET_TOP_LEFT)
	self.position = Vector2((board_size.x - width) * 0.5, hand_top - panel_height - 6)
	self.size = Vector2(width, panel_height)
	$Text.position = Vector2(10, 2)
	$Text.size = Vector2(width - 20, panel_height - 4)


func refresh(modifier: Node, round_number: int) -> void:
	self.visible = true
	$Text.text = compact_status(modifier, round_number)
	self.tooltip_text = "Battle modifier · Tap for full rules"
	current_rules = (
		"[b]%s[/b]\n\n%s" % [modifier.NAMES[modifier.kind], modifier.description(modifier.kind)]
	)
	$Progress.value = modifier.meter_value(round_number)


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
