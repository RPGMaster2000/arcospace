extends CanvasLayer

# RESPONSIBILITY: Present approach details and confirmation; ExpeditionState validates and resolves.
# Presentation-only confirmation. The expedition owns validation and rewards.
signal cancelled
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var shade: ColorRect
var panel: PanelContainer
var column: VBoxContainer
var heading: Label
var cancel_button: Button
var initiate: Button
var tween: Tween
var previous_focus: Control


func _ready() -> void:
	layer = 115
	shade = ColorRect.new()
	shade.color = Color(0, 0, 0, .72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	shade.add_child(panel)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	heading = Label.new()
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.add_theme_font_size_override("font_size", 24)
	column.add_child(heading)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	initiate = Button.new()
	initiate.text = "Initiate"
	for button in [cancel_button, initiate]:
		button.custom_minimum_size = Vector2(0, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 23)
		Presentation.action(button, button == initiate)
		actions.add_child(button)
	cancel_button.pressed.connect(func(): cancelled.emit())
	shade.resized.connect(_fit)
	panel.minimum_size_changed.connect(func(): _fit.call_deferred())
	shade.hide()


func _fit() -> void:
	if not is_instance_valid(panel):
		return
	panel.size = Vector2(minf(920, shade.size.x - 48), 0)
	panel.position = Vector2((shade.size.x - panel.size.x) / 2, shade.size.y - panel.size.y - 24)


func present(value: String) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	heading.text = value
	shade.modulate.a = 0
	shade.show()
	_fit()
	if tween:
		tween.kill()
	tween = create_tween()
	tween.tween_property(shade, "modulate:a", 1.0, .18)
	var controls = _focus_controls()
	for index in range(controls.size()):
		var control: Control = controls[index]
		var previous: NodePath = control.get_path_to(controls[posmod(index - 1, controls.size())])
		var following: NodePath = control.get_path_to(controls[(index + 1) % controls.size()])
		control.focus_neighbor_left = previous
		control.focus_neighbor_top = previous
		control.focus_neighbor_right = following
		control.focus_neighbor_bottom = following
	cancel_button.grab_focus()


func dismiss() -> void:
	if tween:
		tween.kill()
	shade.hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()


func _input(event: InputEvent) -> void:
	if not shade.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		cancelled.emit()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		# Keep keyboard focus in the modal, including the optional repair slider.
		var controls = _focus_controls()
		var current = controls.find(get_viewport().gui_get_focus_owner())
		if not controls.is_empty():
			(
				controls[posmod(current + (-1 if event.shift_pressed else 1), controls.size())]
				. grab_focus()
			)
		get_viewport().set_input_as_handled()


func _focus_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for child in column.get_children():
		for control in child.get_children():
			if (
				control is Control
				and control.is_visible_in_tree()
				and control.focus_mode == Control.FOCUS_ALL
			):
				if not control is BaseButton or not control.disabled:
					controls.append(control)
	return controls
