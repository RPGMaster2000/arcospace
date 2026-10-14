@tool
extends Control
# RESPONSIBILITY: Draw permanent hull and excess plating from one Hull value.
## TUNE: Bar colors; capacity marker separates red hull from metallic amber plating.
@export var hull_color: Color = Color(0.72, 0.20, 0.18)
@export var plating_color: Color = Color(0.78, 0.57, 0.28)
var hull: int = 30
var capacity: int = 35
func update_hull(value: int, limit: int) -> void:
	hull = value
	capacity = maxi(1, limit)
	$Plating.text = "+%d Ablative Plating" % maxi(0, hull - capacity) if hull > capacity else ""
	tooltip_text = "Permanent Hull: %d/%d · Ablative Plating: %d" % [mini(hull,capacity), capacity, maxi(0,hull-capacity)]
	queue_redraw()
func _ready() -> void:
	var label = Label.new()
	label.name = "Plating"
	label.position = Vector2(0,-54)
	label.add_theme_font_size_override("font_size",14)
	label.add_theme_color_override("font_color",plating_color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	update_hull(hull,capacity)
func _draw() -> void:
	var total: float = float(maxi(capacity,hull))
	var boundary: float = size.x * capacity / total
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.12,0.10,0.12,0.85))
	draw_rect(Rect2(0,0,size.x * mini(hull,capacity)/total,size.y),hull_color)
	if hull > capacity:
		draw_rect(Rect2(boundary,0,size.x-boundary,size.y),plating_color)
		draw_line(Vector2(boundary,1),Vector2(size.x,1),plating_color.lightened(0.3),1.0)
	draw_line(Vector2(boundary,0),Vector2(boundary,size.y),Color(0.95,0.85,0.65),1.0)
