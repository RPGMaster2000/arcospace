extends Button
# Presentation-only destination tag; the map supplies its projected anchor each frame.
const EMOJI_FONT = preload("res://assets/fonts/ArcospaceEmoji.ttf")
const ICONS = {
	"mining_operation": "⛏️", "research_station": "🔬", "quarantined_colony": "☣️",
	"gas_giant": "🪐", "trading_outpost": "🏪", "derelict_starship": "🚀",
	"pirate_debris_field": "☠️", "battle": "⚔️", "spatial_anomaly": "🌀",
	"unstable_wormhole": "🕳️", "radiation_nebula": "☢️", "distress_signal": "🆘", "unknown": "❓"
}
const FALLBACKS = {"research_station":"🛰️","quarantined_colony":"⚕️","trading_outpost":"⚖️","unstable_wormhole":"🌀","distress_signal":"📡"}

static func icon_for(kind: String) -> String:
	var glyph: String = ICONS.get(kind,ICONS.unknown)
	return glyph if EMOJI_FONT.has_char(glyph.unicode_at(0)) else FALLBACKS.get(kind,"◇")

var anchor_point := Vector2.ZERO
var icon_center := Vector2.ZERO
var planet_name: Label
var completion_badge: Control
var completed := false
var unavailable := false
var selected := false
var hovered := false
var secondary := false
var accent := Color("a6e9ff")


func style_tag(color: Color) -> void:
	accent = color.lightened(0.3)
	accent.a = 1.0
	flat = false
	# Bitmap emoji must use native advances; synthetic emboldening distorts them.
	add_theme_font_override("font", EMOJI_FONT)
	add_theme_font_size_override("font_size", 28)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.draw_center = state!="focus" # Focus overlays the normal box: no second half-alpha fill.
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
	mouse_entered.connect(func(): _set_hovered(true))
	mouse_exited.connect(func(): _set_hovered(false))
	focus_entered.connect(_refresh_state)
	focus_exited.connect(_refresh_state)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		add_theme_color_override(state, accent)
	add_theme_color_override("font_disabled_color", accent.lerp(Color.WHITE, 0.5).darkened(0.18))
	add_theme_color_override("font_outline_color", Color("020611"))
	add_theme_constant_override("outline_size", 3)


func highlighted() -> bool:
	return selected or hovered or has_focus()

func priority() -> int:
	return 3 if selected else (2 if highlighted() else (0 if completed else 1))

func set_state(is_completed: bool, blocked: bool, is_selected: bool) -> void:
	if completed==is_completed and unavailable==blocked and selected==is_selected: return
	var visual_change: bool = completed!=is_completed or selected!=is_selected
	completed = is_completed
	unavailable = blocked
	selected = is_selected
	if visual_change: _refresh_state()
	else: queue_redraw()

func set_secondary(value: bool) -> void:
	if secondary==value: return
	secondary = value
	_refresh_state()

func _set_hovered(value: bool) -> void:
	hovered = value
	_refresh_state()

func _refresh_state() -> void:
	var foreground := accent
	if completed:
		var gray: float = accent.get_luminance()
		foreground = accent.lerp(Color(gray,gray,gray),0.8).darkened(0.25)
	var emphasis := highlighted()
	self_modulate = Color(0.82,0.82,0.82,1.0) if completed and not selected else Color.WHITE
	if completion_badge != null: completion_badge.visible = completed
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box: StyleBoxFlat = get_theme_stylebox(state)
		var bright: bool = emphasis or state in ["hover","pressed","focus"]
		box.bg_color = Color(0.02,0.28,0.36,0.5) if selected else Color(foreground.r*0.12,foreground.g*0.12,foreground.b*0.12,0.5)
		box.border_color = foreground.lightened(0.18) if bright else foreground
		box.border_color.a = 0.95 if bright else (0.23 if completed else 0.65)
		if secondary and not bright: box.border_color.a *= 0.55
		if selected: box.border_color = Color("b8faff")
		box.set_border_width_all(3 if selected else (2 if bright else 1))
		box.shadow_color = Color(0.3,0.9,1.0,0.35) if selected else Color(foreground.r,foreground.g,foreground.b,0.18 if bright else 0.0)
		box.shadow_size = 6 if selected else (4 if bright else 0)
	begin_bulk_theme_override()
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		add_theme_color_override(key,foreground.lightened(0.1) if emphasis else foreground)
	end_bulk_theme_override()
	if planet_name != null: planet_name.add_theme_color_override("font_color",foreground)
	z_index = priority()*10
	queue_redraw()


