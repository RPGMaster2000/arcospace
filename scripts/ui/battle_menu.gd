extends Button
# RESPONSIBILITY: Battle utility navigation. Settings retains audio, pause and exit ownership.
signal main_menu_requested
const Style = preload("res://scripts/ui/encounter_presentation.gd")
@export var menu_width: float = 300.0
## TUNE: Open toward the viewscreen so the resource column stays readable.
@export var popup_indent: float = 124.0
var menu: CanvasLayer
var popup: ColorRect
var panel: PanelContainer
var settings_option: Button
var info_option: Button
var close_button: Button
var information: CanvasLayer


func _ready() -> void:
	name = "BattleMenu"
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(48, 48)
	tooltip_text = "Battle Menu"
	Style.action(self)
	menu = preload("res://scripts/ui/settings_menu.gd").new()
	add_child(menu)
	menu.main_menu_requested.connect(func(): main_menu_requested.emit())
	information = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(information)
	var navigation := CanvasLayer.new()
	navigation.layer = 210
	add_child(navigation)
	popup = ColorRect.new()
	popup.color = Color(0, 0, 0, 0.25)
	popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	navigation.add_child(popup)
	popup.gui_input.connect(
		func(event):
			if (
				(
					event is InputEventMouseButton
					and event.button_index == MOUSE_BUTTON_LEFT
					and event.pressed
				)
				or (event is InputEventScreenTouch and event.pressed)
			):
				dismiss()
	)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Style.style(Style.COLORS.special))
	popup.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	settings_option = _entry(column, "Settings", menu.present)
	info_option = _entry(column, "Game Information", information.show_legend)
	close_button = _entry(column, "Close", func(): pass)
	pressed.connect(
		func():
			panel.position = global_position + Vector2(popup_indent, size.y + 8)
			panel.size.x = menu_width
			popup.show()
			settings_option.grab_focus()
	)
	popup.hide()


func dismiss() -> void:
	popup.hide()
	grab_focus()


func _input(event: InputEvent) -> void:
	if popup.visible and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()


func _entry(column: VBoxContainer, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(menu_width, 56)
	button.add_theme_font_size_override("font_size", 21)
	Style.action(button)
	column.add_child(button)
	button.pressed.connect(
		func():
			dismiss()
			action.call()
	)
	return button


func _draw() -> void:
	var center := size * 0.5
	for y in [-7, 0, 7]:
		draw_line(center + Vector2(-10, y), center + Vector2(10, y), Color("a9e7ff"), 3, true)
