extends Control
# RESPONSIBILITY: Draw destination markers and tween the ship to a selected destination.
# DOES NOT: Generate encounters, spend resources or grant rewards.
# Presentation only. The expedition controller supplies markers and handles arrival.
signal arrived(index: int)
signal interrupted
signal travel_started
# TUNE: Seconds of sublight movement before an interception opens.
const INTERCEPTION_DELAY: float = 0.5
# TUNE: Total stopped-ship impact duration, shake in pixels, and red flash opacity.
const IMPACT_DURATION: float = 1.0
const SHAKE_PIXELS: float = 8.0
const FLASH_OPACITY: float = 0.35
const POINTS = [
	Vector2(.21, .23),
	Vector2(.5, .15),
	Vector2(.79, .23),
	Vector2(.21, .70),
	Vector2(.5, .83),
	Vector2(.79, .70)
]
const START = Vector2(.5, .53)
const SERVICE = Vector2(.90, .46)
# TUNE: Sun size multiplier stays within +/-25% of the original radii.
const SUN_SCALE_MIN: float = 0.75
const SUN_SCALE_MAX: float = 1.25
var sun_scale: float = 1.0
var sun_hue: float = 0.1
var star_points := PackedVector2Array()
var travel_duration: float = 1.4
var ship_position: Vector2 = START
var traveling: bool = false
var before_travel: Callable
var intercept_travel: Callable
var markers: Dictionary = {}
var tween: Tween
var interruption_tween: Tween
var impact_tween: Tween
var impact_layer: CanvasLayer
var impact_flash: ColorRect
var impact_active: bool = false
var canvas_origin: Transform2D


func configure(entries: Array, last_destination: int, duration: float, visual_seed: int = 0) -> void:
	_configure_sky(visual_seed)
	travel_duration = duration
	ship_position = destination(last_destination) if last_destination != -1 else START
	for entry in entries:
		var button = Button.new()
		button.text = entry.text
		button.tooltip_text = entry.tooltip
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_override("font", preload("res://assets/fonts/emoji_ui.tres"))
		button.add_theme_font_size_override("font_size", 18)
		preload("res://scripts/ui/encounter_presentation.gd").action(button)
		button.add_theme_color_override("font_color", entry.color)
		button.disabled = entry.completed
		button.pressed.connect(travel.bind(entry.index))
		add_child(button)
		markers[entry.index] = button
	resized.connect(_layout)
	_layout()


func _configure_sky(visual_seed: int) -> void:
	# Local visual RNG keeps encounter, reward and chasedown rolls unchanged.
	var sky_rng := RandomNumberGenerator.new()
	sky_rng.seed = visual_seed
	sun_scale = sky_rng.randf_range(SUN_SCALE_MIN, SUN_SCALE_MAX)
	sun_hue = sky_rng.randf()
	star_points.clear()
	# Jittered cells spread stars across the entire map without diagonal bands.
	for row in range(8):
		for column in range(12):
			star_points.append(Vector2(
				(column + sky_rng.randf_range(0.1, 0.9)) / 12.0,
				(row + sky_rng.randf_range(0.1, 0.9)) / 8.0
			))


func destination(index: int) -> Vector2:
	return SERVICE if index == -2 else POINTS[index]


func _layout() -> void:
	var target_size = Vector2(clampf(size.x * .23, 120, 230), clampf(size.y * .20, 64, 100))
	for index in markers:
		var button: Button = markers[index]
		button.size = target_size
		button.position = destination(index) * size - target_size / 2
	queue_redraw()


