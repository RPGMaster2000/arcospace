extends CanvasLayer
## Modal capture controls over the current map. This view owns no strategic time.

signal cancel_requested

const Style = preload("res://scripts/ui/encounter_presentation.gd")
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Icons = preload("res://scripts/ui/warzone_indicators.gd")

var blocker: Control
var caption: Label
var progress: ProgressBar
var cancel_button: Button
var notice_label: Label
var notice_frame: Panel
var notice_kind := ""
var notice_timer: Tween


func _ready() -> void:
	layer = 204
	blocker = Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)
	var anchor := CenterContainer.new()
	anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	anchor.offset_top = 70
	blocker.add_child(anchor)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Style.style(Style.COLORS.special))
	anchor.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	caption = Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	progress = Icons.bar(Icons.ALLIED, 8)
	progress.custom_minimum_size.x = 230
	column.add_child(progress)
	cancel_button = Button.new()
	cancel_button.name = "CancelCaptureHold"
	cancel_button.text = "Cancel Hold"
	cancel_button.custom_minimum_size.y = 48
	Style.action(cancel_button)
	column.add_child(cancel_button)
	cancel_button.pressed.connect(cancel_requested.emit)
	blocker.hide()
	notice_label = Label.new()
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var notice_anchor := CenterContainer.new()
	notice_anchor.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice_anchor.offset_top = 75
	notice_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(notice_anchor)
	var shell := PanelContainer.new()
	shell.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(notice_label)
	notice_anchor.add_child(shell)
	notice_frame = Holo.plate(notice_label, Holo.frame("compact"), Vector2(Holo.DEFAULT.padding.y, Holo.DEFAULT.compact_padding))
	notice_label.hide()


func present(title: String, elapsed: int, duration: int) -> void:
	notice_label.hide()
	caption.text = ""
	update_progress(title, elapsed, duration)
	blocker.show()
	cancel_button.grab_focus()


func update_progress(title: String, elapsed: int, duration: int) -> void:
	if not caption.text.is_empty() and progress.value == elapsed: return
	caption.text = "%s · %ds remaining" % [title, duration - elapsed]
	progress.max_value = duration
	progress.value = elapsed
	progress.accessibility_name = caption.text


func dismiss(message: String = "", kind: String = "compact") -> void:
	blocker.hide()
	if notice_label.visible and notice_label.text == message and notice_kind == kind: return
	notice_kind = kind
	Motion.restore_panel(notice_label)
	if notice_timer != null: notice_timer.kill()
	notice_label.text = message
	notice_label.visible = not message.is_empty()
	if notice_label.visible:
		notice_frame.add_theme_stylebox_override("panel", Holo.frame(kind))
		notice_label.add_theme_color_override("font_color", Holo.DEFAULT.warning if kind == "warning" else Holo.DEFAULT.text)
		Motion.reveal(notice_label, Holo.DEFAULT.selection_seconds)
		if kind == "warning": Holo.audio(Holo.DEFAULT.warning_sound, self)
		if kind == "reward": Holo.audio(Holo.DEFAULT.reward_sound, self)
		notice_timer = create_tween()
		notice_timer.tween_interval(2.5)
		notice_timer.tween_callback(notice_label.hide)
