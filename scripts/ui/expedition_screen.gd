extends Control
# RESPONSIBILITY: Own exploration screen controls; emits user intent without accessing expedition state.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Header = preload("res://scenes/poi_header.tscn")
const TouchScroll = preload("res://scripts/ui/encounter_scroll.gd")

signal deck_requested
signal main_menu_requested
signal hull_requested
signal return_requested
signal cancel_requested
signal repair_changed(value: float)
signal confirm_requested
signal jump_requested

var hull_pulse_period: float = 1.45
var hull_pulse_scale: float = 1.03
var hull_pulse_intensity: float = 0.22
var ui: MarginContainer
var title: Label
var heading_row: HBoxContainer
var deck_button: Button
var legend: Button
var settings_button: Button
var resource_bar: HFlowContainer
var header: PanelContainer
var return_button: Button
var scroll: ScrollContainer
var view: VBoxContainer
var more_hint: Label
var footer: HBoxContainer
var confirmation: CanvasLayer
var station_preview: VBoxContainer
var approach_note: Label
var repair_selector: HSlider
var confirm_button: Button
var jump_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _build_ui() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = Color("0e1a28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	ui = MarginContainer.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		ui.add_theme_constant_override("margin_" + edge, 24)
	add_child(ui)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	ui.add_child(column)
	title = _label("", 30)
	heading_row = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	column.add_child(heading_row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(title)
	deck_button = Button.new()
	deck_button.text = "Deck"
	deck_button.custom_minimum_size = Vector2(90, 48)
	Presentation.action(deck_button)
	deck_button.pressed.connect(deck_requested.emit)
	heading_row.add_child(deck_button)
	legend = Button.new()
	legend.text = "Legend"
	legend.custom_minimum_size = Vector2(100, 48)
	Presentation.action(legend)
	heading_row.add_child(legend)
	settings_button = preload("res://scripts/ui/settings_button.gd").new()
	heading_row.add_child(settings_button)
	settings_button.main_menu_requested.connect(main_menu_requested.emit)
	resource_bar = preload("res://scripts/ui/resource_bar.gd").new()
	resource_bar.pulse_period = hull_pulse_period
	resource_bar.pulse_scale = hull_pulse_scale
	resource_bar.pulse_intensity = hull_pulse_intensity
	column.add_child(resource_bar)
	resource_bar.hull_requested.connect(hull_requested.emit)
	legend.pressed.connect(func(): resource_bar.overlay.show_legend())
	header = Header.instantiate()
	column.add_child(header)
	header.return_requested.connect(return_requested.emit)
	return_button = header.return_button
	scroll = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	view = VBoxContainer.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 10)
	scroll.add_child(view)
	more_hint = _label("More options below — swipe or scroll", 16)
	more_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(more_hint)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	confirmation = preload("res://scripts/ui/approach_confirmation.gd").new()
	add_child(confirmation)
	confirmation.cancelled.connect(cancel_requested.emit)
	confirmation.column.add_child(footer)
	confirmation.column.move_child(footer, 1)
	station_preview = preload("res://scripts/ui/repair_preview.gd").new()
	confirmation.column.add_child(station_preview)
	confirmation.column.move_child(station_preview, 1)
	station_preview.hide()
	var shared = _label("", 20)
	approach_note = shared
	shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(shared)
	repair_selector = HSlider.new()
	repair_selector.custom_minimum_size = Vector2(180, 60)
	repair_selector.step = 1
	repair_selector.value_changed.connect(repair_changed.emit)
	footer.add_child(repair_selector)
	confirm_button = confirmation.initiate
	confirm_button.pressed.connect(confirm_requested.emit)
	jump_button = Button.new()
	jump_button.custom_minimum_size.y = 48
	jump_button.add_theme_font_size_override("font_size", 21)
	jump_button.add_theme_font_override("font", Presentation.UI_FONT)
	Presentation.action(jump_button)
	jump_button.pressed.connect(jump_requested.emit)
	column.add_child(jump_button)



func _label(text: String, font_size: int = 20) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
