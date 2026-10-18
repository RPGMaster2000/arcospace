@tool
extends Control
# RESPONSIBILITY: Draw permanent hull and excess plating from one Hull value.
## TUNE: Bar colors; capacity marker separates red hull from metallic amber plating.
@export var hull_color: Color = Color(0.72, 0.20, 0.18)
@export var plating_color: Color = Color(0.78, 0.57, 0.28)
var preview_hull: int = -1 # Optional repair preview; -1 leaves combat drawing unchanged.
@export var repair_color: Color = Color(0.30, 0.83, 0.46)
var hull: int = 30
var capacity: int = 30
func update_hull(value: int, limit: int) -> void:
	hull = value
	capacity = maxi(1, limit)
	tooltip_text = "Permanent Hull: %d/%d · Ablative Plating: %d" % [mini(hull,capacity), capacity, maxi(0,hull-capacity)]
	queue_redraw()
func _draw() -> void:
	var total: float = float(maxi(maxi(capacity,hull),preview_hull))
	var boundary: float = size.x * capacity / total
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.12,0.10,0.12,0.85))
	draw_rect(Rect2(0,0,size.x * mini(hull,capacity)/total,size.y),hull_color)
	if hull > capacity:
		draw_rect(Rect2(boundary,0,size.x-boundary,size.y),plating_color)
		draw_line(Vector2(boundary,1),Vector2(size.x,1),plating_color.lightened(0.3),1.0)
	if preview_hull > hull:
		var start: float = size.x * mini(hull, capacity) / total
		var finish: float = size.x * mini(preview_hull, capacity) / total
		if finish > start: draw_rect(Rect2(start, 0, finish - start, size.y), repair_color)
		var plating_start: float = size.x * maxi(capacity, hull) / total
		if preview_hull > maxi(capacity, hull):
			draw_rect(Rect2(plating_start, 0, size.x * preview_hull / total - plating_start, size.y), plating_color.lightened(.2))
	draw_line(Vector2(boundary,0),Vector2(boundary,size.y),Color(0.95,0.85,0.65),1.0)
