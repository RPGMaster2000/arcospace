extends CanvasLayer
## A shallow flyout with fixed hit areas; the visible icon plates unfold inside them.
signal mode_selected(mode: String)
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Glyph = preload("res://scripts/ui/holographic/system_glyph.gd")
const MODES = ["balanced", "offense", "defense", "systems"]
const NAMES = ["Balanced", "Offense", "Defense", "Systems"]
const HINTS = ["Normal draw weights", "Attacks draw at %s× weight",
	"Protection draws at %s× weight", "Resource cards draw at %s× weight"]
const TARGET := 48.0

var shade: Control
var panel: Control
var choices: Array[Button] = []
var detail: PanelContainer
var _title: Label
var _hint: Label
var _anchor: Button
var _main_icon: Control
var _plates: Array[Panel] = []
var _hold: Timer
var _pressed := -1
var _held := false
var _active := 0
var _multiplier := 1.0
var _step := TARGET


func _ready() -> void:
	layer = 130
	shade = Control.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.hide()
	panel = Control.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.hide()
	_hold = Timer.new()
	_hold.one_shot = true
	add_child(_hold)
	_hold.timeout.connect(_show_detail)
	var transparent := StyleBoxEmpty.new()
	for index in MODES.size():
		var button := Button.new()
		button.size = Vector2.ONE * TARGET
		button.accessibility_name = NAMES[index]
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for key in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
			button.add_theme_stylebox_override(key, transparent)
		button.add_theme_stylebox_override("focus", Holo.frame("focus", Holo.DEFAULT.friendly))
		panel.add_child(button)
		choices.append(button)
		var plate := Panel.new()
		plate.size = button.size
		plate.modulate.a = 0.0
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(plate)
		_plates.append(plate)
		_add_icon(plate).kind = MODES[index]
		button.button_down.connect(_start_hold.bind(index))
		button.button_up.connect(_release_hold)
		button.mouse_entered.connect(_paint.bind(index))
		button.mouse_exited.connect(_paint.bind(index))
		button.pressed.connect(_choose.bind(index))
	detail = PanelContainer.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var detail_style := Holo.frame("compact", Holo.DEFAULT.friendly)
	detail_style.content_margin_top = 5
	detail_style.content_margin_bottom = 5
	detail.add_theme_stylebox_override("panel", detail_style)
	panel.add_child(detail)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 1)
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(copy)
	_title = _detail_line(copy, 14, Holo.DEFAULT.friendly)
	_hint = _detail_line(copy, 12, Holo.DEFAULT.text)
	detail.hide()
	Motion.Preferences.events.ui_motion_changed.connect(_motion_changed)


func bind_anchor(button: Button) -> void:
	_anchor = button
	_main_icon = _add_icon(button)
	_main_icon.launcher = true
	_main_icon.offset_left = 5
	_main_icon.offset_right = -11


func set_mode(mode: String) -> void:
	_active = maxi(0, MODES.find(mode))
	_main_icon.kind = MODES[_active]
	_anchor.accessibility_name = "Power Allocation · " + NAMES[_active]
	_anchor.tooltip_text = _anchor.accessibility_name + "\nHold an allocation icon for details."
	for index in choices.size(): _paint(index)


func fit() -> void:
	_step = TARGET + Holo.DEFAULT.related_gap
	panel.position = _anchor.get_global_rect().position + Vector2(_step, 0)
	panel.size = Vector2(_step * choices.size() - Holo.DEFAULT.related_gap, TARGET)
	for index in choices.size():
		choices[index].position = Vector2(index * _step, 0)
	detail.position = Vector2(panel.size.x + Holo.DEFAULT.spacing, 0)
	detail.size = Vector2(218, TARGET)


func toggle(mode: String, multiplier: float) -> void:
	if shade.visible:
		dismiss()
		return
	set_mode(mode)
	_multiplier = multiplier
	shade.show()
	panel.show()
	_anchor.set_pressed_no_signal(true)
	_main_icon.expanded = true
	for index in choices.size(): _paint(index)
	_slide(true)


