extends Button

const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Meter = preload("res://scripts/ui/holographic/segmented_meter.gd")
const Holo = preload("res://scripts/ui/holographic/skin.gd")
# Presentation-only destination tag; the map supplies its projected anchor each frame.
const EMOJI_FONT = preload("res://assets/fonts/ArcospaceEmoji.ttf")
const ICONS = {
	"mining_operation": "⛏️", "research_station": "🔬", "quarantined_colony": "☣️",
	"fuel_depot":"🏪", "sensor_relay":"🔬", "ancient_navigation_array":"🌀", "raider_cache":"☠️",
	"gas_giant": "🪐", "trading_outpost": "🏪", "derelict_starship": "🚀",
	"pirate_debris_field": "☠️", "battle": "⚔️", "spatial_anomaly": "🌀",
	"unstable_wormhole": "🕳️", "radiation_nebula": "☢️", "distress_signal": "🆘", "unknown": "❓"
}
const FALLBACKS = {"research_station":"🛰️","quarantined_colony":"⚕️","trading_outpost":"⚖️","unstable_wormhole":"🌀","distress_signal":"📡"}

static func icon_for(kind: String) -> String:
	var glyph: String = ICONS.get(kind,ICONS.unknown)
	return glyph if EMOJI_FONT.has_char(glyph.unicode_at(0)) else FALLBACKS.get(kind,"◇")

var hit_allowed: Callable
var nearest_hit: Callable
var objective_badge: Label
var objective_value := ""
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
var contrast: bool = false
var lattice_tag := false
var lattice_show_name := false
var lattice_name_occluded := false
var recharge_ratio := -1.0
var warzone_importance := 0 # 0 ordinary, 1 strategic command/chokepoint, 2 active final objective
var warzone_consolidation := -1.0
var capture_ratio := 0.0
var capture_tint := Color.WHITE
var in_clash := false
var fleet_strength := -1.0
var forecast: Dictionary = {}
var _pulse := 0.0


func set_warzone_readout(progress: float, tint: Color, clash: bool, strength: float = -1.0) -> void:
	capture_ratio = progress
	capture_tint = tint
	in_clash = clash
	fleet_strength = strength
	set_process(clash or warzone_importance == 2)
	queue_redraw()


func set_integrity(value: int, maximum: int) -> void:
	var ratio := clampf(float(value) / maxi(1, maximum), 0, 1)
	if is_equal_approx(fleet_strength, ratio): return
	fleet_strength = ratio
	queue_redraw()


func set_warzone_importance(tier: int, consolidation: float = -1.0) -> void:
	var next_tier := clampi(tier, 0, 2)
	var next_progress := clampf(consolidation, 0.0, 1.0) if consolidation >= 0.0 else -1.0
	if warzone_importance == next_tier and is_equal_approx(warzone_consolidation, next_progress): return
	var tier_changed := warzone_importance != next_tier
	warzone_importance = next_tier
	warzone_consolidation = next_progress
	set_process(in_clash or warzone_importance == 2)
	if tier_changed: _refresh_state()
	else: queue_redraw()


func set_recharge(value: float) -> void:
	if is_equal_approx(recharge_ratio, value): return
	recharge_ratio = value
	queue_redraw()


func set_forecast(value: Dictionary) -> void:
	if forecast == value: return
	forecast = value
	queue_redraw()


func _process(delta: float) -> void:
	if not (in_clash or warzone_importance == 2) or not is_visible_in_tree():
		return
	if Preferences.ui_motion() == 0:
		if _pulse != 0.0:
			_pulse = 0.0
			queue_redraw()
		return
	_pulse = fmod(_pulse + delta * 3.8, TAU)
	queue_redraw()


