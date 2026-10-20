extends Button

# RESPONSIBILITY: Open the shared settings window from any game screen.
signal main_menu_requested
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var is_main_menu: bool = false
var menu: CanvasLayer


func _ready() -> void:
	name = "SettingsButton"
	process_mode = Node.PROCESS_MODE_ALWAYS
	custom_minimum_size = Vector2(48, 48)
	tooltip_text = "Settings"
	Presentation.action(self)
	menu = preload("res://scripts/ui/settings_menu.gd").new()
	menu.is_main_menu = is_main_menu
	add_child(menu)
	menu.main_menu_requested.connect(func(): main_menu_requested.emit())
	pressed.connect(menu.present)


func _draw() -> void:
	# Native geometry keeps the gear readable without relying on emoji fonts.
	var center: Vector2 = size * 0.5
	var color := Color("a9e7ff")
	for tooth in range(8):
		var direction := Vector2.from_angle(tooth * TAU / 8.0)
		draw_line(center + direction * 10, center + direction * 14, color, 4, true)
	draw_arc(center, 9, 0, TAU, 32, color, 2, true)
	draw_arc(center, 3, 0, TAU, 20, color, 2, true)
