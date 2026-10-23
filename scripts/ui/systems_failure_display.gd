extends Control

const Sound = preload("res://scripts/audio/sfx.gd")
# RESPONSIBILITY: Compact warnings from the authoritative failure snapshot; no timers or rules.
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var columns: Dictionary = {}
var counts: Dictionary = {}
var offline: Dictionary = {}
var _active: Dictionary = {"player": false, "enemy": false}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["player", "enemy"]:
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 0)
		column.custom_minimum_size.x = 120
		add_child(column)
		columns[side] = column
		var heading := _label(column, 11)
		heading.text = "SYSTEMS FAILURE"
		counts[side] = _label(column, 11)
		offline[side] = _label(column, 12)
		offline[side].add_theme_constant_override("line_spacing", -6)
		if side == "enemy":
			for label in column.get_children():
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		column.hide()


func _label(column: VBoxContainer, font_size: int) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", Style.UI_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("ffaaa1"))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	column.add_child(label)
	return label


func fit(board_size: Vector2, top: float) -> void:
	columns.player.position = Vector2(84, top)
	columns.enemy.position = Vector2(board_size.x - 204, top)


func refresh(status: Dictionary) -> void:
	for side in ["player", "enemy"]:
		var data: Dictionary = status[side]
		var active_now: bool = data.remaining >= 0 and not data.offline.is_empty()
		if active_now and not _active[side]:
			Sound.play(&"systems_failure_warning", self)
		elif not active_now and _active[side]:
			Sound.play(&"production_gain", self)
		_active[side] = active_now
		columns[side].visible = active_now
		counts[side].text = "%d TURNS REMAINING" % maxi(0, data.remaining)
		var names: PackedStringArray = []
		for key in data.offline:
			names.append(str(key).capitalize())
		offline[side].text = "\n".join(names)
