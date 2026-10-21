extends CanvasLayer

# RESPONSIBILITY: Present the resolved PoI success/failure pulse before showing its reward.
# One result roll, one restrained color pulse; reveal the reward only after it finishes.
@export var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
var duration: float:
	get:
		return visual_settings.poi_reveal_duration
signal visual_finished
var closing: bool = false
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
	if active:
		return
	active = true
	success = good_outcome
	shade.color = (
		visual_settings.poi_success_color if success else visual_settings.poi_failure_color
	)
	shade.modulate.a = 1
	shade.show()
	tween = create_tween()
	tween.tween_interval(duration * 0.7)
	tween.tween_property(shade, "modulate:a", 0.0, duration * 0.3)
	tween.finished.connect(func(): visual_finished.emit(), CONNECT_ONE_SHOT)
	await visual_finished
	if closing:
		return
	shade.hide()
	active = false


func _input(_event: InputEvent) -> void:
	if active:
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	closing = true
	active = false
	if tween != null and tween.is_valid():
		tween.kill()
	visual_finished.emit()
