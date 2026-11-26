@tool
extends StyleBox
## A native draw command per panel layer. Godot caches the resulting canvas
## commands until the host redraws. Nothing is updated by a render-frame timer.

@export var bg_color := Color("102338ee"):
	set(value):
		bg_color = value
		emit_changed()
@export var depth_color := Color("071220ee")
@export var border_color := Color("62cbe9"):
	set(value):
		border_color = value
		emit_changed()
@export var border_width_top := 1.0
@export var cut := 11.0
@export var draw_center := true
@export var details := 1
@export var shadow_color := Color.TRANSPARENT
@export var shadow_size := 0
@export var frame_texture: StyleBoxTexture
@export var background_texture: Texture2D
@export var ornament: Texture2D
@export var ornament_tint := Color.TRANSPARENT


func _draw(canvas: RID, rect: Rect2) -> void:
	if rect.size.x < 3.0 or rect.size.y < 2.0: return
	if background_texture != null and draw_center:
		RenderingServer.canvas_item_add_texture_rect(canvas, rect, background_texture.get_rid())
	if frame_texture != null:
		frame_texture.draw(canvas, rect)
		_draw_ornament(canvas, rect)
		return

	var area := rect.grow(-maxf(0.5, border_width_top * 0.5))
	var clipped := minf(cut, minf(area.size.x, area.size.y) * 0.35)
	var path := outline(area, clipped)
	if draw_center and bg_color.a > 0.0 and background_texture == null:
		var dim := Color(bg_color.lerp(depth_color, 0.54), bg_color.a)
		var colors := PackedColorArray()
		for point in path:
			colors.append(bg_color.lerp(dim, (point.y - area.position.y) / maxf(1, area.size.y)))
		RenderingServer.canvas_item_add_polygon(canvas, path, colors)
	path.append(path[0])
	if shadow_size > 0 and shadow_color.a > 0.0:
		RenderingServer.canvas_item_add_polyline(canvas, path, PackedColorArray([shadow_color]), shadow_size + 1, true)
	RenderingServer.canvas_item_add_polyline(canvas, path, PackedColorArray([border_color]), border_width_top, true)
	if details > 0 and clipped >= 2.0:
		var lit := border_color.lightened(0.28)
		var reach := minf(area.size.x * 0.32, 36.0)
		var upper := PackedVector2Array([path[7], path[0], path[0] + Vector2(reach, 0)])
		var lower := PackedVector2Array([path[3], path[4], path[4] - Vector2(reach * 0.85, 0)])
		RenderingServer.canvas_item_add_polyline(canvas, upper, PackedColorArray([lit]), border_width_top + 0.7, true)
		RenderingServer.canvas_item_add_polyline(canvas, lower, PackedColorArray([lit]), border_width_top + 0.7, true)
	if details > 1 and area.size.x > 72.0 and area.size.y > 48.0:
		var trace := Color(border_color, border_color.a * 0.34) if ornament_tint == Color.TRANSPARENT else Color(ornament_tint, 0.82)
		var start := area.position + Vector2(clipped + 3.0, 5.0)
		RenderingServer.canvas_item_add_line(canvas, start, start + Vector2(minf(area.size.x * 0.48, 82.0), 0), trace, 1.0)
		var ticks := PackedVector2Array()
		for i in range(3 + details):
			var point := area.end - Vector2(clipped + 7.0 + i * 5.0, 6.0)
			ticks.append(point)
			ticks.append(point + Vector2(3, -3))
		RenderingServer.canvas_item_add_multiline(canvas, ticks, PackedColorArray([trace]), 1.0)
	if details >= 2 and minf(area.size.x, area.size.y) > 8.0:
		var inner := area.grow(-3.5)
		var secondary := outline(inner, maxf(1.0, clipped - 2.0))
		secondary.append(secondary[0])
		var secondary_tint := border_color if ornament_tint == Color.TRANSPARENT else ornament_tint
		RenderingServer.canvas_item_add_polyline(canvas, secondary,
			PackedColorArray([Color(secondary_tint, 0.43 if details >= 3 else 0.24)]), 1.0, true)
	_draw_ornament(canvas, rect)


func _draw_ornament(canvas: RID, rect: Rect2) -> void:
	if ornament == null: return
	var extent := Vector2(ornament.get_size()).limit_length(minf(28.0, rect.size.y * 0.5))
	RenderingServer.canvas_item_add_texture_rect(canvas, Rect2(rect.position + Vector2(12, 6), extent), ornament.get_rid())


static func outline(rect: Rect2, c: float) -> PackedVector2Array:
	var top := rect.position
	var bottom := rect.end
	return PackedVector2Array([
		top + Vector2(c, 0), Vector2(bottom.x - c * 0.65, top.y),
		Vector2(bottom.x, top.y + c * 0.65), bottom - Vector2(0, c),
		bottom - Vector2(c, 0), Vector2(top.x + c * 0.65, bottom.y),
		Vector2(top.x, bottom.y - c * 0.65), top + Vector2(0, c),
	])