func dismiss() -> void:
	if not shade.visible: return
	_hold.stop()
	_pressed = -1
	_held = false
	detail.hide()
	shade.hide()
	_anchor.set_pressed_no_signal(false)
	_main_icon.expanded = false
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and panel.is_ancestor_of(focus):
		if _anchor.is_visible_in_tree() and not _anchor.disabled: _anchor.grab_focus()
	_slide(false)


func _slide(opening: bool) -> void:
	Motion.stop(self, &"allocation")
	var seconds := Motion.duration(Holo.DEFAULT.allocation_slide_seconds)
	if not opening: seconds *= 0.65
	var tween: Tween
	if seconds > 0.0:
		tween = Motion.start(self, &"allocation").set_parallel()
		if not opening: tween.finished.connect(panel.hide)
	for index in choices.size():
		var button := choices[index]
		button.disabled = not opening
		var plate := _plates[index]
		var folded := Vector2(-_step * (index + 1), 0)
		var target := Vector2.ZERO if opening else folded
		if tween == null:
			plate.position = target
			plate.modulate.a = 1.0 if opening else 0.0
			continue
		if opening and is_zero_approx(plate.modulate.a): plate.position = folded
		var delay := index * 0.015 if opening else 0.0
		tween.tween_property(plate, "position", target, seconds).set_delay(delay)
		tween.tween_property(plate, "modulate:a", 1.0 if opening else 0.0, seconds * 0.7).set_delay(delay)
	if not opening and tween == null: panel.hide()


func _motion_changed(profile: int) -> void:
	if profile == 0 and panel.visible: _slide(shade.visible)


func _add_icon(target: Control) -> Control:
	var icon := Glyph.new()
	icon.name = "ModeGlyph"
	icon.ink = Holo.DEFAULT.text
	target.add_child(icon)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12
	icon.offset_top = 12
	icon.offset_right = -12
	icon.offset_bottom = -12
	return icon


func _detail_line(parent: Control, pixels: int, tint: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", Holo.DEFAULT.font)
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", tint)
	parent.add_child(label)
	return label


func _paint(index: int) -> void:
	var button := choices[index]
	var selected := index == _active
	var accent := Holo.DEFAULT.friendly if selected else Holo.DEFAULT.edge
	var state := "selected" if selected else ("hover" if button.is_hovered() else "normal")
	var frame := Holo.frame("tab", accent, state)
	if selected: frame.bg_color = frame.bg_color.lerp(accent, 0.24)
	var plate := _plates[index]
	plate.add_theme_stylebox_override("panel", frame)
	plate.get_node("ModeGlyph").ink = accent if selected else Holo.DEFAULT.text
	button.accessibility_description = "Selected allocation" if selected else ""


func _start_hold(index: int) -> void:
	if not shade.visible: return
	_pressed = index
	_held = false
	_hold.start(Holo.DEFAULT.allocation_hold_seconds)


func _release_hold() -> void:
	_hold.stop()
	_pressed = -1


func _show_detail() -> void:
	if _pressed < 0 or not shade.visible: return
	_held = true
	_title.text = NAMES[_pressed]
	_hint.text = HINTS[_pressed] if _pressed == 0 else HINTS[_pressed] % str(_multiplier)
	detail.show()
	Motion.reveal(detail, Holo.DEFAULT.selection_seconds)


func _choose(index: int) -> void:
	if not shade.visible or _held: return
	dismiss()
	mode_selected.emit(MODES[index])


func _input(event: InputEvent) -> void:
	if shade == null or not shade.visible: return
	if event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
		return
	if _pressed >= 0 and (event is InputEventMouseMotion or event is InputEventScreenDrag):
		if not choices[_pressed].get_global_rect().has_point(event.position):
			_release_hold()
	var pointer_down: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed)
	if not pointer_down: return
	var point: Vector2 = event.position
	if _anchor.get_global_rect().has_point(point) or panel.get_global_rect().has_point(point): return
	if detail.visible and detail.get_global_rect().has_point(point): return
	dismiss()
	get_viewport().set_input_as_handled()
