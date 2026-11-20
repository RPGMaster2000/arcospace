extends CanvasLayer
## The campaign outcome is already committed when this banner opens.

signal dismissed

const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const DURATION := 4.5

var active := false
var _panel: CenterContainer
var _caption: Label
var _skip: Button
var _reveal: Tween


func _ready() -> void:
	layer = 205
	_panel = CenterContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_panel.offset_top = 78
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", Presentation.style(Color("69b6d4")))
	_panel.add_child(frame)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)
	_caption = Label.new()
	_caption.add_theme_font_size_override("font_size", 17)
	row.add_child(_caption)
	_skip = Button.new()
	_skip.text = "Skip"
	_skip.custom_minimum_size = Vector2(66, 42)
	Presentation.action(_skip)
	_skip.pressed.connect(finish)
	row.add_child(_skip)
	hide()


func begin(outcome: Dictionary) -> void:
	active = true
	_caption.text = "%s · +%d Salvage" % [outcome.grade, outcome.salvage]
	_caption.modulate = Color("c3d0de") if outcome.grade == "Pyrrhic Victory" else Color("9de9f4")
	_panel.modulate.a = 0.0
	show()
	_reveal = create_tween()
	_reveal.tween_property(_panel, "modulate:a", 1.0, 0.3)
	_reveal.tween_interval(DURATION - 0.3)
	_reveal.tween_callback(finish)


func finish() -> void:
	if not active: return
	active = false
	if _reveal != null:
		_reveal.kill()
		_reveal = null
	hide()
	dismissed.emit()
