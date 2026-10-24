extends CanvasLayer
# Scene-owned curtain survives replacement of the map UI by the battle child.
# Owns one cancellable fade/delay at a time; interrupted waiters return false.
signal settled
var curtain: ColorRect
var motion: Tween
var revision: int = 0


func _ready() -> void:
	layer = 300
	curtain = ColorRect.new()
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	curtain.color = Color(1, 1, 1, 0)
	curtain.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(curtain)
	curtain.hide()


func block() -> void:
	curtain.show()


func fade(opacity: float, duration: float) -> bool:
	cancel(false)
	var request: int = revision
	block()
	motion = create_tween()
	motion.tween_property(curtain, "color:a", opacity, duration)
	motion.tween_callback(settled.emit)
	await settled
	if request != revision or not is_inside_tree():
		return false
	if opacity == 0:
		curtain.hide()
	return true


func pause(duration: float) -> bool:
	cancel(false)
	var request: int = revision
	motion = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	motion.tween_interval(duration)
	motion.tween_callback(settled.emit)
	await settled
	return request == revision and is_inside_tree()


func cancel(clear: bool = true) -> void:
	revision += 1
	if motion and motion.is_valid():
		motion.kill()
	if clear and is_instance_valid(curtain):
		curtain.color.a = 0
		curtain.hide()
	settled.emit()


func _exit_tree() -> void:
	cancel()
