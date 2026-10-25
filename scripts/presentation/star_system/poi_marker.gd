extends Button
# Presentation-only destination tag; the map supplies its projected anchor each frame.
var anchor_point := Vector2.ZERO
var icon_center := Vector2.ZERO
var planet_name: Label
var accent := Color("a6e9ff")


func style_tag(color: Color) -> void:
	accent = color.lightened(0.3)
	accent.a = 1.0
	flat = false
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.fallbacks = [preload("res://assets/fonts/emoji_ui.tres")]
	font.variation_embolden = 1.0
	add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(accent.r*0.12,accent.g*0.12,accent.b*0.12,0.5)
		box.border_color = accent * Color(1, 1, 1, 0.65)
		box.set_border_width_all(1)
		box.set_corner_radius_all(10)
		box.content_margin_left = 7
		box.content_margin_right = 7
		box.content_margin_top = 4
		box.content_margin_bottom = 4
		if state in ["hover", "focus", "pressed"]:
			box.bg_color = Color(accent.r*0.22,accent.g*0.22,accent.b*0.22,0.5)
			box.border_color = accent
		if state == "disabled":
			box.border_color.a = 0.35
		add_theme_stylebox_override(state, box)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, accent)
	add_theme_color_override("font_disabled_color", accent.lerp(Color.WHITE, 0.5).darkened(0.18))
	add_theme_color_override("font_outline_color", Color("020611"))
	add_theme_constant_override("outline_size", 2)


func set_label(value: String, symbol: String, is_planet: bool) -> void:
	text = symbol
	if planet_name == null:
		planet_name = Label.new()
		planet_name.mouse_filter = MOUSE_FILTER_IGNORE
		planet_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		planet_name.add_theme_font_size_override("font_size",14)
		planet_name.add_theme_color_override("font_outline_color",Color("020611"))
		planet_name.add_theme_constant_override("outline_size",2)
		add_child(planet_name)
	planet_name.text = value if is_planet else ""
	planet_name.visible = is_planet
	planet_name.add_theme_color_override("font_color",accent)
	var width: float = get_theme_font("font").get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+18 if is_planet else 48.0
	custom_minimum_size = Vector2(maxf(48,width),72 if is_planet else 48)
	size = custom_minimum_size
	icon_center = Vector2(size.x*0.5,(26+size.y-4)*0.5) if is_planet else size*0.5
	planet_name.position = Vector2(6,4)
	planet_name.size = Vector2(size.x-12,20)
	for state in ["normal","hover","pressed","disabled","focus"]:
		get_theme_stylebox(state).content_margin_top = 26 if is_planet else 4


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


func _hit_distance(point: Vector2) -> float:
	var distance := INF
	if Rect2(Vector2.ZERO,size).has_point(point): distance = point.distance_to(icon_center)
	var map: Control = get_parent() as Control
	if map != null and Rect2(Vector2.ZERO,map.size).has_point(position+point) and point.distance_to(anchor_point)<=28.0:
		distance = minf(distance,point.distance_to(anchor_point))
	return distance

func _has_point(point: Vector2) -> bool:
	var distance: float = _hit_distance(point)
	if distance == INF: return false
	# Anchored tags may overlap. Give the nearest icon/model one unambiguous tap.
	var map: Control = get_parent() as Control
	if map == null: return true
	for other in map.get("markers").values():
		if other == self or other.disabled or not other.is_visible_in_tree(): continue
		var other_distance: float = other._hit_distance(position+point-other.position)
		if other_distance<distance or (is_equal_approx(other_distance,distance) and other.get_index()>get_index()): return false
	return true
