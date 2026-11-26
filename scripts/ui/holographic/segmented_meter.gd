@tool
extends Control
## Observes a native ProgressBar. Its value, range, and accessibility remain
## authoritative on the original control. Geometry does not receive input.
const ThemeSkin = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")

var skin: ThemeSkin.Settings = ThemeSkin.DEFAULT
var gauge: ProgressBar
var tint := Color.CYAN
var track := Color("25394c")
var display_ratio := 0.0:
	set(value):
		display_ratio = value
		queue_redraw()
var target_ratio := 0.0
var animate := true


static func attach(bar: ProgressBar, accent: Color, background := Color("25394c"), animated := true,
		configuration: ThemeSkin.Settings = ThemeSkin.DEFAULT) -> Control:
	var view := new()
	view.skin = configuration
	view.gauge = bar
	view.tint = accent
	view.track = background
	view.animate = animated
	view.target_ratio = bar.ratio
	view.display_ratio = bar.ratio
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	bar.add_theme_stylebox_override("fill", StyleBoxEmpty.new())
	bar.add_child(view, false, Node.INTERNAL_MODE_FRONT)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.value_changed.connect(view._update)
	bar.changed.connect(func(): view._update(bar.value))
	Motion.Preferences.events.ui_motion_changed.connect(view._motion_changed)
	return view


func set_tint(color: Color) -> void:
	if color == tint: return
	tint = color
	queue_redraw()


func _update(_value: float) -> void:
	if is_equal_approx(target_ratio, gauge.ratio): return
	target_ratio = gauge.ratio
	var seconds := Motion.duration(skin.meter_seconds)
	if animate and seconds > 0 and is_visible_in_tree():
		Motion.start(self, &"meter").tween_property(self, "display_ratio", target_ratio, seconds)
	else:
		Motion.stop(self, &"meter")
		display_ratio = target_ratio



func _motion_changed(profile: int) -> void:
	if profile != 0: return
	Motion.stop(self, &"meter")
	display_ratio = target_ratio


func _draw() -> void:
	if skin.meter_track != null:
		draw_texture_rect(skin.meter_track, Rect2(Vector2.ZERO, size), false, track.lightened(0.6))
	else:
		draw_cells(self, size, 0.0, size.x, track, skin.segments)
	if skin.meter_fill != null:
		# Crop the destination and corresponding source together so fill art
		# remains fixed while a value rises or falls.
		var width := clampf(display_ratio, 0, 1)
		if width > 0.0:
			var source := Vector2(skin.meter_fill.get_size())
			draw_texture_rect_region(skin.meter_fill, Rect2(0, 0, size.x * width, size.y),
				Rect2(0, 0, source.x * width, source.y), tint)
	else:
		draw_cells(self, size, 0.0, size.x * clampf(display_ratio, 0, 1), tint, skin.segments, true)


static func draw_cells(view: Control, extent: Vector2, start: float, end: float, color: Color,
		segments: int = ThemeSkin.DEFAULT.segments, lit: bool = false, origin := Vector2.ZERO) -> void:
	if end <= start or extent.x <= 0 or extent.y <= 0: return
	var pitch := extent.x / maxi(1, segments)
	var gutter := minf(2.0, pitch * 0.22)
	for index in segments:
		var left := maxf(start, index * pitch)
		var right := minf(end, (index + 1) * pitch - gutter)
		if right <= left: continue
		view.draw_rect(Rect2(origin + Vector2(left, 0), Vector2(right - left, extent.y)), color)
		if lit and extent.y >= 4.0:
			view.draw_line(origin + Vector2(left, 0.5), origin + Vector2(right, 0.5), color.lightened(0.4), 1.0)
