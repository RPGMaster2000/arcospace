extends CanvasLayer
# Scene-owned curtain survives replacement of the map UI by the battle child.
signal settled
var curtain: ColorRect
var motion: Tween


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


func fade(opacity: float, duration: float) -> void:
	block()
	if motion and motion.is_valid():
		motion.kill()
	motion = create_tween()
	motion.tween_property(curtain, "color:a", opacity, duration)
	motion.tween_callback(settled.emit)
	await settled
	if is_instance_valid(curtain) and opacity == 0:
		curtain.hide()


func _exit_tree() -> void:
	if motion and motion.is_valid():
		motion.kill()
	settled.emit()
