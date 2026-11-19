extends Control
## A clipped, non-modal drawer attached to a resource column.

signal closing

const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const WIDTH := 330.0
const CYAN := Color("79ddf5")

var handle: Button
var drawer: Control
var surface: Panel
var content: VBoxContainer
var scroll: ScrollContainer
var open := false
var _left: bool
var _motion: Tween


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
		var tint := Color(CYAN, 0.25 if state == "normal" else 0.75)
		var edge := _frame(Color.TRANSPARENT, tint)
		edge.set_border_width_all(0)
		edge.set_border_width(SIDE_RIGHT if left else SIDE_LEFT, 1)
		edge.content_margin_left = 3
		edge.content_margin_right = 3
		handle.add_theme_stylebox_override(state, edge)
	handle.alignment = HORIZONTAL_ALIGNMENT_RIGHT if left else HORIZONTAL_ALIGNMENT_LEFT
	handle.add_theme_color_override("font_color", CYAN)
	add_child(handle)

	drawer = Control.new()
	drawer.clip_contents = true
	drawer.mouse_filter = MOUSE_FILTER_STOP
	drawer.hide()
	add_child(drawer)
	surface = Panel.new()
	var frame := _frame(Color(0.021, 0.061, 0.105, 0.96), Color("3c92b5"))
	frame.set_border_width(SIDE_LEFT if left else SIDE_RIGHT, 3)
	frame.shadow_color = Color(0.11, 0.65, 0.91, 0.23)
	frame.shadow_size = 6
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


func fit(first: Rect2, last: Rect2, hand_top: float, view_width: float) -> void:
	var area := first.merge(last)
	# The production badge overhangs the left resource tile.
	area.size.x += 28 if _left else 14
	if not _left:
		area.position.x -= 14
	handle.position = area.position
	handle.size = area.size
	var width := minf(WIDTH, view_width * 0.43)
	drawer.position = Vector2(area.end.x + 3 if _left else area.position.x - width - 3, area.position.y)
	drawer.size = Vector2(width, maxf(100, hand_top - area.position.y - 12))
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
	if immediate:
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
	_motion = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