func set_label(value: String, symbol: String, is_planet: bool) -> void:
	text = symbol
	if planet_name == null:
		planet_name = Label.new()
		planet_name.mouse_filter = MOUSE_FILTER_IGNORE
		planet_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		planet_name.add_theme_font_override("font",ThemeDB.fallback_font)
		planet_name.add_theme_font_size_override("font_size",18)
		planet_name.add_theme_color_override("font_outline_color",Color("020611"))
		planet_name.add_theme_constant_override("outline_size",2)
		add_child(planet_name)
		completion_badge = Control.new()
		completion_badge.mouse_filter = MOUSE_FILTER_IGNORE
		completion_badge.size = Vector2(28,28)
		completion_badge.draw.connect(_draw_completion_badge)
		add_child(completion_badge)
	planet_name.text = value if is_planet else ""
	planet_name.visible = is_planet
	planet_name.add_theme_color_override("font_color",accent)
	var width: float = ThemeDB.fallback_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+24 if is_planet else 48.0
	custom_minimum_size = Vector2(maxf(48,width),78 if is_planet else 48)
	size = custom_minimum_size
	icon_center = Vector2(size.x*0.5,(32+size.y-4)*0.5) if is_planet else size*0.5
	completion_badge.position = Vector2(size.x-4,-8)
	planet_name.position = Vector2(6,4)
	planet_name.size = Vector2(size.x-12,24)
	for state in ["normal","hover","pressed","disabled","focus"]:
		get_theme_stylebox(state).content_margin_top = 32 if is_planet else 4
	_refresh_state()


func _draw() -> void:
	if not Rect2(Vector2.ZERO,size).has_point(anchor_point):
		var direction := anchor_point - size * 0.5
		var ratio: float = minf(size.x * 0.5 / maxf(absf(direction.x), 0.001), size.y * 0.5 / maxf(absf(direction.y), 0.001))
		var edge := size * 0.5 + direction * ratio
		var color := accent
		color.a = 0.65 if highlighted() else (0.18 if completed else 0.32)
		draw_line(anchor_point,edge,color,1.25 if highlighted() else 1.0,true)
		draw_circle(anchor_point,1.8,color)
	if unavailable and not completed:
		var at := Vector2(size.x-8,size.y-9)
		draw_line(at+Vector2(-2,-3),at+Vector2(-2,3),accent,1.5,true)
		draw_line(at+Vector2(2,-3),at+Vector2(2,3),accent,1.5,true)
	if selected:
		var at := Vector2(-6,icon_center.y)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-8,0),at+Vector2(0,-8),at+Vector2(8,0),at+Vector2(0,8)]),Color("02151f"))
		draw_colored_polygon(PackedVector2Array([at+Vector2(-5,0),at+Vector2(0,-5),at+Vector2(5,0),at+Vector2(0,5)]),Color("b8faff"))

func _draw_completion_badge() -> void:
	# Geometry guarantees the completion check even without a platform check glyph.
	var center := Vector2(14,14)
	completion_badge.draw_circle(center,13,Color("021c17"))
	completion_badge.draw_circle(center,11,Color("167b59"))
	completion_badge.draw_arc(center,11,0,TAU,32,Color("78ffb3"),1.5,true)
	completion_badge.draw_line(center+Vector2(-6,0),center+Vector2(-1,5),Color("e6fff0"),3.0,true)
	completion_badge.draw_line(center+Vector2(-1,5),center+Vector2(7,-6),Color("e6fff0"),3.0,true)


func _hit_distance(point: Vector2) -> float:
	var map_parent: Control = get_parent() as Control
	if map_parent != null and map_parent.has_method("point_is_reserved") and map_parent.point_is_reserved(position+point+map_parent.global_position): return INF
	if map_parent != null and map_parent.clip_contents and not Rect2(Vector2.ZERO,map_parent.size).has_point(position+point): return INF
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
	var peers: Variant = map.get("markers")
	if not peers is Dictionary: return true
	for other in peers.values():
		if other == self or other.disabled or not other.is_visible_in_tree(): continue
		var other_distance: float = other._hit_distance(position+point-other.position)
		if other_distance<distance or (is_equal_approx(other_distance,distance) and other.get_index()>get_index()): return false
	return true
