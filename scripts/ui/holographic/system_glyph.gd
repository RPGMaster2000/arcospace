extends Control
## Small vector symbols shared by the battle systems controls.
var kind := "balanced":
	set(value):
		kind = value
		queue_redraw()
var ink := Color.WHITE:
	set(value):
		ink = value
		queue_redraw()

var launcher := false
var expanded := false:
	set(value):
		expanded = value
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var zoom := minf(size.x, size.y) / 24.0
	draw_set_transform((size - Vector2.ONE * 24 * zoom) * 0.5, 0.0, Vector2.ONE * zoom)
	match kind:
		"offense":
			_path([Vector2(5, 20), Vector2(18, 7), Vector2(20, 3), Vector2(16, 5), Vector2(4, 17)])
			_path([Vector2(3, 14), Vector2(10, 21)])
			_path([Vector2(8, 6), Vector2(4, 3), Vector2(6, 8), Vector2(19, 21)])
			_path([Vector2(20, 15), Vector2(14, 21)])
		"defense":
			_path([Vector2(12, 2), Vector2(20, 6), Vector2(19, 15), Vector2(12, 22),
				Vector2(5, 15), Vector2(4, 6), Vector2(12, 2)])
			_path([Vector2(12, 6), Vector2(12, 16)])
		"systems":
			draw_arc(Vector2(12, 12), 7, 0.0, TAU, 20, ink, 1.6, true)
			draw_arc(Vector2(12, 12), 3, 0.0, TAU, 12, ink, 1.4, true)
			for spoke in 8:
				var ray := Vector2.from_angle(spoke * TAU / 8.0)
				draw_line(Vector2(12, 12) + ray * 7, Vector2(12, 12) + ray * 10, ink, 2.0, true)
		"emp":
			_path([Vector2(14, 2), Vector2(5, 13), Vector2(11, 13), Vector2(10, 22),
				Vector2(19, 10), Vector2(13, 10), Vector2(14, 2)])
		_:
			_path([Vector2(12, 6), Vector2(12, 11), Vector2(5, 11), Vector2(5, 17)])
			_path([Vector2(12, 11), Vector2(19, 11), Vector2(19, 17)])
			_path([Vector2(12, 11), Vector2(12, 17)])
			for x in [5, 12, 19]:
				draw_rect(Rect2(x - 1.8, 17, 3.6, 3.6), ink, false, 1.2)
			draw_circle(Vector2(12, 4), 2, ink, true, -1.0, true)

	if launcher:
		var edge := Vector2(size.x - 6.0, size.y * 0.5)
		var direction := -1.0 if expanded else 1.0
		draw_set_transform(Vector2.ZERO)
		draw_polyline(PackedVector2Array([edge + Vector2(-2.5 * direction, -4), edge + Vector2(1.5 * direction, 0),
			edge + Vector2(-2.5 * direction, 4)]), ink, 1.25, true)


func _path(points: PackedVector2Array) -> void:
	draw_polyline(points, ink, 1.6, true)
