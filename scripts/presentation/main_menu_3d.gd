extends Node3D

const Sound = preload("res://scripts/audio/sfx.gd")
# RESPONSIBILITY: Title, camera and fleet choreography; never reads or changes a run.
signal phase_changed
signal selection_ready
signal departure_finished

enum Phase { INTRO_BACKGROUND, INTRO_LOGO, PRESS_TO_PLAY, CAMERA_TRANSITION, SHIP_SELECTION, LAUNCHING, LOADING }
@export_group("Title")
@export var title_text: String = "ARCOSPACE"
@export var logo_texture: Texture2D
@export_range(24, 160) var title_font_size: int = 152
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
@export_group("Fleet")
@export_range(3, 12) var fleet_spacing: float = 6.2
@export_range(0, 0.3) var fleet_curvature: float = 0.025
@export var ship_orientation: Vector3 = Vector3(0, 30, -30)
## Bank around each ship's own forward (+X) axis, toward its right.
@export_range(-180, 180) var ship_roll_degrees: float = 30.0
@export_range(0, 30) var rotation_degrees_per_second: float = 14.0
@export_range(0.05, 3) var selection_duration: float = 0.55
@export var framing_offset: Vector3 = Vector3.ZERO
## Optional camera distance corrections in library order, without changing ship geometry.
@export var ship_camera_offsets: PackedVector3Array = PackedVector3Array()
@export_group("Launch")
@export_range(0.05, 5) var orientation_duration: float = 1.0
@export var orientation_easing: Tween.EaseType = Tween.EASE_IN_OUT
## Camera-space +X is screen right, +Y is screen up, -Z travels away.
@export var departure_direction: Vector3 = Vector3(1, 0.65, -0.6)
@export_range(0, 4) var departure_pause_duration: float = 1.0
@export_range(1, 200) var departure_acceleration: float = 110.0
@export_range(0.1, 4) var departure_travel_duration: float = 0.9
var models: Array[Node3D] = []
var selected_model: Node3D
var camera_tween: Tween
var phase: Phase = Phase.INTRO_BACKGROUND:
	set(value):
		phase = value
		phase_changed.emit()
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
	get_viewport().size_changed.connect(_fit_title)
	_fit_title()
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


func _fit_title() -> void:
	var width: float = get_viewport().get_visible_rect().size.x
	var font: Font = $Title/Logo/Text.get_theme_font("font")
	var full_width: float = font.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_font_size).x
	$Title/Logo/Text.add_theme_font_size_override("font_size", int(title_font_size * minf(1.0, width * 0.90 / maxf(full_width, 1.0))))


func _process(delta: float) -> void:
	if phase == Phase.SHIP_SELECTION and selected_model != null:
		selected_model.rotate_y(deg_to_rad(rotation_degrees_per_second) * delta)
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


func populate(profiles: Array) -> void:
	for index in range(profiles.size()):
		var profile: Resource = profiles[index]
		var mount := Node3D.new()
		mount.name = profile.ship_name
		$Fleet.add_child(mount)
		mount.position = Vector3(fleet_curvature * index * index, 0, -index * fleet_spacing)
		mount.rotation_degrees = ship_orientation
		mount.rotate_object_local(Vector3.RIGHT, deg_to_rad(ship_roll_degrees))
		var model: Node3D = profile.model_scene.instantiate()
		mount.add_child(model)
		model.set_hull_color(profile.hull_color)
		model.set_hull_strength(profile.hull_capacity)
		model.get_node("Shield").hide()
		model.set_process(false)
		for light in model.find_children("*", "Light3D", true, false): light.hide()
		models.append(mount)


func select_ship(index: int, immediate: bool = false) -> void:
	if models.is_empty(): return
	selected_model = models[index]
	$Fleet/ShowcaseLight.position = selected_model.position + Vector3(4, 3, 1)
	if camera_tween != null: camera_tween.kill()
	var target: Transform3D = selection_anchor.transform
	target.origin += $Fleet.basis * selected_model.position + framing_offset
	if index < ship_camera_offsets.size(): target.origin += ship_camera_offsets[index]
	# The fleet root controls the world placement; camera tracks only lineup displacement.
	if phase == Phase.SHIP_SELECTION:
		if immediate: camera.transform = target
		else:
			camera_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			camera_tween.tween_property(camera, "transform", target, selection_duration)


func depart() -> void:
	if phase != Phase.SHIP_SELECTION: return
	phase = Phase.LAUNCHING
	if camera_tween != null: camera_tween.kill()
	_stop_tween()
	phase_tween = create_tween()
	if skip_cinematics:
		Sound.play(&"ui_confirm", self)
		phase_tween.tween_callback(departure_finished.emit)
		return
	var direction: Vector3 = (camera.global_basis * departure_direction).normalized()
	if direction.is_zero_approx(): direction = camera.global_basis.x
	var motion: Vector3 = $Fleet.global_basis.inverse() * direction
	var forward: Vector3 = motion.normalized()
	var up: Vector3 = Vector3.UP if absf(forward.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var side: Vector3 = forward.cross(up).normalized()
	var heading := Basis(forward, side.cross(forward), side).get_rotation_quaternion()
	phase_tween.set_ease(orientation_easing).set_trans(Tween.TRANS_SINE)
	phase_tween.tween_property(selected_model, "quaternion", heading, orientation_duration)
	phase_tween.tween_callback(func(): Sound.play(&"ship_departure", self))
	phase_tween.tween_interval(departure_pause_duration)
	var origin: Vector3 = selected_model.position
	phase_tween.tween_method(func(t: float): selected_model.position = origin + motion * 0.5 * departure_acceleration * t * t, 0.0, departure_travel_duration, departure_travel_duration).set_trans(Tween.TRANS_LINEAR)
	phase_tween.tween_callback(departure_finished.emit)


func _exit_tree() -> void:
	_stop_tween()
	if camera_tween != null: camera_tween.kill()
