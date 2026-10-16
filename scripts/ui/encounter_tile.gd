extends Button
# Label children wrap without imposing a horizontal minimum on GridContainer.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var icon_label: Label
var heading: Label
var details: Label
var content: MarginContainer
var accent: Color = Presentation.COLORS.special
var selected: bool = false
var minimum_height: float = 84.0

func configure(title: String, body: String, color: Color, centered: bool = false) -> void:
	accent = color
	mouse_filter = Control.MOUSE_FILTER_PASS
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(0, 84)
	content = MarginContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: content.add_theme_constant_override("margin_" + edge, 16)
	for edge in ["top", "bottom"]: content.add_theme_constant_override("margin_" + edge, 6)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(column)
	if centered and title.contains("\n"):
		icon_label = _label(title.get_slice("\n", 0), 34)
		icon_label.add_theme_font_override("font", Presentation.UI_FONT)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(icon_label)
		title = title.substr(title.find("\n") + 1)
	heading = _label(title, 24)
	heading.add_theme_font_override("font", Presentation.UI_FONT)
	details = _label(body, 21)
	details.add_theme_font_override("font", Presentation.UI_FONT)
	if centered:
		heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)
	column.add_child(details)
	content.minimum_size_changed.connect(update_minimum_size)
	refresh_style()

func _process(_delta: float) -> void:
	if is_instance_valid(content):
		var icon_height: float = icon_label.get_combined_minimum_size().y + 4 if is_instance_valid(icon_label) else 0
		custom_minimum_size.y = maxf(minimum_height, icon_height + heading.get_combined_minimum_size().y + details.get_combined_minimum_size().y + 16)

func _label(value: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func refresh_style() -> void:
	for key in ["normal", "hover", "pressed", "disabled"]:
		add_theme_stylebox_override(key, Presentation.style(accent, selected or key == "pressed", disabled))
	var focus = Presentation.style(Color("a8d9fc"), true)
	focus.bg_color = Color.TRANSPARENT
	add_theme_stylebox_override("focus", focus)
	if is_instance_valid(icon_label): icon_label.modulate = Color("82909f") if disabled else Color.WHITE
	if is_instance_valid(heading):
		heading.modulate = Color("82909f") if disabled else Color("f3f6fa")
		details.modulate = Color("82909f") if disabled else Color("c2d7e7")