func style_tag(color: Color) -> void:
	set_process(false)
	accent = color.lightened(0.3)
	accent.a = 1.0
	flat = false
	# Bitmap emoji must use native advances; synthetic emboldening distorts them.
	add_theme_font_override("font", EMOJI_FONT)
	add_theme_font_size_override("font_size", 22 if lattice_tag else 28)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := Holo.frame("focus" if state == "focus" else "marker", accent, state)
		box.draw_center = state!="focus" # Focus overlays the normal box: no second half-alpha fill.
		box.bg_color = Color(accent.r*0.12,accent.g*0.12,accent.b*0.12,0.5)
		box.border_color = accent * Color(1, 1, 1, 0.65)
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
	return 3 if selected else (2 if highlighted() or warzone_importance == 2 else (0 if completed else 1))

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
	if hovered == value: return
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
	if objective_badge != null: objective_badge.visible = not objective_value.is_empty() and not completed
	for state in ["normal","hover","pressed","disabled","focus"]:
		var box: Holo.Frame = get_theme_stylebox(state)
		var bright: bool = emphasis or state in ["hover","pressed","focus"]
		box.bg_color = Color(0.02,0.28,0.36,0.85 if contrast else 0.5) if selected else Color(foreground.r*0.12,foreground.g*0.12,foreground.b*0.12,0.85 if contrast else 0.5)
		box.border_color = foreground.lightened(0.18) if bright else foreground
		box.border_color.a = 0.95 if bright else (0.23 if completed else 0.65)
		if secondary and not bright: box.border_color.a *= 0.55
		if lattice_tag and warzone_importance > 0 and not selected:
			box.border_color = Color("ffe4a2") if warzone_importance == 2 else Color("d4aa66")
			box.border_color.a = 0.97 if warzone_importance == 2 else 0.82
		if selected: box.border_color = Color("b8faff")
		box.border_width_top = 3 if selected or (lattice_tag and warzone_importance == 2) else (2 if bright or (lattice_tag and warzone_importance == 1) else 1)
		box.shadow_color = Color(0.3,0.9,1.0,0.35) if selected else Color(foreground.r,foreground.g,foreground.b,0.18 if bright else 0.0)
		box.shadow_size = 6 if selected else (4 if bright else 0)
	begin_bulk_theme_override()
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color"]:
		add_theme_color_override(key,foreground.lightened(0.1) if emphasis else foreground)
	end_bulk_theme_override()
	if planet_name != null:
		planet_name.add_theme_color_override("font_color", Color("ffe4a2") if lattice_tag and warzone_importance == 2 else (Color.WHITE if contrast else foreground))
		if lattice_tag:
			planet_name.visible = not planet_name.text.is_empty() and (emphasis or (lattice_show_name and not lattice_name_occluded))
	z_index = priority()*10
	queue_redraw()


func set_label(value: String, symbol: String, is_planet: bool) -> void:
	text = symbol
	if planet_name == null:
		planet_name = Label.new()
		planet_name.mouse_filter = MOUSE_FILTER_IGNORE
		planet_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		planet_name.add_theme_font_override("font",ThemeDB.fallback_font)
		planet_name.add_theme_font_size_override("font_size", 14 if lattice_tag else 18)
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
	planet_name.add_theme_color_override("font_color", Color.WHITE if contrast else accent)
	var width: float = ThemeDB.fallback_font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x+24 if is_planet else 48.0
	custom_minimum_size = Vector2(44, 44) if lattice_tag else Vector2(maxf(48,width),78 if is_planet else 48)
	size = custom_minimum_size
	icon_center = Vector2(size.x*0.5,(32+size.y-4)*0.5) if is_planet and not lattice_tag else size*0.5
	completion_badge.position = Vector2(size.x-4,-8)
	if lattice_tag:
		var name_width := planet_name.get_minimum_size().x
		planet_name.position = Vector2((size.x - name_width) * 0.5, -20)
		planet_name.size = Vector2(name_width, 20)
	else:
		planet_name.position = Vector2(6,4)
		planet_name.size = Vector2(size.x-12,24)
	for state in ["normal","hover","pressed","disabled","focus"]:
		get_theme_stylebox(state).content_margin_top = 32 if is_planet and not lattice_tag else 4
	_refresh_state()


func set_lattice_name_visible(value: bool) -> void:
	if lattice_show_name == value: return
	lattice_show_name = value
	_refresh_state()



func set_lattice_name_occluded(value: bool) -> void:
	if lattice_name_occluded == value: return
	lattice_name_occluded = value
	planet_name.visible = not planet_name.text.is_empty() and (highlighted() or (lattice_show_name and not value))

