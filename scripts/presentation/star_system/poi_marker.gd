extends Button
# Presentation-only destination tag; the map supplies its projected anchor each frame.
var anchor_point := Vector2.ZERO
var full_text := ""
var event_icon := "◇"
var planet := false
var full_size := Vector2(128,36)
var compact := false
var accent := Color("a6e9ff")


func style_tag(color: Color) -> void:
	accent = color.lightened(0.3)
	flat = false
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.fallbacks = [preload("res://assets/fonts/emoji_ui.tres")]
	font.variation_embolden = 1.0
	add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 14)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.025, 0.065, 0.105, 0.94)
		box.border_color = accent * Color(1, 1, 1, 0.65)
		box.set_border_width_all(1)
		box.set_corner_radius_all(10)
		box.content_margin_left = 7
		box.content_margin_right = 7
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		if state in ["hover", "focus", "pressed"]:
			box.bg_color = Color(0.055, 0.14, 0.21, 0.97)
			box.border_color = accent
		if state == "disabled":
			box.bg_color.a = 0.78
			box.border_color.a = 0.35
		add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, Color.WHITE.lerp(accent, 0.12))
	add_theme_color_override("font_disabled_color", accent.lerp(Color.WHITE, 0.5).darkened(0.18))
	add_theme_color_override("font_outline_color", Color("020611"))
	add_theme_constant_override("outline_size", 2)


func set_label(value: String, symbol: String, is_planet: bool) -> void:
	full_text = value
	event_icon = symbol
	planet = is_planet
	var width: float = get_theme_font("font").get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+18
	full_size = Vector2(clampf(width,54,180),44 if width>180 else 32)
	show_compact(compact)

func show_compact(enabled: bool) -> void:
	var target: bool = enabled and not planet
	var caption: String = event_icon if target else full_text
	var dimensions: Vector2 = Vector2(36,32) if target else full_size
	if compact == target and text == caption and custom_minimum_size == dimensions: return
	compact = target
	text = caption
	custom_minimum_size = dimensions
	size = dimensions


func _draw() -> void:
	if Rect2(Vector2.ZERO, size).has_point(anchor_point):
		return
	var direction := anchor_point - size * 0.5
	var ratio: float = minf(size.x * 0.5 / maxf(absf(direction.x), 0.001), size.y * 0.5 / maxf(absf(direction.y), 0.001))
	var edge := size * 0.5 + direction * ratio
	var color := accent
	color.a = 0.45 if disabled else 0.8
	draw_line(anchor_point, edge, color, 1.5, true)
	draw_circle(anchor_point, 2.5, color)
	draw_circle(edge, 1.5, color)


func _has_point(point: Vector2) -> bool:
	if Rect2(Vector2.ZERO, size).has_point(point):
		return true
	# Moving the plate away must not remove the model's original tap target.
	var map: Control = get_parent() as Control
	return map != null and Rect2(Vector2.ZERO, map.size).has_point(position + point) and point.distance_to(anchor_point) <= 28.0
