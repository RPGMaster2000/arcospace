extends RefCounted
## Owns cosmetic Tweens by target/channel so repeated inputs replace them.
const ThemeSkin = preload("res://scripts/ui/holographic/skin.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")


static func duration(seconds: float, decorative: bool = false) -> float:
	match Preferences.ui_motion():
		0: return 0.0
		2: return seconds * (1.22 if decorative else 1.0)
		_: return seconds


static func stop(target: Node, channel: StringName) -> void:
	var key := StringName("holo_" + String(channel))
	var old: Tween = target.get_meta(key) if target.has_meta(key) else null
	if old != null: old.kill()
	if target.has_meta(key): target.remove_meta(key)


static func start(target: Node, channel: StringName) -> Tween:
	stop(target, channel)
	var key := StringName("holo_" + String(channel))
	var tween := target.create_tween().set_trans(ThemeSkin.DEFAULT.transition).set_ease(ThemeSkin.DEFAULT.easing)
	target.set_meta(key, tween)
	tween.finished.connect(func(): target.remove_meta(key))
	return tween


static func restore_panel(target: Control) -> void:
	stop(target, &"panel")
	target.modulate.a = 1.0


static func reveal(target: Control, seconds: float = -1.0) -> void:
	restore_panel(target)
	var time := duration(ThemeSkin.DEFAULT.panel_seconds if seconds < 0.0 else seconds, true)
	if time <= 0.0 or not target.is_inside_tree(): return
	target.modulate.a = 0.48
	start(target, &"panel").tween_property(target, "modulate:a", 1.0, time)


static func bind_button(button: Button) -> void:
	if button.has_meta("holo_response"): return
	button.set_meta("holo_response", true)
	var flare := Panel.new()
	flare.name = "HolographicResponse"
	flare.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flare.self_modulate.a = 0.0
	flare.add_theme_stylebox_override("panel", ThemeSkin.frame("focus"))
	button.add_child(flare, false, Node.INTERNAL_MODE_FRONT)
	flare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.mouse_entered.connect(_respond.bind(button, flare, 0.45, ThemeSkin.DEFAULT.hover_seconds))
	button.mouse_exited.connect(_respond.bind(button, flare, 0.0, ThemeSkin.DEFAULT.hover_seconds))
	button.button_down.connect(_respond.bind(button, flare, 0.92, ThemeSkin.DEFAULT.press_seconds))
	button.button_up.connect(_respond.bind(button, flare, 0.0, ThemeSkin.DEFAULT.selection_seconds))
	button.visibility_changed.connect(func():
		if not button.is_visible_in_tree():
			stop(flare, &"response")
			flare.self_modulate.a = 0.0)


static func _respond(button: Button, flare: Panel, value: float, seconds: float) -> void:
	stop(flare, &"response")
	if button.disabled or duration(seconds) <= 0.0 or not button.is_visible_in_tree():
		flare.self_modulate.a = 0.0
		return
	start(flare, &"response").tween_property(flare, "self_modulate:a", value, seconds)
