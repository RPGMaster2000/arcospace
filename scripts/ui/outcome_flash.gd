extends CanvasLayer
# One result roll, one restrained color pulse; reveal the reward only after it finishes.
@export_range(0.1, 3.0, 0.1) var duration: float = 1.0
var shade: ColorRect
var tween: Tween
var active: bool = false
var success: bool = false

func _ready() -> void:
	layer = 150
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	shade.hide()

func play(good_outcome: bool) -> void:
	if active: return
	active = true
	success = good_outcome
	shade.color = Color(0.15, 0.85, 0.35, 0.32) if success else Color(0.95, 0.18, 0.15, 0.32)
	shade.modulate.a = 1
	shade.show()
	tween = create_tween()
	tween.tween_interval(duration * 0.7)
	tween.tween_property(shade, "modulate:a", 0.0, duration * 0.3)
	await tween.finished
	shade.hide()
	active = false

func _input(_event: InputEvent) -> void:
	if active: get_viewport().set_input_as_handled()
