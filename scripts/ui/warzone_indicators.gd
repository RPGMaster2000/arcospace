extends RefCounted

const Meter = preload("res://scripts/ui/holographic/segmented_meter.gd")
## Small shared graphics for the Warzone HUD and inspections.

const ALLIED := Color("65dee9")
const HOSTILE := Color("ff817c")
const TRACK := Color("20364b")
const MOTIFS := {
	"fleet": preload("res://assets/ui/card_effects/hull.png"),
	"combat": preload("res://assets/ui/card_effects/attack.png"),
	"warning": preload("res://assets/ui/card_effects/risk.png"),
	"sabotage": preload("res://assets/ui/card_effects/sabotage.png"),
	"coordinate": preload("res://assets/ui/card_effects/attack.png"),
	"jam": preload("res://assets/ui/card_effects/sabotage.png"),
	"fortify": preload("res://assets/ui/card_effects/shield.png"),
	"deploy": preload("res://assets/ui/card_effects/hull.png"),
	"repair": preload("res://assets/ui/card_effects/repair.png"),
}


static func icon(kind: String, tint: Color, width: float = 24.0) -> TextureRect:
	var image := TextureRect.new()
	image.texture = MOTIFS[kind]
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.custom_minimum_size = Vector2(width, width * 0.8)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.modulate = tint
	return image


static func bar(tint: Color, height: float = 6.0, background: Color = TRACK) -> ProgressBar:
	var gauge := ProgressBar.new()
	gauge.custom_minimum_size.y = height
	gauge.show_percentage = false
	gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Meter.attach(gauge, tint, background)
	return gauge


static func tint(side: String) -> Color:
	return ALLIED if side == "allied" else HOSTILE
