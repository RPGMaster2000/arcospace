@tool
extends RefCounted
## Native, lightweight card styling. Text and interactions remain in CardView.
## Shared gradient textures are read-only; no per-frame textures or materials.
static var washes: Dictionary = {}


static func wash(tint: Color) -> GradientTexture2D:
	var key := tint.to_html()
	if not washes.has(key):
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0, 0.35, 1])
		gradient.colors = PackedColorArray([Color(tint, 0.14), Color(tint, 0.055), Color(tint, 0)])
		var texture := GradientTexture2D.new()
		texture.width = 4
		texture.height = 64
		texture.fill_from = Vector2(0, 0)
		texture.fill_to = Vector2(0, 1)
		texture.gradient = gradient
		washes[key] = texture
	return washes[key]


static func box(
	base: Color,
	tint: Color,
	selected: bool,
	hovered: bool,
	affordable: bool,
	storm: bool,
	storm_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = base.lerp(tint, 0.035 if affordable else 0.012)
	style.border_color = Color(
		tint, 1.0 if selected else (0.95 if hovered else (0.82 if affordable else 0.63))
	)
	style.set_border_width_all(2 if selected else 1)
	style.set_corner_radius_all(7)
	style.anti_aliasing = true
	if selected:
		style.shadow_color = Color(tint, 0.50)
		style.shadow_size = 10
		# Slight visual enlargement only. Root geometry and its touch hitbox do not move.
		style.expand_margin_left = 2
		style.expand_margin_top = 2
		style.expand_margin_right = 2
		style.expand_margin_bottom = 2
	elif storm:
		style.shadow_color = Color(storm_color, 0.55)
		style.shadow_size = 9
	elif hovered:
		style.shadow_color = Color(tint, 0.16)
		style.shadow_size = 5
	return style
