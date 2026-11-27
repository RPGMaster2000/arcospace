extends Control

const Holo = preload("res://scripts/ui/holographic/skin.gd")
const HoloMotion = preload("res://scripts/ui/holographic/motion.gd")
## A clipped, non-modal drawer attached to a resource column.

signal closing

const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const WIDTH := 330.0
const HANDLE_WIDTH := 32.0
const CYAN := Color("79ddf5")

var handle: Button
var drawer: Control
var surface: Panel
var content: VBoxContainer
var scroll: ScrollContainer
var open := false
var _left: bool
var _motion: Tween
var _resource_target: Button


func _init(left: bool) -> void:
	_left = left
	name = "PlayerTacticalPanel" if left else "EnemyTacticalPanel"
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 20

	handle = Button.new()
	handle.name = "ResourceHandle"
	handle.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	handle.tooltip_text = "Player tactics · Tap resources" if left else "Enemy tactics · Tap resources"
	handle.accessibility_name = "Player tactical panel" if left else "Enemy tactical panel"
	handle.toggle_mode = true
	handle.add_theme_font_override("font", Presentation.UI_FONT)
	handle.add_theme_font_size_override("font_size", 21)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var tab := Holo.frame("compact", CYAN, state)
		tab.bg_color = Holo.DEFAULT.surface_depth.lerp(CYAN, 0.06 if state == "normal" else 0.14)
		tab.cut = 5.0
		tab.set_content_margin_all(3)
		tab.draw_center = state != "focus"
		handle.add_theme_stylebox_override(state, tab)
	handle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	handle.add_theme_color_override("font_color", CYAN)
	add_child(handle)

	# Keep the whole resource rail as a secondary tap target for the drawer.
	_resource_target = Button.new()
	var transparent := StyleBoxEmpty.new()
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		_resource_target.add_theme_stylebox_override(style, transparent)
	_resource_target.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	_resource_target.focus_mode = Control.FOCUS_NONE
	_resource_target.tooltip_text = handle.tooltip_text
	add_child(_resource_target)
	_resource_target.pressed.connect(func():
		if not handle.disabled: handle.pressed.emit())

	drawer = Control.new()
	drawer.clip_contents = true
	drawer.mouse_filter = MOUSE_FILTER_STOP
	drawer.hide()
	add_child(drawer)
	surface = Panel.new()
	var frame := Holo.frame("panel", Holo.DEFAULT.friendly if left else Holo.DEFAULT.hostile)
	frame.shadow_color = Color(frame.border_color, 0.20)
	frame.shadow_size = 5
	surface.add_theme_stylebox_override("panel", frame)
	drawer.add_child(surface)

	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.09, 0.43, 0.65, 0.15), Color(0.09, 0.43, 0.65, 0)])
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_to = Vector2(0.6, 0.8)
	var tint := TextureRect.new()
	tint.texture = wash
	tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tint.mouse_filter = MOUSE_FILTER_IGNORE
	surface.add_child(tint)
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.offset_left = 4
	tint.offset_top = 4
	tint.offset_right = -4
	tint.offset_bottom = -4

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	surface.add_child(layout)
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 14
	layout.offset_right = -12
	layout.offset_top = 10
	layout.offset_bottom = -10
	var heading := _label("PLAYER TACTICS" if left else "ENEMY TACTICS", 15, CYAN)
	layout.add_child(heading)
	var rule := ColorRect.new()
	rule.color = Color("286681")
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	layout.add_child(rule)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.scroll_deadzone = 8
	layout.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	scroll.add_child(content)
	_update_handle()


func fit(first: Rect2, last: Rect2, hand_top: float, view_width: float, attachment: Rect2, activation := Rect2()) -> void:
	var area := first.merge(last)
	var row := is_equal_approx(first.position.y, last.position.y)
	var width := minf(WIDTH, view_width * 0.43)
	var gap: float = Holo.DEFAULT.related_gap
	if not _left: attachment = area
	_resource_target.position = area.position
	_resource_target.size = area.size
	handle.size = Vector2(HANDLE_WIDTH, minf(Holo.DEFAULT.touch_height, attachment.size.y))
	var x := attachment.end.x + gap if _left else attachment.position.x - HANDLE_WIDTH - gap
	handle.position = Vector2(x, attachment.get_center().y - handle.size.y * 0.5)
	# Reserve the top EMP action footprint without moving the normal stacked
	# rail's handle. Short horizontal rails need more horizontal separation.
	if _left and activation.has_area() and handle.get_rect().intersects(activation.grow(gap)):
		handle.position.x = activation.end.x + gap
	var drawer_left := handle.get_rect().end.x + gap
	if _left and activation.has_area() and not row:
		drawer_left = maxf(drawer_left, activation.end.x + gap)
	width = minf(width, view_width - drawer_left - gap if _left else x - gap)
	drawer.position = Vector2(drawer_left if _left else x - width - gap,
		area.end.y + gap if row else area.position.y)
	drawer.size = Vector2(width, maxf(48, hand_top - drawer.position.y - 12))
	surface.size = drawer.size
	if _motion and _motion.is_running():
		_motion.kill()
		drawer.visible = open
		surface.position.x = 0
		surface.modulate.a = 1


func set_open(value: bool, immediate: bool = false) -> void:
	if open == value and (not immediate or drawer.visible == value):
		return
	open = value
	_update_handle()
	if _motion:
		_motion.kill()
	if not value:
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and drawer.is_ancestor_of(focused):
			focused.release_focus()
		closing.emit()
	if immediate or HoloMotion.duration(1.0) == 0.0:
		drawer.visible = value
		surface.position.x = 0
		surface.modulate.a = 1
		return
	var retracted := -drawer.size.x if _left else drawer.size.x
	if value and not drawer.visible:
		scroll.scroll_vertical = 0
		surface.position.x = retracted
		surface.modulate.a = 0.0
	drawer.show()
	_motion = create_tween().set_parallel().set_trans(Holo.DEFAULT.transition).set_ease(Holo.DEFAULT.easing)
	_motion.tween_property(surface, "position:x", 0.0 if value else retracted, 0.21)
	_motion.tween_property(surface, "modulate:a", 1.0 if value else 0.0, 0.17)
	if not value:
		_motion.chain().tween_callback(drawer.hide)


func add_section(section: String) -> Label:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 2)
	content.add_child(group)
	group.add_child(_label(section, 14, CYAN))
	var body := _label("", 16, Color("d9eaf3"))
	group.add_child(body)
	return body


func _update_handle() -> void:
	handle.set_pressed_no_signal(open)
	handle.text = "›" if _left != open else "‹"


static func _label(value: String, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Presentation.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	return label


static func _frame(background: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	return box
