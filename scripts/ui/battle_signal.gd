extends Control
## A short, input-transparent holographic accent aligned to a live HUD rect.
const Motion = preload("res://scripts/ui/holographic/motion.gd")

var ink: Color
var kind: StringName
var progress := 0.0:
	set(value):
		progress = value
		queue_redraw()


static func sweep(host: Control, color: Color, seconds: float, shape: StringName = &"sweep") -> void:
	if not host.is_inside_tree() or not host.is_visible_in_tree() or Motion.duration(seconds) <= 0.0: return
	clear(host)
	var view := new()
	view.kind = shape
	view.ink = color
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(view)
	host.set_meta(&"battle_signal", weakref(view))
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Motion.Preferences.events.ui_motion_changed.connect(view._motion_changed)
	var animation := view.create_tween()
	animation.tween_property(view, "progress", 1.0, seconds)
	animation.tween_callback(view.queue_free)


static func clear(host: Control) -> void:
	if host.has_meta(&"battle_signal"):
		var view: Control = host.get_meta(&"battle_signal").get_ref()
		if is_instance_valid(view):
			view.hide()
			view.queue_free()
		host.remove_meta(&"battle_signal")


func _motion_changed(profile: int) -> void:
	if profile == 0:
		hide()
		queue_free()


func _draw() -> void:
	var strength := sin(progress * PI)
	if strength <= 0 or size.x <= 1 or size.y <= 1: return
	var tint := Color(ink, strength * 0.74)
	match kind:
		&"production":
			var badge: Control = get_parent().get_node("ProductionBadge")
			var x := badge.position.x + 4.0
			var y := lerpf(badge.position.y + badge.size.y * 0.5, size.y * 0.34, progress)
			var reach := 4.0 + 6.0 * strength
			draw_line(Vector2(x, y + reach), Vector2(x, y), Color(ink, strength * 0.49), 2.0, true)
			draw_circle(Vector2(x, y), 2.3, tint)
			var edge_y := badge.position.y + badge.size.y - 1.0
			draw_line(Vector2(x, edge_y), Vector2(badge.get_rect().end.x - 4, edge_y), tint, 1.0, true)
		&"interference":
			for i in 3:
				var y := size.y * (0.23 + 0.22 * i) + sin(progress * 14 + i * 2) * 3
				var x := size.x * (0.10 + 0.15 * i)
				draw_line(Vector2(x, y), Vector2(minf(size.x - 3, x + size.x * 0.52), y),
					Color(ink, strength * (0.23 + 0.09 * i)), 1.0, true)
		_:
			var y := clampf((1.0 - progress) * size.y, 2.0, size.y - 2.0)
			var inset := minf(size.x * 0.24, 9.0)
			draw_rect(Rect2(inset, y - 2, size.x - 2 * inset, 4), Color(ink, strength * 0.12))
			draw_line(Vector2(inset, y), Vector2(size.x - inset, y), tint, 1.0, true)
