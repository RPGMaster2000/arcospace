extends VBoxContainer

const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
const FAMILIES := ["materials", "energy", "crew"]

var families := [0, 0, 0]
var tiers := [0, 0, 0]
var upgraded := 0
var readout: RichTextLabel
var strip: Control


func _ready() -> void:
	add_theme_constant_override("separation", 5)
	readout = RichTextLabel.new()
	readout.bbcode_enabled = true
	readout.fit_content = true
	readout.scroll_active = false
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_font_override("normal_font", Style.UI_FONT)
	readout.add_theme_font_size_override("normal_font_size", 16)
	add_child(readout)
	strip = Control.new()
	strip.custom_minimum_size.y = 10
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.draw.connect(_paint_strip)
	strip.resized.connect(strip.queue_redraw)
	add_child(strip)


func display(cards: Array, capacity: int) -> void:
	families = [0, 0, 0]
	tiers = [0, 0, 0]
	upgraded = 0
	for card in cards:
		families[FAMILIES.find(card.family)] += 1
		tiers[clampi(card.tier - 1, 0, 2)] += 1
		upgraded += int(card.upgrade_level > 0)
	var summary := PackedStringArray(["[b]%d / %d cards[/b]" % [cards.size(), capacity] if capacity > 0 else
		"[b]%d cards[/b]" % cards.size()])
	for index in FAMILIES.size():
		var family: String = FAMILIES[index]
		summary.append("[color=#%s]%s %d[/color]" % [Holo.family(family).to_html(false), family.capitalize(), families[index]])
	summary.append("Tier I %d   II %d   III %d" % tiers)
	summary.append("%d upgraded" % upgraded)
	readout.text = "     ·     ".join(summary)
	strip.queue_redraw()


func _paint_strip() -> void:
	strip.draw_rect(Rect2(Vector2.ZERO, strip.size), Color("213748"))
	var total: int = families[0] + families[1] + families[2]
	if total == 0: return
	var x := 0.0
	for index in families.size():
		var width: float = strip.size.x * families[index] / total
		if width <= 0.0: continue
		var tint := Holo.family(FAMILIES[index])
		strip.draw_rect(Rect2(x, 1, maxf(0, width - 2), strip.size.y - 2), tint.darkened(0.24))
		strip.draw_line(Vector2(x, 1), Vector2(x + maxf(0, width - 2), 1), tint)
		x += width
