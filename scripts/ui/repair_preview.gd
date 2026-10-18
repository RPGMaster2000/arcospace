extends VBoxContainer
# RESPONSIBILITY: Preview Hull gain and Salvage cost; never spend or modify game state.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const HullBar = preload("res://scripts/hull_bar.gd")
var hull_text: Label
var bar: Control
var cost_text: Label

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 3)
	hull_text = Label.new()
	bar = HullBar.new()
	bar.custom_minimum_size.y = 12
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_text = Label.new()
	for label in [hull_text, cost_text]:
		label.add_theme_font_override("font", Presentation.UI_FONT)
		label.add_theme_font_size_override("font_size", 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hull_text)
	add_child(bar)
	add_child(cost_text)

func show_repair(hull: int, capacity: int, salvage: int, amount: int, unit_cost: int, plating: bool = false) -> void:
	var gain: int = maxi(0, amount)
	var cost: int = gain * unit_cost
	var result: int = hull + gain
	hull_text.text = "%s %d → %d/%d   (+%d %s)" % ["❤️", hull, result, capacity, gain, "plating" if plating else "Hull"]
	hull_text.add_theme_color_override("font_color", bar.plating_color.lightened(.25) if plating else Color(.55, .95, .67))
	bar.preview_hull = result
	bar.update_hull(hull, capacity)
	bar.tooltip_text = "Red: current Hull · Green: repair gain · Amber: plating"
	cost_text.text = "🪨 Salvage %d → %d   (−%d) · %d / %s" % [salvage, salvage - cost, cost, unit_cost, "plating" if plating else "Hull"]
	cost_text.add_theme_color_override("font_color", Color(.95, .78, .46))
	tooltip_text = "%d Salvage restores 1 %s. Preview only; confirm to spend." % [unit_cost, "plating" if plating else "Hull"]
