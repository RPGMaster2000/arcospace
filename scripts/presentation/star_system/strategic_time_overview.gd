extends CanvasLayer
## Presents a committed strategic activity. Only the activity advances game state.
signal finished

const Framing = preload("res://scripts/presentation/star_system/strategic_activity_framing.gd")
const Activity = preload("res://scripts/expedition/strategic_activity.gd")
var active := false
var activity: Activity
var progress: ProgressBar
var caption: Label
var _clock := 0.0
var _last_usec := 0
var _settle: Callable
var _map: Control
var _screen: Control
var _restore := {}
var _return_motion: Tween
var _framing := Framing.new()
var _timer_panel: PanelContainer


func _ready() -> void:
	layer = 204
	var layout := CenterContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	layout.offset_top = 74
	layout.offset_bottom = 129
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layout)
	var panel := PanelContainer.new()
	_timer_panel = panel
	var presentation = preload("res://scripts/ui/encounter_presentation.gd")
	panel.add_theme_stylebox_override("panel", presentation.style(presentation.COLORS.special))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 16)
	column.add_child(caption)
	progress = preload("res://scripts/ui/warzone_indicators.gd").bar(Color("69b6f5"), 7)
	progress.custom_minimum_size.x = 226
	column.add_child(progress)
	hide()
	set_process(false)


func begin(span: Activity, settle: Callable, map: Control, screen: Control) -> void:
	active = true
	activity = span
	_settle = settle
	_map = map
	_screen = screen
	_clock = 0.0
	var camera = map.camera
	_restore = {"camera": camera.transform, "view": camera.viewing, "pan": camera.pan_offset,
		"zoom": camera.zoom_scale, "zoom_target": camera.zoom_target, "calibration": camera.calibration,
		"focused": map.focused, "interactive": map.interactive, "focus_orbit": map.focus_orbit_enabled,
		"ui": screen.ui.visible, "backing": screen.focus_backing.visible, "return": screen.return_button.visible,
		"hud": screen.overview_hud.mode}
	map._end_pinch()
	map.focused = false
	map.strategic_time_active = true
	map.interactive = false
	map.focus_orbit_enabled = false
	map.orbit_velocity = Vector2.ZERO
	screen.ui.hide()
	screen.focus_backing.hide()
	screen.return_button.hide()
	screen.overview_hud.set_mode(screen.EdgeHUD.Mode.OVERVIEW)
	screen._sync_map_rect()
	camera.viewing = &"strategic_time"
	progress.max_value = span.duration
	_update_progress()
	show()
	_framing.begin(map, framing_bounds())
	rebase_clock()
	set_process(true)


func rebase_clock() -> void:
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var seconds := (now - _last_usec) / 1000000.0
	_last_usec = now
	advance(seconds)


func advance(seconds: float) -> void:
	if activity == null:
		return
	_clock += maxf(0.0, seconds)
	var done := activity.advance_to(_clock)
	var fraction := clampf((_clock - activity.elapsed) / Activity.STEP, 0.0, 1.0)
	_map.blend_strategic_defense(fraction)
	_update_progress()
	if not done: _framing.update(_map, framing_bounds, seconds)
	if done:
		_commit()
		_return_camera()


# Use a clear band between the timer and edge controls. Transform to normalized
# map coordinates, leaving room for fleet tags and beam impacts.
func framing_bounds() -> Rect2:
	var rect: Rect2 = _map.get_global_rect()
	var height := maxf(1.0, rect.size.y)
	var top := maxf(136.0, _timer_panel.get_global_rect().end.y + 10.0 - rect.position.y) / height
	var bottom := 0.88
	for region in _screen.overview_hud.regions():
		if region.get_center().y < rect.get_center().y:
			top = maxf(top, (region.end.y + 8.0 - rect.position.y) / height)
		else:
			bottom = minf(bottom, (region.position.y - 8.0 - rect.position.y) / height)
	top = clampf(top, 0.12, 0.34)
	bottom = clampf(bottom, top + 0.34, 0.92)
	return Rect2(0.09, top, 0.82, bottom - top)


func _update_progress() -> void:
	progress.value = activity.elapsed
	var elapsed := floorf(activity.elapsed * 10.0 + 0.000001) / 10.0
	caption.text = "STRATEGIC TIME  %s / %s s" % [str(elapsed), str(snappedf(activity.duration, 0.001))]
	progress.accessibility_name = caption.text


func _commit() -> void:
	set_process(false)
	activity = null
	if is_instance_valid(_map): _map.finish_strategic_time()
	var settle := _settle
	_settle = Callable()
	settle.call()


func _return_camera() -> void:
	_return_motion = create_tween().set_ignore_time_scale(true)
	_return_motion.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_return_motion.tween_property(_map.camera, "transform", _restore.camera, _map.settings.camera_duration)
	_return_motion.tween_callback(_restore_view)


# An interrupted app may be killed before it resumes. Settle the confirmed span
# before writing a checkpoint, including its continuation, without a second charge.
func finish_immediately() -> void:
	if not active: return
	if activity != null:
		activity.advance_to(activity.duration)
		_commit()
	if _return_motion != null and _return_motion.is_valid():
		_return_motion.kill()
	_restore_view()


func _restore_view() -> void:
	if is_instance_valid(_map) and is_instance_valid(_screen):
		var camera = _map.camera
		camera.transform = _restore.camera
		camera.viewing = _restore.view
		camera.pan_offset = _restore.pan
		camera.zoom_scale = _restore.zoom
		camera.zoom_target = _restore.zoom_target
		camera.calibration = _restore.calibration
		_map.focused = _restore.focused
		_map.interactive = _restore.interactive
		_map.focus_orbit_enabled = _restore.focus_orbit
		_map.keep_activity_focus = _restore.focused
		_screen.ui.visible = _restore.ui
		_screen.focus_backing.visible = _restore.backing
		_screen.return_button.visible = _restore["return"]
		_screen.overview_hud.set_mode(_restore.hud)
		_screen._sync_map_rect()
	_restore.clear()
	active = false
	hide()
	finished.emit()


func _input(_event: InputEvent) -> void:
	if active: get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	# Explicit save and lifecycle handlers settle before leaving. Teardown itself
	# cannot publish a half-finished activity or access detached UI nodes.
	activity = null
	_settle = Callable()
