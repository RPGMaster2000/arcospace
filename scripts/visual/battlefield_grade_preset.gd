@tool
extends Resource
class_name BattlefieldGradePreset
## Display-referred Mobile grading inspired by Rytelier's SMH ranges and vibrance.
## A neutral resource or Strength 0 bypasses the shader entirely.
@export var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		emit_changed()
@export_range(0, 1, 0.01) var strength: float = 1.0:
	set(value):
		if strength == value:
			return
		strength = value
		emit_changed()
@export_group("Shadows / Midtones / Highlights")
## Multiplicative tint. White leaves the original channel balance unchanged.
@export_color_no_alpha var shadow_tint: Color = Color.WHITE:
	set(value):
		if shadow_tint == value:
			return
		shadow_tint = value
		emit_changed()
@export_color_no_alpha var midtone_tint: Color = Color.WHITE:
	set(value):
		if midtone_tint == value:
			return
		midtone_tint = value
		emit_changed()
@export_color_no_alpha var highlight_tint: Color = Color.WHITE:
	set(value):
		if highlight_tint == value:
			return
		highlight_tint = value
		emit_changed()
## 1 preserves brightness; lift modestly to keep dark hulls readable.
@export_range(0.5, 1.5, 0.01) var shadow_brightness: float = 1.0:
	set(value):
		if shadow_brightness == value:
			return
		shadow_brightness = value
		emit_changed()
@export_range(0.5, 1.5, 0.01) var midtone_brightness: float = 1.0:
	set(value):
		if midtone_brightness == value:
			return
		midtone_brightness = value
		emit_changed()
@export_range(0.5, 1.5, 0.01) var highlight_brightness: float = 1.0:
	set(value):
		if highlight_brightness == value:
			return
		highlight_brightness = value
		emit_changed()
@export_group("Color and Contrast")
## Gentle S-curve contrast, preserving black and white endpoints. 1 is neutral.
@export_range(0.5, 1.5, 0.01) var contrast: float = 1.0:
	set(value):
		if contrast == value:
			return
		contrast = value
		emit_changed()
@export_range(0, 2, 0.01) var saturation: float = 1.0:
	set(value):
		if saturation == value:
			return
		saturation = value
		emit_changed()
## Relative saturation in the shadow range; other ranges use the global value.
@export_range(0, 1.5, 0.01) var shadow_saturation: float = 1.0:
	set(value):
		if shadow_saturation == value:
			return
		shadow_saturation = value
		emit_changed()
## Preferentially boosts low-saturation colors; 0 is neutral.
@export_range(-0.5, 0.5, 0.01) var vibrance: float = 0.0:
	set(value):
		if vibrance == value:
			return
		vibrance = value
		emit_changed()
@export_group("Luminance Ranges")
## Shadow weight fades from full to zero between these display-luminance values.
@export var shadow_range: Vector2 = Vector2(0.0, 0.35):
	set(value):
		if shadow_range == value:
			return
		shadow_range = value
		emit_changed()
## Highlight weight fades from zero to full between these values.
@export var highlight_range: Vector2 = Vector2(0.55, 1.0):
	set(value):
		if highlight_range == value:
			return
		highlight_range = value
		emit_changed()

func is_neutral() -> bool:
	return (
		shadow_tint == Color.WHITE and midtone_tint == Color.WHITE
		and highlight_tint == Color.WHITE and shadow_brightness == 1.0
		and midtone_brightness == 1.0 and highlight_brightness == 1.0
		and contrast == 1.0 and saturation == 1.0 and shadow_saturation == 1.0 and vibrance == 0.0
	)

static func safe_range(value: Vector2) -> Vector2:
	var start := clampf(minf(value.x, value.y), 0.0, 0.999)
	return Vector2(start, clampf(maxf(value.x, value.y), start + 0.001, 1.0))

func parameters() -> Dictionary:
	return {
		"strength": clampf(strength, 0, 1),
		"shadow_tint": Vector3(shadow_tint.r, shadow_tint.g, shadow_tint.b),
		"midtone_tint": Vector3(midtone_tint.r, midtone_tint.g, midtone_tint.b),
		"highlight_tint": Vector3(highlight_tint.r, highlight_tint.g, highlight_tint.b),
		"brightness": Vector3(shadow_brightness, midtone_brightness, highlight_brightness),
		"contrast": contrast, "saturation": saturation, "shadow_saturation": shadow_saturation, "vibrance": vibrance,
		"shadow_range": safe_range(shadow_range),
		"highlight_range": safe_range(highlight_range)
	}
