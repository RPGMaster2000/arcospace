extends Control
## Draws accrued protection in five-point cells, without a reserve track.
const ThemeSkin = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const POINTS_PER_SEGMENT := 5.0
const CELL_WIDTH := 9.0
const GAP := 2.0
const MULTIPLIER_SIZE := 12
const ACCENT := Color("#249aff")
const HIGHLIGHT := Color("#7beeff")

var points := -1
var disabled := false
var displayed_points := 0.0:
	set(value):
		displayed_points = value
		queue_redraw()
var _readout: Label
var _surge := 0.0:
	set(value):
		_surge = value
		queue_redraw()


func _init(readout: Label) -> void:
	_readout = readout
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	Motion.Preferences.events.ui_motion_changed.connect(_motion_changed)


func update_shields(amount: int, offline: bool) -> void:
	if amount == points and offline == disabled: return
	var animate := points >= 0 and not offline and not disabled and is_visible_in_tree()
	var restoring := amount > points
	points = amount
	disabled = offline
	_readout.text = "Shields OFF" if disabled else "Shields %d" % points
	_readout.tooltip_text = "Shield systems disabled" if disabled else (
		"No active Shields" if points == 0 else "%d Shields · 5 points per segment" % points)
	_readout.accessibility_name = _readout.text
	_readout.add_theme_color_override("font_color", ThemeSkin.DEFAULT.muted if disabled else ThemeSkin.DEFAULT.shield)
	var seconds := Motion.duration(ThemeSkin.DEFAULT.meter_seconds)
	if animate and seconds > 0.0:
		# Commit the exact readout immediately. Ease the emphasis and the stack
		# from their current painted values when a new event interrupts the tween.
		_readout.self_modulate.a = minf(_readout.self_modulate.a, 0.75)
		var tween := Motion.start(self, &"shields").set_parallel()
		tween.tween_property(self, "displayed_points", float(points), seconds)
		tween.tween_property(_readout, "self_modulate:a", 1.0, seconds)
		_surge = 0.78 if restoring else 0.47
		tween.tween_property(self, "_surge", 0.0, seconds)
	else:
		settle_display()


func _motion_changed(profile: int) -> void:
	if profile == 0: settle_display()


func settle_display() -> void:
	Motion.stop(self, &"shields")
	_surge = 0.0
	displayed_points = 0.0 if disabled else float(maxi(0, points))
	_readout.self_modulate.a = 1.0


func strip_layout(value: float) -> Dictionary:
	var units := maxf(0.0, value) / POINTS_PER_SEGMENT
	var full := floori(units)
	var partial := units - full
	var cells := full + int(partial > 0.0)
	var width := maxf(0.0, cells * (CELL_WIDTH + GAP) - GAP)
	if width <= size.x or full == 0:
		return {"full": full, "partial": partial, "multiplier": "", "width": width}
	var multiplier := "×%d" % full
	var text_width := ThemeSkin.DEFAULT.font.get_string_size(multiplier, HORIZONTAL_ALIGNMENT_LEFT, -1, MULTIPLIER_SIZE).x
	return {"full": 1, "partial": partial, "multiplier": multiplier,
		"width": CELL_WIDTH + GAP + text_width + (GAP + CELL_WIDTH if partial > 0.0 else 0.0)}


func _draw() -> void:
	if displayed_points <= 0.0 or size.x <= 0.0 or size.y <= 0.0: return
	var strip := strip_layout(displayed_points)
	var x := maxf(0.0, (size.x - float(strip.width)) * 0.5)
	var height := minf(size.y, 10.0)
	var y := (size.y - height) * 0.5
	for segment in int(strip.full):
		_draw_cell(Vector2(x, y), height, 1.0)
		x += CELL_WIDTH + GAP
	if not strip.multiplier.is_empty():
		var font := ThemeSkin.DEFAULT.font
		var baseline := (size.y - font.get_height(MULTIPLIER_SIZE)) * 0.5 + font.get_ascent(MULTIPLIER_SIZE)
		draw_string(font, Vector2(x, baseline), strip.multiplier, HORIZONTAL_ALIGNMENT_LEFT, -1, MULTIPLIER_SIZE, HIGHLIGHT)
		x += font.get_string_size(strip.multiplier, HORIZONTAL_ALIGNMENT_LEFT, -1, MULTIPLIER_SIZE).x + GAP
	if strip.partial > 0.0:
		_draw_cell(Vector2(x, y), height, strip.partial)


func _draw_cell(origin: Vector2, height: float, fraction: float) -> void:
	var area := Rect2(origin, Vector2(CELL_WIDTH * fraction, height))
	var texture: Texture2D = ThemeSkin.DEFAULT.meter_fill
	if texture != null:
		draw_texture_rect_region(texture, area, Rect2(Vector2.ZERO, Vector2(texture.get_width() * fraction, texture.get_height())), ACCENT)
		return
	draw_rect(area, ACCENT.lerp(HIGHLIGHT, _surge * 0.43))
	draw_rect(Rect2(area.position, Vector2(area.size.x, 1.0 + _surge)), HIGHLIGHT.lerp(Color.WHITE, _surge * 0.46))
