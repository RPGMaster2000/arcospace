extends RefCounted
## Shared safe bounds for the hand and mirrored battlefield HUD.
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const FAMILIES = ["materials", "energy", "crew"]
const PRODUCTION = ["synthesizer", "reactor", "quarters"]
const BUTTON_SIZE = Vector2(48, 48)


static func safe_insets(view: Control) -> Vector4:
	if not OS.has_feature("android") and not OS.has_feature("ios"):
		return Vector4.ZERO
	return scaled_insets(
		DisplayServer.get_display_safe_area(), DisplayServer.window_get_size(), view.size
	)


static func scaled_insets(safe: Rect2i, window: Vector2i, logical: Vector2) -> Vector4:
	if safe.size.x <= 0 or safe.size.y <= 0 or window.x <= 0 or window.y <= 0:
		return Vector4.ZERO
	var factor := logical / Vector2(window)
	return Vector4(
		maxi(0, safe.position.x) * factor.x,
		maxi(0, safe.position.y) * factor.y,
		maxi(0, window.x - safe.end.x) * factor.x,
		maxi(0, window.y - safe.end.y) * factor.y
	)


static func safe_bounds(view_size: Vector2, inset: Vector4) -> Rect2:
	var side := maxf(inset.x, inset.z)
	return Rect2(side, inset.y, view_size.x - side * 2, view_size.y - inset.y - inset.w)


static func fit(view: Control, menu: Button, allocation: Button, bounds: Rect2) -> void:
	var tokens := Holo.DEFAULT
	var edge := float(tokens.section_gap)
	var padding := float(tokens.compact_padding)
	var gap := float(tokens.spacing)
	var left := bounds.position.x + edge
	var right := bounds.end.x - edge
	var midpoint := bounds.get_center().x
	menu.position = Vector2(left, bounds.position.y + 16)
	menu.size = Vector2(48, 48)
	var identity_inset := menu.size.x + gap + padding
	view.hud.header.fit(view.size.x, left + identity_inset, right - identity_inset, bounds.position.y + 12)

	var hand: Control = view.get_node(view.card_slots[0])
	var status_height := 45.0
	var status_y := hand.position.y - 14.0 - status_height
	var allocation_y := status_y - BUTTON_SIZE.y - gap
	var y := bounds.position.y + 82.0
	var rail := 100.0 if bounds.size.x >= 880 else 82.0
	var row_budget := (allocation_y - y - gap * 3) / 3.0
	var horizontal := row_budget < 54.0
	var height := clampf(row_budget, 54.0, 72.0) if not horizontal else 55.0
	if horizontal: rail = clampf((right - left - gap * 5) / 6.0, 64, 91)
	for side in ["Player", "Enemy"]:
		var x := left if side == "Player" else right - rail
		var direction := 1.0 if side == "Player" else -1.0
		for i in FAMILIES.size():
			var tile: Control = view.get_node("%sResource%d" % [side, i + 1])
			tile.position = Vector2(x + i * (rail + gap) * direction, y) if horizontal else Vector2(x, y + i * (height + gap))
			tile.size = Vector2(rail, height)
			_fit_resource(tile, i, padding, height >= 64.0)

	var materials: Control = view.get_node("PlayerResource1")
	var crew: Control = view.get_node("PlayerResource3")
	var resources := materials.get_rect().merge(crew.get_rect())
	var emp: Control = view.get_node("FTLPanel")
	emp.position = Vector2(resources.end.x + tokens.related_gap, resources.position.y)
	emp.size = Vector2(materials.size.x * 0.24, resources.size.y)

	var group_x := maxf(hand.position.x, left)
	var group_width := minf(258.0, hand.size.x * hand.scale.x * 1.30)
	var tile_width := (group_width - gap) * 0.5
	for side in ["Player", "Enemy"]:
		var player: bool = side == "Player"
		var hull: Control = view.get_node(side + "HullLabel")
		var shield: Control = view.get_node(side + "ShieldsLabel")
		var hull_bar: Control = view.get_node(side + "HullBar")
		var origin := group_x if player else 2 * midpoint - group_x - group_width
		hull.position = Vector2(origin if player else origin + tile_width + gap, status_y)
		shield.position = Vector2(origin + tile_width + gap if player else origin, status_y)
		for label in [hull, shield]:
			label.size = Vector2(tile_width, status_height)
			label.add_theme_font_size_override("font_size", 17 if tile_width < 122 else 20)
		hull_bar.position = hull.position + Vector2(padding, hull.size.y - padding - 6)
		hull_bar.size = Vector2(tile_width - 2 * padding, 6)
	allocation.size = BUTTON_SIZE
	allocation.position = Vector2(left, minf(allocation_y, resources.end.y + gap))

	var action_log: Control = view.get_node("LastActionLabel")
	if action_log.visible:
		action_log.position = Vector2(left + rail + gap, bounds.position.y + 75)
		action_log.size.x = right - left - 2 * (rail + gap)
	var warning_edge: float = emp.get_rect().end.x + tokens.related_gap * 2 + view.hud.player_panel.HANDLE_WIDTH
	view.get_node("SystemsFailureDisplay").fit(maxf(group_x, warning_edge),
		minf(2 * midpoint - group_x, right - rail - gap), allocation.position.y - gap)


static func _fit_resource(tile: Control, index: int, pad: float, roomy: bool) -> void:
	var width := tile.size.x - 2 * pad
	var reserve: Label = tile.get_node(FAMILIES[index])
	var production: Label = tile.get_node(PRODUCTION[index])
	var family: Label = tile.get_node("FamilyLabel")
	var badge: Control = tile.get_node("ProductionBadge")
	var production_height := 18.0 if roomy else 14.0
	family.position = Vector2(pad, pad if roomy else 3.0)
	family.size = Vector2(width, 13)
	reserve.position = Vector2(pad, family.get_rect().end.y)
	reserve.size = Vector2(width, tile.size.y - (pad if roomy else 3.0) - production_height - reserve.position.y)
	reserve.add_theme_font_size_override("font_size", 26 if roomy else 18)
	badge.position = Vector2(pad, tile.size.y - (pad if roomy else 3.0) - production_height)
	badge.size = Vector2(width, production_height)
	production.position = badge.position
	production.size = badge.size
	production.add_theme_font_size_override("font_size", 12 if roomy else 11)
