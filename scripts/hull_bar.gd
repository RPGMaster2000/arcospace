@tool
extends Control
## Permanent Hull and excess plating are drawn on one scale. Repairs preview
## the same amount the existing checkout will commit.
const ThemeSkin = preload("res://scripts/ui/holographic/skin.gd")
const Meter = preload("res://scripts/ui/holographic/segmented_meter.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")

@export var hull_color: Color = Color("ee7374")
@export var plating_color: Color = Color("dfb26a")
@export var repair_color: Color = Color("76e3aa")
var preview_hull: int = -1
var hull := 30
var capacity := 30
var animate_changes := false
var _initialized := false
var displayed_hull := 30.0:
	set(value):
		displayed_hull = value
		queue_redraw()
var _damage_from := 0.0
var _damage_fade := 0.0:
	set(value):
		_damage_fade = value
		queue_redraw()
var _impact := 0.0:
	set(value):
		_impact = value
		queue_redraw()


func update_hull(value: int, limit: int) -> void:
	var previous := hull
	var previous_capacity := capacity
	hull = value
	capacity = maxi(1, limit)
	tooltip_text = "Permanent Hull: %d/%d · Ablative Plating: %d" % [
		mini(hull, capacity), capacity, maxi(0, hull - capacity)]
	var seconds := Motion.duration(ThemeSkin.DEFAULT.meter_seconds)
	if not _initialized or not animate_changes or seconds == 0.0 or not is_visible_in_tree():
		Motion.stop(self, &"hull")
		displayed_hull = float(hull)
		_impact = 0.0
		_damage_fade = 0.0
	elif hull != previous or capacity != previous_capacity:
		var damaged := hull < previous
		_impact = 0.12 if damaged else 0.36
		var animation := Motion.start(self, &"hull").set_parallel()
		animation.tween_property(self, "displayed_hull", float(hull), seconds * (0.55 if damaged else 1.0))
		animation.tween_property(self, "_impact", 0.0, seconds)
		if damaged:
			_damage_from = maxf(displayed_hull, previous)
			_damage_fade = 0.8
			animation.tween_property(self, "_damage_fade", 0.0, seconds).set_delay(0.09)
		else:
			_damage_fade = 0.0
	_initialized = true
	queue_redraw()


func condition_color() -> Color:
	if not animate_changes: return hull_color
	var ratio := float(hull) / maxi(1, capacity)
	if ratio <= 0.25: return ThemeSkin.DEFAULT.hull
	if ratio <= 0.55: return ThemeSkin.DEFAULT.warning
	return ThemeSkin.DEFAULT.crew


func _draw() -> void:
	var total := maxf(maxf(capacity, displayed_hull), preview_hull)
	if _damage_fade > 0.0: total = maxf(total, _damage_from)
	var boundary := size.x * capacity / total
	var amount := size.x * clampf(displayed_hull, 0, capacity) / total
	Meter.draw_cells(self, size, 0, size.x, Color("2c222d"))
	Meter.draw_cells(self, size, 0, amount, condition_color().lerp(Color.WHITE, _impact), ThemeSkin.DEFAULT.segments, true)
	Meter.draw_cells(self, size, boundary, size.x * displayed_hull / total, plating_color, ThemeSkin.DEFAULT.segments, true)
	if _damage_fade > 0.0:
		Meter.draw_cells(self, size, size.x * displayed_hull / total, size.x * _damage_from / total,
			Color(ThemeSkin.DEFAULT.hull, _damage_fade), ThemeSkin.DEFAULT.segments)
	if preview_hull > hull:
		Meter.draw_cells(self, size, amount, size.x * mini(preview_hull, capacity) / total, repair_color)
		Meter.draw_cells(self, size, size.x * maxi(capacity, hull) / total, size.x * preview_hull / total, plating_color.lightened(0.2))
	if boundary < size.x:
		draw_line(Vector2(boundary, 0), Vector2(boundary, size.y), Color("ffe3aa"), 1.0)