func _draw() -> void:
	if lattice_tag:
		var ring := minf(size.x, size.y) * 0.5 - 4.0
		if warzone_importance == 1:
			var strategic_tint := Color("d4aa66")
			for segment in 4:
				var start := float(segment) * TAU / 4.0 + 0.10
				draw_arc(icon_center, ring + 1.0, start, start + 0.60, 8, strategic_tint, 1.8, true)
		elif warzone_importance == 2:
			var alpha := 0.73 + 0.21 * sin(_pulse)
			draw_arc(icon_center, ring + 2.0, 0, TAU, 40, Color(Color("ffe4a2"), alpha), 2.7, true)
			if warzone_consolidation >= 0.0:
				draw_arc(icon_center, ring + 2.0, -PI / 2, -PI / 2 + TAU * warzone_consolidation,
					40, Color("fff5d5"), 3.5, true)
		if recharge_ratio >= 0.0:
			draw_arc(icon_center, ring - 4.0, 0, TAU, 24, Color("20364b"), 2.0, true)
			if recharge_ratio > 0.0:
				draw_arc(icon_center, ring - 4.0, -PI / 2, -PI / 2 + TAU * recharge_ratio, 24, Color("b4d8e6"), 2.0, true)
		if in_clash:
			draw_arc(icon_center, ring, 0, TAU, 24, Color(capture_tint, 0.5 + sin(_pulse) * 0.19), 2.0, true)
		elif capture_ratio > 0:
			draw_arc(icon_center, ring, -PI / 2, -PI / 2 + TAU * capture_ratio, 28, capture_tint, 2.5, true)
	if fleet_strength >= 0.0:
		var extent := Vector2(size.x - 16.0, 3.0)
		var origin := Vector2(8.0, size.y - 7.0)
		var cells := 6 if lattice_tag else Holo.DEFAULT.segments
		Meter.draw_cells(self, extent, 0.0, extent.x, Color("25394c"), cells, false, origin)
		Meter.draw_cells(self, extent, 0.0, extent.x * fleet_strength, accent, cells, false, origin)
	if not forecast.is_empty():
		var plate := Rect2(Vector2(1, size.y - 16), Vector2(size.x - 2, 15))
		draw_rect(plate, Color("101a28"))
		var strip := Rect2(plate.position + Vector2(2, 1), Vector2(plate.size.x - 4, 3))
		draw_rect(strip, Color("ff817c"))
		strip.size.x *= forecast.allied_share
		draw_rect(strip, Color("65dee9"))
		var eta := "~%ds" % forecast.seconds
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(eta, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		draw_string(font, Vector2((size.x - width) * 0.5, size.y - 2), eta, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
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


# Effective targets expand the touch area without expanding the drawn icon.
func hit_distance(point: Vector2) -> float:
	var distance: float = INF
	if Rect2(Vector2.ZERO,size).has_point(point) or point.distance_to(icon_center) <= 36.0:
		distance = point.distance_to(icon_center)
	if point.distance_to(anchor_point) <= 36.0:
		distance = minf(distance,point.distance_to(anchor_point))
	return distance


func _has_point(point: Vector2) -> bool:
	var global: Vector2 = global_position+point
	if hit_allowed.is_valid() and not hit_allowed.call(global): return false
	if hit_distance(point) == INF: return false
	return not nearest_hit.is_valid() or nearest_hit.call(global)


func set_objective(value: String) -> void:
	if objective_badge == null:
		objective_badge = Label.new()
		objective_badge.mouse_filter = MOUSE_FILTER_IGNORE
		objective_badge.add_theme_font_override("font",preload("res://assets/fonts/emoji_ui.tres"))
		objective_badge.add_theme_font_size_override("font_size",14 if lattice_tag else 23)
		objective_badge.add_theme_color_override("font_color",Color("ffe39a"))
		objective_badge.add_theme_color_override("font_outline_color",Color("020611"))
		objective_badge.add_theme_constant_override("outline_size",4)
		objective_badge.size = Vector2(28,28)
		objective_badge.draw.connect(_draw_objective)
		add_child(objective_badge)
	objective_value = value
	objective_badge.text = "" if value == "🔒" else value
	objective_badge.queue_redraw()
	objective_badge.visible = not value.is_empty() and not completed
	objective_badge.position = Vector2(size.x-12, -9 if lattice_tag else -12)


func _draw_objective() -> void:
	if objective_value != "🔒": return
	var tint := Color("ffe39a")
	objective_badge.draw_rect(Rect2(5,12,18,14),Color("142330"))
	objective_badge.draw_rect(Rect2(5,12,18,14),tint,false,2)
	objective_badge.draw_arc(Vector2(14,12),6,PI,TAU,16,tint,2,true)
	objective_badge.draw_line(Vector2(14,17),Vector2(14,22),tint,2,true)
