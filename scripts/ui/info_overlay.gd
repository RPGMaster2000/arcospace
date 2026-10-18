extends CanvasLayer
# Shared modal for descriptions/legend; an optional footer hosts controller-owned actions.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var shade: ColorRect
var panel: PanelContainer
var body: RichTextLabel
var extra: VBoxContainer
var close: Button
var previous_focus: Control
var desired_height: float = 320

func _ready() -> void:
	layer = 120
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, .8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	shade.add_child(panel)
	var column = VBoxContainer.new()
	panel.add_child(column)
	close = Button.new()
	close.text = "Close"
	close.custom_minimum_size.y = 48
	Presentation.action(close)
	close.pressed.connect(dismiss)
	column.add_child(close)
	var scroll = preload("res://scripts/ui/encounter_scroll.gd").new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	body = RichTextLabel.new()
	body.bbcode_enabled = true
	body.fit_content = true
	body.scroll_active = false
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_override("normal_font", Presentation.UI_FONT)
	var bold_font = FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 0.7
	bold_font.fallbacks = [Presentation.EMOJI_FONT]
	body.add_theme_font_override("bold_font", bold_font)
	body.add_theme_font_size_override("normal_font_size", 22)
	body.add_theme_font_size_override("bold_font_size", 22)
	scroll.add_child(body)
	extra = VBoxContainer.new()
	column.add_child(extra)
	extra.hide()
	shade.resized.connect(_fit)
	_fit()
	shade.hide()

func _fit() -> void:
	var height: float = minf(desired_height, shade.size.y - 48)
	panel.position = Vector2(maxf(24, (shade.size.x - 760) / 2), (shade.size.y - height) / 2)
	panel.size = Vector2(minf(760, shade.size.x - 48), height)

func show_text(value: String) -> void:
	extra.hide()
	desired_height = 320
	previous_focus = get_viewport().gui_get_focus_owner()
	body.text = value
	shade.show()
	close.grab_focus()
	_fit()

func show_legend() -> void:
	var lines: Array[String] = ["[font_size=28][b]Icon legend[/b][/font_size]"]
	var keys: Array = Presentation.MEANINGS.keys()
	for key in Presentation.ICONS:
		if not keys.has(key): keys.append(key)
	for key in keys:
		lines.append(Presentation.icon(key, body.get_theme_default_font()) + "  " + Presentation.meaning(key))
	show_text("\n".join(lines))
	desired_height = 560
	_fit()

func dismiss() -> void:
	extra.hide()
	shade.hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if shade.visible and event is InputEventKey and event.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
	if shade.visible and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
