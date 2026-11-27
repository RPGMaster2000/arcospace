extends Control
## Temporary projected card backs. Shared skin replacements may supply the face artwork.
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const EXTENT := Vector2(54, 76)

var assembly := 0.0:
	set(value):
		assembly = value
		queue_redraw()
var tint := Holo.DEFAULT.edge:
	set(value):
		tint = value
		queue_redraw()
var stack := true
var premium := false
var _frame := Holo.frame("deck.back")
const SLICES := [0, 1, -1, 2, -2]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.set_content_margin_all(0)
	_frame.details = 0
	_frame.cut = 7
	size = EXTENT


func _draw() -> void:
	if assembly <= 0.001: return
	var center := size * 0.5
	var light := tint.lightened(0.42)
	if stack:
		var projection := Vector2(center.x, size.y + 5)
		for i in range(2, 0, -1):
			_draw_back(Rect2(Vector2(-5 * i, -4 * i), size), Color(tint, 0.36 * assembly))
		draw_line(projection - Vector2(30 * assembly, 0), projection + Vector2(30 * assembly, 0),
			Color(light, 0.65 * assembly), 2.0, true)
		if premium:
			var beams := PackedVector2Array([projection + Vector2(-25, 0), Vector2(-4, size.y * 0.48),
				projection + Vector2(26, 0), Vector2(size.x + 4, size.y * 0.48)])
			draw_multiline(beams, Color(tint, 0.48 * assembly), 1.0, true)
	var slice_height := size.y / SLICES.size()
	if assembly < 0.96 and stack:
		for index in SLICES.size():
			var reach := smoothstep(index * 0.10, 0.55 + index * 0.10, assembly)
			var vertical: float = SLICES[index] * slice_height * reach
			var extent := Vector2(lerpf(5, size.x, reach), slice_height * reach)
			draw_rect(Rect2(center + Vector2(0, vertical) - extent * 0.5, extent),
				Color(tint, 0.09 + reach * 0.18))
			draw_line(center + Vector2(-extent.x * 0.5, vertical), center + Vector2(extent.x * 0.5, vertical),
				Color(light, reach * 0.8), 1.0, true)
	var face := smoothstep(0.47 if stack else 0.0, 1.0, assembly)
	if face > 0.0:
		var extent := Vector2(size.x * lerpf(0.7, 1.0, face), size.y * face)
		_draw_back(Rect2(center - extent * 0.5, extent), Color(tint, face))
		if Holo.DEFAULT.deck_back == null and face > 0.58:
			var wide := 14.0 * face
			var peak := Vector2(0, -19.0 * face)
			var points := PackedVector2Array([center + peak, center + Vector2(wide, 10),
				center + Vector2(0, 4), center + Vector2(-wide, 10), center + peak])
			draw_polyline(points, Color(light, face * 0.9), 1.5, true)
			draw_line(center + Vector2(-9, 18), center + Vector2(9, 18), Color(light, face * 0.65), 1.0, true)
		if premium:
			draw_line(Vector2(9, 10), Vector2(size.x - 9, 10), Color(light, face * 0.7), 1.0, true)


func _draw_back(rect: Rect2, ink: Color) -> void:
	_frame.border_color = ink
	_frame.bg_color = Color(Holo.DEFAULT.surface_depth, ink.a * 0.93)
	_frame.depth_color = Color(Holo.DEFAULT.surface, ink.a)
	_frame.draw(get_canvas_item(), rect)
	if Holo.DEFAULT.deck_back != null:
		draw_texture_rect(Holo.DEFAULT.deck_back, rect.grow(-3), false, Color(1, 1, 1, ink.a))
