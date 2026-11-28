extends RefCounted

const Layout = preload("res://scripts/ui/battle_layout.gd")


static func fit(margin: MarginContainer, padding: int) -> void:
	var window := DisplayServer.window_get_size()
	var inset := Layout.scaled_insets(DisplayServer.get_display_safe_area(), window, margin.size) 		if OS.has_feature("android") or OS.has_feature("ios") else Vector4.ZERO
	apply(margin, padding, inset)


static func apply(margin: MarginContainer, padding: int, inset: Vector4) -> void:
	var sides := ["left", "top", "right", "bottom"]
	for side in sides.size():
		margin.add_theme_constant_override("margin_" + sides[side], padding + maxi(0, roundi(inset[side])))
