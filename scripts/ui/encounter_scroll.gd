extends ScrollContainer

# RESPONSIBILITY: Preserve touch scrolling and suppress card/button activation after dragging.
# Native Godot touch scrolling; cancel button activation after a drag, including its release frame.
@export var drag_threshold: float = 12.0
## Nested card Buttons need explicit ScreenDrag handling; ordinary PoI scrolling stays native.
@export var explicit_touch_drag: bool = false
## Explicit drag can opt into momentum without depending on mouse emulation.
@export var kinetic_touch_drag: bool = false
@export var kinetic_deceleration: float = 2400.0
var kinetic_velocity: float = 0.0
var kinetic_position: float = 0.0
var last_motion_msec: int = 0
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
	set_process(false)
	scroll_started.connect(_scroll_started)
	scroll_ended.connect(_scroll_ended)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1 and get_global_rect().has_point(event.position):
			set_process(false)
			kinetic_velocity = 0.0
			last_motion_msec = Time.get_ticks_msec()
			touch_index = event.index
			touch_origin = event.position
			touch_scroll_origin = scroll_vertical
			dragged = false
		elif not event.pressed and event.index == touch_index:
			if dragged:
				blocked_until = Time.get_ticks_msec() + 180
			if explicit_touch_drag and kinetic_touch_drag and dragged and Time.get_ticks_msec() - last_motion_msec < 120:
				kinetic_position = scroll_vertical
				set_process(true)
			touch_index = -1
	elif event is InputEventScreenDrag and event.index == touch_index:
		if event.position.distance_to(touch_origin) >= drag_threshold:
			dragged = true
			blocked_until = Time.get_ticks_msec() + 180
			if explicit_touch_drag:
				var now: int = Time.get_ticks_msec()
				var elapsed: float = maxf((now - last_motion_msec) / 1000.0, 0.001)
				kinetic_velocity = -event.velocity.y if not is_zero_approx(event.velocity.y) else -event.relative.y / elapsed
				last_motion_msec = now
				scroll_vertical = touch_scroll_origin + roundi(touch_origin.y - event.position.y)
				get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or absf(kinetic_velocity) < 1.0:
		set_process(false)
		return
	var bar: VScrollBar = get_v_scroll_bar()
	kinetic_position = clampf(kinetic_position + kinetic_velocity * delta, 0.0, maxf(0.0, bar.max_value - bar.page))
	scroll_vertical = roundi(kinetic_position)
	kinetic_velocity = move_toward(kinetic_velocity, 0.0, kinetic_deceleration * delta)
	blocked_until = Time.get_ticks_msec() + 180
	if kinetic_position <= 0.0 or kinetic_position >= bar.max_value - bar.page: set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		touch_index = -1
		kinetic_velocity = 0.0
		set_process(false)


func _scroll_started() -> void:
	dragged = true
	blocked_until = Time.get_ticks_msec() + 180


func _scroll_ended() -> void:
	blocked_until = Time.get_ticks_msec() + 180


func allows_activation() -> bool:
	return Time.get_ticks_msec() >= blocked_until and not (touch_index >= 0 and dragged)
