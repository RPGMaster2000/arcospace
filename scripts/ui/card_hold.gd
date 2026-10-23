extends Node

# RESPONSIBILITY: Translate card holds/middle-click into inspection; cancel taps when gestures become holds.
# Reusable gesture adapter. GUI starts a hold; global motion/release cancels it before scrolling/actions.
var preview: Node
var source: Button
var rendering: Button
var footer: Button
var settings: Resource
var timer: Timer
var origin: Vector2
var pointer: int = -2  # -1 mouse, nonnegative touch, -2 idle
var activated: bool = false
var blocked_until: int = 0
var scroll_ancestors: Array = []


func bind_card(
	button: Button, visual: Button, configuration: Resource, discard: Button = null
) -> void:
	source = button
	rendering = visual
	settings = configuration
	footer = discard
	timer = Timer.new()
	timer.one_shot = true
	add_child(timer)
	timer.timeout.connect(_hold)
	source.gui_input.connect(_gui.bind(source))
	if footer != null:
		footer.gui_input.connect(_gui.bind(footer))
	var ancestor: Node = source.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			scroll_ancestors.append(weakref(ancestor))
			ancestor.scroll_started.connect(_cancel_drag)
		ancestor = ancestor.get_parent()
	# A source disappearing or its view closing must not retain an overlay/gesture.
	source.visibility_changed.connect(
		func():
			if not source.is_visible_in_tree():
				cancel()
	)


func overlay() -> Node:
	var root: Node = get_tree().root
	var existing: Node = root.get_node_or_null("CardInspection")
	if existing != null:
		return existing
	var created = load("res://scripts/ui/card_inspection.gd").new()
	created.name = "CardInspection"
	root.add_child(created)
	return created


func _gui(event: InputEvent, control: Control) -> void:
	if not source.is_visible_in_tree() or source.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return
	if Time.get_ticks_msec() < blocked_until:
		control.accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			origin = event.global_position
			pointer = -1
			_inspect()
			control.accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed and pointer == -2:
			_begin(-1, event.global_position)
	elif event is InputEventScreenTouch and event.pressed:
		_begin(event.index, control.get_global_transform_with_canvas() * event.position)


func _begin(index: int, point: Vector2) -> void:
	var current: Node = get_tree().root.get_node_or_null("CardInspection")
	if current != null and current.is_open():
		return
	pointer = index
	origin = point
	activated = false
	timer.start(settings.hold_duration)


func _input(event: InputEvent) -> void:
	if pointer == -2:
		return
	var release: bool = (
		(event is InputEventScreenTouch and event.index == pointer and not event.pressed)
		or (event is InputEventMouseButton and pointer == -1 and not event.pressed)
	)
	if release:
		timer.stop()
		pointer = -2
		if activated:
			blocked_until = Time.get_ticks_msec() + 180
			get_viewport().set_input_as_handled()
		activated = false
	elif event is InputEventScreenDrag and event.index == pointer:
		if event.position.distance_to(origin) >= settings.hold_movement_cancellation:
			_cancel_drag()
	elif event is InputEventMouseMotion and pointer == -1:
		if event.global_position.distance_to(origin) >= settings.hold_movement_cancellation:
			_cancel_drag()


func _process(_delta: float) -> void:
	if timer == null or timer.is_stopped():
		return
	for saved in scroll_ancestors:
		var scroll = saved.get_ref()
		if (
			is_instance_valid(scroll)
			and scroll.has_method("allows_activation")
			and not scroll.allows_activation()
		):
			_cancel_drag()
			return


func _hold() -> void:
	if is_instance_valid(preview) and is_instance_valid(source) and rendering.card_data != null:
		activated = true
		_reset_buttons()
		preview.present(self)
	else:
		_inspect()


func _unhandled_input(event: InputEvent) -> void:
	var requested: bool = (event is InputEventKey and event.pressed and event.keycode == KEY_I) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y)
	if requested and (source.has_focus() or (footer != null and footer.has_focus())):
		_hold()
		get_viewport().set_input_as_handled()


func _inspect() -> void:
	if (
		not is_instance_valid(source)
		or not is_instance_valid(rendering)
		or not source.is_visible_in_tree()
		or rendering.card_data == null
		or rendering.modulate.a <= 0.01
	):
		return
	activated = true
	_reset_buttons()
	if is_instance_valid(preview) and preview.source != source: preview.dismiss(true)
	overlay().present(source, rendering, settings)


func _reset_buttons() -> void:
	# Reset BaseButton's pending release activation, including an optional discard footer.
	for button in [source, footer]:
		if not is_instance_valid(button):
			continue
		var disabled_before: bool = button.disabled
		button.disabled = true
		button.disabled = disabled_before


func _cancel_drag() -> void:
	timer.stop()
	_reset_buttons()


func cancel() -> void:
	if pointer != -2 and is_instance_valid(source):
		_reset_buttons()
	if timer != null:
		timer.stop()
	pointer = -2
	activated = false
	if not is_inside_tree():
		return
	var current: Node = get_tree().root.get_node_or_null("CardInspection")
	if current != null and current.source == source:
		current.dismiss(true)


func _exit_tree() -> void:
	cancel()
