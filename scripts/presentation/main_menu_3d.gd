extends Node3D
# RESPONSIBILITY: Title, camera and fleet choreography; never reads or changes a run.
signal selection_ready
signal departure_finished

enum Phase { INTRO_BACKGROUND, INTRO_LOGO, PRESS_TO_PLAY, CAMERA_TRANSITION, SHIP_SELECTION, LAUNCHING, LOADING }
@export_group("Title")
@export var title_text: String = "ARCOSPACE"
@export var logo_texture: Texture2D
@export_range(24, 160) var title_font_size: int = 76
@export_range(0.1, 8) var background_fade_duration: float = 2.0
@export_range(0.1, 8) var logo_fade_duration: float = 2.0
@export_range(0, 1) var title_vertical_position: float = 0.40
@export_range(0, 1) var prompt_vertical_position: float = 0.61
@export_range(12, 48) var prompt_font_size: int = 22
@export_range(0.2, 6) var blink_duration: float = 2.4
@export_range(0, 1) var prompt_min_opacity: float = 0.3
@export_range(0, 1) var prompt_max_opacity: float = 1.0
@export_group("Camera")
@export var title_anchor: Node3D
@export var selection_anchor: Node3D
@export_range(0.1, 8) var camera_transition_duration: float = 2.5
@export var camera_easing: Tween.EaseType = Tween.EASE_IN_OUT
@export var camera_transition: Tween.TransitionType = Tween.TRANS_SINE
var phase: Phase = Phase.INTRO_BACKGROUND
var phase_tween: Tween
var prompt_time: float = 0.0
var skip_cinematics: bool = false
@onready var camera: Camera3D = $Camera3D
@onready var logo: Control = $Title/Logo
@onready var prompt: Label = $Title/Prompt
@onready var curtain: ColorRect = $Title/Curtain


func _ready() -> void:
	camera.transform = title_anchor.transform
	$Title/Logo/Text.text = title_text
	$Title/Logo/Text.add_theme_font_size_override("font_size", title_font_size)
	$Title/Logo/Image.texture = logo_texture
	$Title/Logo/Image.visible = logo_texture != null
	$Title/Logo/Text.visible = logo_texture == null
	logo.anchor_top = title_vertical_position
	logo.anchor_bottom = title_vertical_position
	prompt.anchor_top = prompt_vertical_position
	prompt.anchor_bottom = prompt_vertical_position
	prompt.add_theme_font_size_override("font_size", prompt_font_size)
	prompt.text = "TAP SCREEN TO PLAY" if DisplayServer.is_touchscreen_available() else "PRESS ANY BUTTON TO PLAY"
	logo.modulate.a = 0.0
	prompt.hide()
	curtain.color = Color.BLACK
	if skip_cinematics:
		_finish_intro()
	else:
		phase_tween = create_tween()
		phase_tween.tween_property(curtain, "color:a", 0.0, background_fade_duration)
		phase_tween.tween_callback(func(): phase = Phase.INTRO_LOGO)
		phase_tween.tween_property(logo, "modulate:a", 1.0, logo_fade_duration)
		phase_tween.tween_callback(_finish_intro)


func _process(delta: float) -> void:
	if phase == Phase.PRESS_TO_PLAY:
		prompt_time += delta
		prompt.modulate.a = lerpf(prompt_min_opacity, prompt_max_opacity, (1.0 + cos(prompt_time * TAU / blink_duration)) * 0.5)


func _stop_tween() -> void:
	if phase_tween != null: phase_tween.kill()


func _finish_intro() -> void:
	curtain.color.a = 0.0
	logo.modulate.a = 1.0
	prompt.show()
	phase = Phase.PRESS_TO_PLAY


# One press finishes the intro; only a distinct second press reveals selection.
func advance() -> void:
	if phase in [Phase.INTRO_BACKGROUND, Phase.INTRO_LOGO]:
		_stop_tween()
		_finish_intro()
	elif phase == Phase.PRESS_TO_PLAY:
		phase = Phase.CAMERA_TRANSITION
		_stop_tween()
		prompt.hide()
		phase_tween = create_tween().set_ease(camera_easing).set_trans(camera_transition)
		phase_tween.tween_property(logo, "modulate:a", 0.0, 0.08 if skip_cinematics else 0.5)
		phase_tween.parallel().tween_property(camera, "transform", selection_anchor.transform, 0.08 if skip_cinematics else camera_transition_duration)
		phase_tween.tween_callback(func():
			phase = Phase.SHIP_SELECTION
			selection_ready.emit())


func _exit_tree() -> void:
	_stop_tween()
