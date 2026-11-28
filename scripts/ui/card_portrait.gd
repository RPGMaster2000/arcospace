extends Button

# RESPONSIBILITY: Embed the original card scene in galleries without combat actions.
# Shared visual adapter: renders the real battle card, with no play/discard behavior.
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Sound = preload("res://scripts/audio/sfx.gd")
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const CARD = preload("res://scenes/card.tscn")
var card_data: Resource
var comparison_base: Resource
var card_scale: float = 1.0
var rendering: Button
var badge: Label
var hold_input: Node
var inspection_enabled: bool = true
var selected := false
var price := -1
var purchase_balance := 0
var price_label: Label


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
	if price >= 0:
		price_label = Label.new()
		price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 15)
		price_label.add_theme_color_override("font_color", Holo.DEFAULT.reward if price <= purchase_balance else Holo.DEFAULT.warning)
		price_label.text = "%d Salvage%s" % [price, " · Short" if price > purchase_balance else ""]
		add_child(price_label)
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
	focus_entered.connect(_emphasis)
	focus_exited.connect(_emphasis)
	mouse_entered.connect(_emphasis)
	mouse_exited.connect(_emphasis)
	button_down.connect(func():
		Sound.play(&"card_select", self)
		_emphasis())
	button_up.connect(_emphasis)


func set_card_scale(value: float) -> void:
	if is_equal_approx(value, card_scale) and custom_minimum_size.x > 0: return
	card_scale = value
	custom_minimum_size = Vector2(198, 294) * value
	if price_label != null:
		price_label.position = Vector2(0.0, custom_minimum_size.y + 4)
		price_label.size = Vector2(custom_minimum_size.x, 22)
		custom_minimum_size.y += 26
	if rendering:
		rendering.size = Vector2(198, 294)
		rendering.scale = Vector2.ONE * value


# Selection decoration surrounds the original renderer without altering its artwork.
func set_selected(active: bool) -> void:
	selected = active
	var border: Panel = get_node_or_null("SelectionBorder")
	if border == null:
		border = Panel.new()
		border.name = "SelectionBorder"
		border.add_theme_stylebox_override("panel", Holo.frame("focus", Holo.family(card_data.family)))
		border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		border.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(border)
	border.visible = active
	if rendering: _emphasis()


func _emphasis() -> void:
	var hover := is_hovered() or has_focus()
	rendering.interaction_hovered = hover
	rendering.interaction_selected = selected or button_pressed
	rendering.apply_card_theme()
	var seconds := Motion.duration(0.15)
	var destination := Vector2(0, -5 if selected else (-3 if hover else 0))
	if seconds > 0.0:
		Motion.start(rendering, &"gallery_lift").tween_property(rendering, "position", destination, seconds)
	else:
		Motion.stop(rendering, &"gallery_lift")
		rendering.position = Vector2.ZERO
