extends ScrollContainer

# RESPONSIBILITY: Preserve touch scrolling and suppress card/button activation after dragging.
# Native Godot touch scrolling; cancel button activation after a drag, including its release frame.
@export var drag_threshold: float = 12.0
## Nested card Buttons need explicit ScreenDrag handling; ordinary PoI scrolling stays native.
@export var explicit_touch_drag: bool = false
var touch_scroll_origin: int = 0
var touch_index: int = -1
var touch_origin: Vector2
var dragged: bool = false
var blocked_until: int = 0


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll_deadzone = int(drag_threshold)
	follow_focus = true
	scroll_started.connect(_scroll_started)
	scroll_ended.connect(_scroll_ended)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 and get_global_rect().has_point(event.position):
			touch_index = event.index
			touch_origin = event.position
			touch_scroll_origin = scroll_vertical
			dragged = false
		elif not event.pressed and event.index == touch_index:
			if dragged:
				blocked_until = Time.get_ticks_msec() + 180
			touch_index = -1
	elif event is InputEventScreenDrag and event.index == touch_index:
		if event.position.distance_to(touch_origin) >= drag_threshold:
			dragged = true
			blocked_until = Time.get_ticks_msec() + 180
			if explicit_touch_drag:
				scroll_vertical = touch_scroll_origin + roundi(touch_origin.y - event.position.y)
				get_viewport().set_input_as_handled()


func _scroll_started() -> void:
	dragged = true
	blocked_until = Time.get_ticks_msec() + 180


func _scroll_ended() -> void:
	blocked_until = Time.get_ticks_msec() + 180


func allows_activation() -> bool:
	return Time.get_ticks_msec() >= blocked_until and not (touch_index >= 0 and dragged)
