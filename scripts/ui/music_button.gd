extends Button
# Shared compact control for ship selection and the system header.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var music: Node

func _ready() -> void:
	name = "MusicToggle"
	custom_minimum_size = Vector2(48, 48)
	toggle_mode = true
	Presentation.action(self)
	music = get_node("/root/Music")
	music.enabled_changed.connect(_sync)
	pressed.connect(func(): music.set_enabled(not music.enabled))
	_sync(music.enabled)

func _sync(value: bool) -> void:
	set_pressed_no_signal(value)
	tooltip_text = "Music on — tap to mute" if value else "Music off — tap to enable"
	queue_redraw()

func _draw() -> void:
	# Draw a musical note directly, so no platform emoji/font support is required.
	var color = Color("a9e7ff") if button_pressed else Color("81909e")
	var center = size * 0.5
	draw_line(center + Vector2(3, 5), center + Vector2(3, -10), color, 2.0, true)
	draw_line(center + Vector2(3, -10), center + Vector2(10, -7), color, 3.0, true)
	draw_circle(center + Vector2(-1, 6), 4.0, color)
	if not button_pressed:
		draw_line(center + Vector2(-11, 11), center + Vector2(11, -11), color, 2.0, true)
