extends CanvasLayer
# Presentation only. Selecting emits a mode; never deals, replaces or edits cards.
signal mode_selected(mode: String)
const Style = preload("res://scripts/ui/encounter_presentation.gd")
const MODES = ["balanced", "offense", "defense", "systems"]
const ICONS = ["⚖️", "⚔️", "🛡️", "⚙️"]
const NAMES = ["Balanced", "Offense", "Defense", "Systems"]
const HINTS = ["Normal", "More attacks", "More protection", "More resources"]
var shade: ColorRect
var panel: PanelContainer
var choices: Array[Button] = []
var indicators: Array[Label] = []
var previous_focus: Control

func _ready() -> void:
	layer = 130
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	shade.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: dismiss()
		elif event is InputEventScreenTouch and event.pressed: dismiss())
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.add_child(center)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", Style.style(Style.COLORS.special))
	center.add_child(panel)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title = Label.new()
	title.text = "Power Allocation"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for index in range(MODES.size()):
		var button = Button.new()
		button.custom_minimum_size = Vector2(224, 150)
		button.toggle_mode = true
		button.tooltip_text = NAMES[index] + ": " + HINTS[index]
		Style.action(button)
		grid.add_child(button)
		choices.append(button)
		var contents = VBoxContainer.new()
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		contents.offset_top = 8
		contents.offset_bottom = -8
		contents.alignment = BoxContainer.ALIGNMENT_CENTER
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(contents)
		for pair in [[ICONS[index], 36], [NAMES[index], 22], [HINTS[index], 17], ["", 15]]:
			var label = Label.new()
			label.text = pair[0]
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.add_theme_font_override("font", Style.UI_FONT)
			label.add_theme_font_size_override("font_size", pair[1])
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			contents.add_child(label)
		indicators.append(contents.get_child(3))
		button.pressed.connect(_choose.bind(index))
	var close = Button.new()
	close.text = "Back"
	close.custom_minimum_size.y = 48
	Style.action(close)
	close.pressed.connect(dismiss)
	column.add_child(close)
	var focus_controls: Array[Button] = choices.duplicate()
	focus_controls.append(close)
	for index in range(focus_controls.size()):
		focus_controls[index].focus_next = focus_controls[index].get_path_to(focus_controls[(index + 1) % focus_controls.size()])
		focus_controls[index].focus_previous = focus_controls[index].get_path_to(focus_controls[(index + focus_controls.size() - 1) % focus_controls.size()])
	shade.hide()

func present(mode: String, multiplier: float) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	for index in range(choices.size()):
		var active: bool = mode == MODES[index]
		choices[index].button_pressed = active
		choices[index].add_theme_stylebox_override("normal", Style.style(Style.COLORS.special, active))
		indicators[index].text = "" if index == 0 else "%s× draw weight" % str(multiplier)
	shade.show()
	choices[maxi(0, MODES.find(mode))].grab_focus()

func _choose(index: int) -> void:
	dismiss()
	mode_selected.emit(MODES[index])

func dismiss() -> void:
	shade.hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	if shade.visible and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
