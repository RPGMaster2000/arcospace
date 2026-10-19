extends Button

# RESPONSIBILITY: Embed the original card scene in galleries without combat actions.
# Shared visual adapter: renders the real battle card, with no play/discard behavior.
const CARD = preload("res://scenes/card.tscn")
var card_data: Resource
var comparison_base: Resource
var card_scale: float = 1.0
var rendering: Button
var badge: Label
var hold_input: Node
var inspection_enabled: bool = true


func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rendering = CARD.instantiate()
	rendering.inspection_enabled = false
	rendering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rendering.focus_mode = Control.FOCUS_NONE
	add_child(rendering)
	rendering.card_data = card_data
	rendering.get_node("DiscardButton").hide()
	for child in rendering.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(8, 259)
	badge.size = Vector2(182, 26)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 15)
	badge.text = ["BASE", "UPGRADE I +", "UPGRADE II ++ · MAX"][clampi(
		card_data.upgrade_level, 0, 2
	)]
	rendering.add_child(badge)
	if inspection_enabled:
		hold_input = preload("res://scripts/ui/card_hold.gd").new()
		add_child(hold_input)
		hold_input.bind_card(self, rendering, rendering.presentation_settings)
	set_card_scale(card_scale)
	tooltip_text = (
		card_data.card_name
		+ " · "
		+ str(card_data.cost)
		+ " "
		+ card_data.family.capitalize()
		+ "\n"
		+ card_data.description
	)
	focus_entered.connect(func(): rendering.modulate = Color(1.12, 1.12, 1.12))
	focus_exited.connect(func(): rendering.modulate = Color.WHITE)
	mouse_entered.connect(func(): rendering.modulate = Color(1.12, 1.12, 1.12))
	mouse_exited.connect(func(): rendering.modulate = Color.WHITE)


func set_card_scale(value: float) -> void:
	card_scale = value
	custom_minimum_size = Vector2(198, 294) * value
	if rendering:
		rendering.size = Vector2(198, 294)
		rendering.scale = Vector2.ONE * value
