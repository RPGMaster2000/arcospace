extends Button
# Shared visual adapter: renders the real battle card, with no play/discard behavior.
const CARD = preload("res://scenes/card.tscn")
const Text = preload("res://scripts/ui/card_effect_text.gd")
var card_data: Resource
var comparison_base: Resource
var card_scale: float = 1.0
var rendering: Button
var badge: Label
var effects: RichTextLabel

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rendering = CARD.instantiate()
	rendering.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rendering.focus_mode = Control.FOCUS_NONE
	add_child(rendering)
	rendering.card_data = card_data
	rendering.get_node("DiscardButton").hide()
	for child in rendering.get_children():
		if child is Control: child.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge = Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(8, 259)
	badge.size = Vector2(182, 26)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 15)
	badge.text = ["BASE", "UPGRADE I +", "UPGRADE II ++ · MAX"][clampi(card_data.upgrade_level, 0, 2)]
	rendering.add_child(badge)
	if comparison_base != null:
		effects = RichTextLabel.new()
		effects.bbcode_enabled = true
		effects.scroll_active = false
		effects.fit_content = true
		effects.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effects.add_theme_font_size_override("normal_font_size", 16)
		effects.add_theme_color_override("default_color", Color("eee4cd"))
		effects.text = Text.comparison(card_data, comparison_base)
		rendering.get_node("DescriptionLabel").hide()
		rendering.add_child(effects)
		_fit_effects.call_deferred()
	set_card_scale(card_scale)
	tooltip_text = card_data.card_name + " · " + str(card_data.cost) + " " + card_data.family.capitalize() + "\n" + card_data.description
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

func _fit_effects() -> void:
	effects.position = Vector2(13, 170)
	effects.size = Vector2(173, 75)
	# Comparison text can have more lines than the compact combat description.
	var height: float = effects.get_content_height()
	effects.position.y = 248 - height
	effects.size.y = height
	rendering.get_node("ArtPlaceholder").offset_bottom = effects.position.y - 6
	rendering.get_node("ArtPlaceholder").visible = effects.position.y > rendering.get_node("ArtPlaceholder").offset_top + 10
	rendering.fit_placeholder_art()