# Lock further destination input until arrival; leaving the tree kills travel instead of opening a stale encounter.
func travel(index: int) -> void:
	if traveling or not markers.has(index) or markers[index].disabled:
		return
	if before_travel.is_valid() and not before_travel.call(index):
		return
	var intercepted: bool = intercept_travel.is_valid() and intercept_travel.call(index)
	traveling = true
	travel_started.emit()
	for button in markers.values():
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tween = create_tween()
	(
		tween
		. tween_method(
			_move_ship, ship_position, destination(index),
			maxf(travel_duration, INTERCEPTION_DELAY + 0.1) if intercepted else travel_duration
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	if intercepted:
		# A separate node-bound timer stops movement without emitting arrival.
		interruption_tween = create_tween()
		interruption_tween.tween_interval(INTERCEPTION_DELAY)
		interruption_tween.tween_callback(_interrupt_travel)
	else:
		tween.tween_callback(func(): arrived.emit(index))


func _interrupt_travel() -> void:
	tween.kill()
	impact_active = true
	canvas_origin = get_viewport().canvas_transform
	impact_layer = CanvasLayer.new()
	impact_layer.layer = 100
	add_child(impact_layer)
	impact_flash = ColorRect.new()
	impact_flash.color = Color(1.0, 0.0, 0.0, 0.0)
	impact_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Block screen controls until the one-second impact finishes.
	impact_flash.mouse_filter = Control.MOUSE_FILTER_STOP
	impact_layer.add_child(impact_flash)
	impact_tween = create_tween()
	impact_tween.tween_method(_update_impact, 0.0, 1.0, IMPACT_DURATION)
	impact_tween.tween_callback(_finish_impact)


func _update_impact(progress: float) -> void:
	# Deterministic shake does not consume gameplay RNG; it settles to zero.
	var strength: float = SHAKE_PIXELS * (1.0 - progress)
	var offset := Vector2(sin(progress * 93.0), sin(progress * 127.0)) * strength
	get_viewport().canvas_transform = canvas_origin.translated(offset)
	# Two quick pulses at the start, then the shake continues for the remaining time.
	var first: float = maxf(0.0, 1.0 - absf(progress - 0.06) / 0.06)
	var second: float = maxf(0.0, 1.0 - absf(progress - 0.24) / 0.06)
	impact_flash.color.a = FLASH_OPACITY * maxf(first, second)


func _finish_impact() -> void:
	_clear_impact()
	interrupted.emit()


func _clear_impact() -> void:
	if impact_active:
		get_viewport().canvas_transform = canvas_origin
		impact_active = false
	if is_instance_valid(impact_layer):
		impact_layer.visible = false
		impact_layer.queue_free()


func _move_ship(point: Vector2) -> void:
	ship_position = point
	queue_redraw()


func cancel_presentation() -> void:
	traveling = false
	if impact_tween:
		impact_tween.kill()
	_clear_impact()
	if interruption_tween:
		interruption_tween.kill()
	if tween:
		tween.kill()


func _exit_tree() -> void:
	cancel_presentation()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1422"))
	for point in star_points:
		draw_circle(point * size, 1.2, Color("708399"))
	var center = size * Vector2(.5, .46)
	draw_circle(center, 37 * sun_scale, Color.from_hsv(sun_hue, 0.45, 0.29))
	draw_circle(center, 26 * sun_scale, Color.from_hsv(sun_hue, 0.68, 0.85))
	draw_circle(center, 20 * sun_scale, Color.from_hsv(sun_hue, 0.37, 1.0))
	for index in markers:
		var button: Button = markers[index]
		var point: Vector2 = button.position + Vector2(-15, button.size.y / 2)
		var tint = Color("4a6174") if button.disabled else button.get_theme_color("font_color")
		if index == -2:
			draw_rect(Rect2(point - Vector2(8, 8), Vector2(16, 16)), tint, false, 2)
		else:
			draw_circle(point, 11, tint.darkened(.4))
			draw_arc(point, 11, 0, TAU, 24, tint, 1.5, true)
	var ship = ship_position * size - Vector2(0, clampf(size.y * .20, 64, 100) / 2 + 16)
	draw_colored_polygon(
		PackedVector2Array(
			[
				ship + Vector2(0, -13),
				ship + Vector2(-9, 10),
				ship + Vector2(0, 5),
				ship + Vector2(9, 10)
			]
		),
		Color("a7e5fa")
	)
