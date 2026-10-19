extends Control
# RESPONSIBILITY: Draw destination markers and tween the ship to a selected destination.
# DOES NOT: Generate encounters, spend resources or grant rewards.
# Presentation only. The expedition controller supplies markers and handles arrival.
signal arrived(index: int)
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
var travel_duration: float = 1.4
var ship_position: Vector2 = START
var traveling: bool = false
var before_travel: Callable
var markers: Dictionary = {}
var tween: Tween


func configure(entries: Array, last_destination: int, duration: float) -> void:
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
	traveling = true
	for button in markers.values():
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tween = create_tween()
	(
		tween
		. tween_method(_move_ship, ship_position, destination(index), travel_duration)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	tween.tween_callback(func(): arrived.emit(index))


func _move_ship(point: Vector2) -> void:
	ship_position = point
	queue_redraw()


func _exit_tree() -> void:
	if tween:
		tween.kill()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0a1422"))
	for i in range(45):
		var point = Vector2(fposmod(i * .618 + .04, 1), fposmod(i * .381 + .08, 1)) * size
		draw_circle(point, 1.2, Color("708399"))
	var center = size * Vector2(.5, .46)
	draw_circle(center, 37, Color("493b28"))
	draw_circle(center, 26, Color("d89c46"))
	draw_circle(center, 20, Color("ffe0a0"))
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
