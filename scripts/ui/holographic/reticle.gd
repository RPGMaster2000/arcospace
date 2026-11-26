@tool
extends Control

const Holo = preload("res://scripts/ui/holographic/skin.gd")
@export var tint := Color("65dee9")
@export var configuration: Holo.Settings = Holo.DEFAULT


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(center.x, center.y) - 8.0
	if radius <= 1: return
	if configuration.reticle != null:
		draw_texture_rect(configuration.reticle, Rect2(Vector2.ZERO, size), false, tint)
		return
	draw_arc(center, radius, 0, TAU, 48, Color(tint, 0.37), 1.0, true)
	for quadrant in 4:
		var angle := quadrant * PI * 0.5
		draw_arc(center, radius, angle - 0.30, angle + 0.30, 8, tint, 2.0, true)
		draw_arc(center, radius * 0.74, angle + 0.24, angle + 1.2, 9, Color(tint, 0.63), 1.0, true)
		var bearing := Vector2.from_angle(angle)
		draw_line(center + bearing * (radius - 5.0), center + bearing * (radius + 6.0), tint, 1.0, true)
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -8), center + Vector2(6, 6), center + Vector2(0, 3), center + Vector2(-6, 6)]), tint)
