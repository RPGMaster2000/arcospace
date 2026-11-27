extends Control
## Paints the committed EMP snapshot and its one-shot presentation transitions.
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Glyph = preload("res://scripts/ui/holographic/system_glyph.gd")

var state := ""
var ratio := 0.0
var fill := 0.0:
	set(value):
		fill = value
		queue_redraw()
var sweep := 1.0:
	set(value):
		sweep = value
		queue_redraw()
var _icon: Control
var _frame: Holo.Frame


func _ready() -> void:
	_frame = Holo.frame("status", Holo.DEFAULT.emp_color)
	_frame.details = 0
	_frame.cut = 6
	Holo.plate(self, _frame)
	$Charge.clip_text = true
	_icon = Glyph.new()
	_icon.kind = "emp"
	add_child(_icon)
	var transparent := StyleBoxEmpty.new()
	for key in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		$WarpButton.add_theme_stylebox_override(key, transparent)
	$WarpButton.add_theme_stylebox_override("focus", Holo.frame("focus", Holo.DEFAULT.emp_color))
	Motion.Preferences.events.ui_motion_changed.connect(_motion_changed)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	_icon.size = Vector2(17, 17)
	_icon.position = Vector2((size.x - _icon.size.x) * 0.5, 5)
	$Charge.position = Vector2(0, size.y - 18)
	$Charge.size = Vector2(size.x, 14)
	_fit_label()
	$WarpButton.size = size
	queue_redraw()


func present(data: Dictionary) -> void:
	var info: Dictionary = data.emp
	if data.escaped_by_ftl:
		if state == "used": return
		if data.get("emp_pending", false):
			if state != "firing":
				state = "firing"
				ratio = 1.0
				settle_display()
				$Charge.tooltip_text = "EMP Pulse firing"
				tooltip_text = $Charge.tooltip_text
				_update_ink()
		else:
			discharge()
		$WarpButton.hide()
		return
	$Charge.tooltip_text = "EMP Pulse %d / %d" % [info.charge, info.charge_target]
	var next_ratio := clampf(float(info.charge) / maxi(1, info.charge_target), 0.0, 1.0)
	var next := "charging"
	if info.disabled_turns > 0:
		next = "offline"
		$Charge.tooltip_text += " · Offline (%d turns)" % info.disabled_turns
	elif info.can_warp:
		next = "ready"
		$Charge.tooltip_text += " · Ready"
	elif next_ratio >= 0.8:
		next = "near"
	var charged: bool = info.charge >= info.charge_target
	$WarpButton.visible = charged and (data.winner.is_empty() or data.get("destruction_presenting", false))
	$WarpButton.disabled = not info.can_warp or data.current_actor != "player" or data.resolving_card or data.effects_busy or not data.winner.is_empty()
	$WarpButton.accessibility_name = "Fire EMP Pulse" if info.can_warp else $Charge.tooltip_text
	tooltip_text = $Charge.tooltip_text
	$WarpButton.tooltip_text = tooltip_text
	if state == next and is_equal_approx(ratio, next_ratio): return
	var first := state.is_empty()
	state = next
	ratio = next_ratio
	_update_ink()
	_animate(0.0 if first else (Holo.DEFAULT.emp_ready_seconds if state == "ready" else Holo.DEFAULT.meter_seconds))


func discharge() -> void:
	if state == "used": return
	state = "used"
	ratio = 0.0
	$WarpButton.hide()
	$Charge.tooltip_text = "EMP Pulse discharged"
	tooltip_text = $Charge.tooltip_text
	_update_ink()
	_animate(Holo.DEFAULT.emp_discharge_seconds)


func _update_ink() -> void:
	var tint := _tint()
	$Charge.text = {"ready": "RDY", "offline": "OFF", "firing": "FIRE", "used": "USED"}.get(state, "EMP")
	_fit_label()
	$Charge.accessibility_name = $Charge.tooltip_text
	$Charge.add_theme_color_override("font_color", tint.lightened(0.16))
	_icon.ink = tint
	_frame.border_color = Color(tint, 0.82 if state == "ready" else 0.51)
	queue_redraw()


func _fit_label() -> void:
	var label: Label = $Charge
	var font := label.get_theme_font("font")
	var font_size := 10
	while font_size > 6 and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 2:
		font_size -= 1
	label.add_theme_font_size_override("font_size", font_size)


func _animate(seconds: float) -> void:
	seconds = Motion.duration(seconds, state in ["ready", "used"])
	if seconds <= 0.0 or not is_visible_in_tree():
		settle_display()
		return
	sweep = 0.0 if state in ["ready", "used"] else 1.0
	var tween := Motion.start(self, &"charge").set_parallel()
	tween.tween_property(self, "fill", ratio, seconds)
	if sweep == 0.0:
		tween.tween_property(self, "sweep", 1.0, seconds).set_trans(Tween.TRANS_LINEAR)


func settle_display() -> void:
	Motion.stop(self, &"charge")
	fill = ratio
	sweep = 1.0


func _motion_changed(profile: int) -> void:
	if profile == 0: settle_display()


func _tint() -> Color:
	if state == "offline": return Holo.DEFAULT.muted
	if state in ["near", "ready", "firing", "used"]: return Holo.DEFAULT.emp_bright
	return Holo.DEFAULT.emp_color


func _draw() -> void:
	var skin := Holo.DEFAULT
	var top := 25.0
	var bottom := size.y - 18.0
	if bottom <= top: return
	var width: float = skin.emp_thickness
	var left := (size.x - width) * 0.5
	var length := bottom - top
	var tint := _tint()
	draw_rect(Rect2(left - 1, top - 1, width + 2, length + 2), Color(tint, 0.24), false)
	draw_rect(Rect2(left, top, width, length), Color(tint, 0.13))
	var lit := length * fill
	if lit > 0.0:
		draw_rect(Rect2(left, bottom - lit, width, lit), Color(tint, 0.34 if state == "offline" else 0.93))
		draw_line(Vector2(left, bottom - lit), Vector2(left + width, bottom - lit), tint.lightened(0.45))
	if sweep < 1.0:
		var wave_y := lerpf(top, bottom, sweep) if state == "used" else lerpf(bottom, top, sweep)
		var energy := sin(sweep * PI) * skin.emp_glow
		draw_rect(Rect2(left - 5, wave_y - 3, width + 10, 6), Color(skin.emp_bright, energy * 0.48))
		draw_rect(Rect2(left - 2, wave_y - 1, width + 4, 2), Color(Color.WHITE, energy))
