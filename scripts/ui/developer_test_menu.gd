extends CanvasLayer

signal launch_requested(configuration: Dictionary)

const Launch = preload("res://scripts/expedition/developer_launch.gd")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")

static var last_configuration := {"mode": "warzone", "stage": 1, "rank": -1}
var ship_name: String
var mode: OptionButton
var stage: OptionButton
var difficulty: OptionButton
var launch_button: Button
var back_button: Button
var _previous_focus: Control
var _was_paused := false
var _was_back_quit := true
var _open := false


func _ready() -> void:
	layer = 221
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.8)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 430
	panel.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "Developer Testing"
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	var summary := Label.new()
	summary.text = "Unsaved session · Selected ship: %s" % ship_name
	column.add_child(summary)
	mode = _selector(column, "Game Mode", Launch.MODE_LABELS, Launch.MODES.find(last_configuration.mode))
	var stages: Array = []
	for number in range(1, Launch.MAX_STAGE + 1):
		stages.append("System %d" % number)
	stage = _selector(column, "Expedition Stage", stages, int(last_configuration.stage) - 1)
	difficulty = _selector(column, "Enemy Difficulty", ["Automatic", "Tier 1", "Tier 2", "Tier 3"],
		int(last_configuration.rank) + 1)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	back_button = _action(actions, "Back", close)
	launch_button = _action(actions, "Launch Test", _launch_selected, true)
	# Keep keyboard focus inside the modal, including when wrapping past the buttons.
	mode.focus_previous = mode.get_path_to(launch_button)
	launch_button.focus_next = launch_button.get_path_to(mode)

	_previous_focus = get_viewport().gui_get_focus_owner()
	_was_paused = get_tree().paused
	_was_back_quit = get_tree().quit_on_go_back
	get_tree().paused = true
	get_tree().quit_on_go_back = false
	_open = true
	mode.grab_focus()


func _selector(column: VBoxContainer, caption: String, choices: Array, selected: int) -> OptionButton:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var label := Label.new()
	label.text = caption
	label.custom_minimum_size.x = 150
	row.add_child(label)
	var selector := OptionButton.new()
	selector.accessibility_name = caption
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.custom_minimum_size.y = 48
	for choice in choices:
		selector.add_item(choice)
	selector.get_popup().add_theme_constant_override("v_separation", 12)
	selector.select(selected)
	Presentation.action(selector)
	row.add_child(selector)
	return selector


func _action(row: HBoxContainer, caption: String, action: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size.y = 48
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Presentation.action(button, primary)
	row.add_child(button)
	button.pressed.connect(action)
	return button


func _launch_selected() -> void:
	if not _open:
		return
	last_configuration = Launch.configuration(Launch.MODES[mode.selected], stage.selected + 1, difficulty.selected - 1)
	close()
	launch_requested.emit(last_configuration.duplicate())


func close() -> void:
	if not _open:
		return
	_restore_input()
	hide()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	queue_free()


func _restore_input() -> void:
	if _open:
		_open = false
		get_tree().paused = _was_paused
		get_tree().quit_on_go_back = _was_back_quit


func _unhandled_input(event: InputEvent) -> void:
	if _open and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _open:
		for selector in [mode, stage, difficulty]:
			if selector.get_popup().visible:
				selector.get_popup().hide()
				return
		close()


func _exit_tree() -> void:
	_restore_input()
