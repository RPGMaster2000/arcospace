extends Control
## Presentation-only badge for a card effect. A dashed teal frame marks conditional gains.
var resource_kind: String = "materials"
var amount: int = 0
var conditional: bool = false

func configure(kind: String, value: int, is_conditional: bool) -> void:
	resource_kind = kind
	amount = value
	conditional = is_conditional
	tooltip_text = ("%s%+d %s" % ["Conditional " if conditional else "", amount, kind.capitalize()])
	queue_redraw()

func _draw() -> void:
	var accent: Color = Color(0.24, 0.89, 0.85) if conditional else Color(0.36, 0.7, 0.8, 0.8)
	var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
	draw_rect(r, Color(0.02, 0.08, 0.13, 0.95), true)
	if conditional:
		for x in range(1, int(size.x) - 3, 7):
			draw_line(Vector2(x, 1), Vector2(mini(x + 4, int(size.x) - 2), 1), accent, 1.2)
			draw_line(Vector2(x, size.y - 1), Vector2(mini(x + 4, int(size.x) - 2), size.y - 1), accent, 1.2)
		for y in range(1, int(size.y) - 3, 7):
			draw_line(Vector2(1, y), Vector2(1, mini(y + 4, int(size.y) - 2)), accent, 1.2)
			draw_line(Vector2(size.x - 1, y), Vector2(size.x - 1, mini(y + 4, int(size.y) - 2)), accent, 1.2)
	else:
		draw_rect(r, accent, false, 1.0)
	var icon_color: Color = {"materials": Color(1, 0.45, 0.34), "energy": Color(0.45, 0.83, 0.96), "crew": Color(0.64, 0.94, 0.49)}.get(resource_kind, Color.WHITE)
	var center := Vector2(13, size.y / 2.0)
	match resource_kind:
		"materials":
			draw_rect(Rect2(center - Vector2(6, 6), Vector2(12, 12)), icon_color)
		"energy":
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -7), center + Vector2(7, 0), center + Vector2(0, 7), center + Vector2(-7, 0)]), icon_color)
		"crew":
			draw_circle(center + Vector2(0, -4), 4, icon_color)
			draw_rect(Rect2(center + Vector2(-6, 1), Vector2(12, 6)), icon_color)
	if amount != 0:
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(25, size.y / 2.0 + 5), "%+d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.97, 0.89, 0.69))
