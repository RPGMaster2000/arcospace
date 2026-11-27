extends RefCounted
## Shared safe bounds for the hand and mirrored battlefield HUD.
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const FAMILIES = ["materials", "energy", "crew"]
const PRODUCTION = ["synthesizer", "reactor", "quarters"]
const BUTTON_SIZE = Vector2(48, 48)
const RESOURCE_VERTICAL_PAD := 2.0
const RESOURCE_ROW_GAP := 1.0
const PRODUCTION_VERTICAL_PAD := 1.0


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
	var allocation_y := status_y - BUTTON_SIZE.y - tokens.related_gap
	var y := bounds.position.y + 82.0
	var rail := 100.0 if bounds.size.x >= 880 else 82.0
	var row_budget := (allocation_y - y - gap * 2 - tokens.related_gap) / 3.0
	var rows := _measure_resource_rows(view)
	var min_height := rows.x + rows.y + rows.z + 2 * (RESOURCE_VERTICAL_PAD + RESOURCE_ROW_GAP)
	var horizontal := row_budget < min_height
	var height := min_height if horizontal else minf(row_budget, maxf(72.0, min_height))
	if horizontal: rail = clampf((right - left - gap * 5) / 6.0, 64, 91)
	for side in ["Player", "Enemy"]:
		var x := left if side == "Player" else right - rail
		var direction := 1.0 if side == "Player" else -1.0
		for i in FAMILIES.size():
			var tile: Control = view.get_node("%sResource%d" % [side, i + 1])
			tile.position = Vector2(x + i * (rail + gap) * direction, y) if horizontal else Vector2(x, y + i * (height + gap))
			tile.size = Vector2(rail, height)
			_fit_resource(tile, i, padding, rows, min_height)

	var materials: Control = view.get_node("PlayerResource1")
	var crew: Control = view.get_node("PlayerResource3")
	var resources := materials.get_rect().merge(crew.get_rect())
	var emp: Control = view.get_node("FTLPanel")
	emp.position = Vector2(resources.end.x + tokens.related_gap, resources.position.y)
	emp.size = Vector2(materials.size.x * 0.24, resources.size.y)

	var card_width := hand.size.x * hand.scale.x
	var group_width := minf(258.0, card_width * 1.30)
	var min_flank := (group_width + card_width) * 0.5 + gap * 2
	var max_flank := midpoint - left - group_width * 0.5
	var flank := clampf(view._defense_flank_offset(), min_flank, maxf(min_flank, max_flank))
	var tile_width := (group_width - gap) * 0.5
	for side in ["Player", "Enemy"]:
		var player: bool = side == "Player"
		var hull: Control = view.get_node(side + "HullLabel")
		var shield: Control = view.get_node(side + "ShieldsLabel")
		var hull_bar: Control = view.get_node(side + "HullBar")
		var origin := midpoint + (-flank if player else flank) - group_width * 0.5
		hull.position = Vector2(origin if player else origin + tile_width + gap, status_y)
		shield.position = Vector2(origin + tile_width + gap if player else origin, status_y)
		for label in [hull, shield]:
			label.size = Vector2(tile_width, status_height)
			label.add_theme_font_size_override("font_size", 17 if tile_width < 122 else 20)
		hull_bar.position = hull.position + Vector2(padding, hull.size.y - padding - 6)
		hull_bar.size = Vector2(tile_width - 2 * padding, 6)
	allocation.size = Vector2(rail, BUTTON_SIZE.y)
	allocation.position = Vector2(left, resources.end.y + tokens.related_gap)

	var action_log: Control = view.get_node("LastActionLabel")
	if action_log.visible:
		action_log.position = Vector2(left + rail + gap, bounds.position.y + 75)
		action_log.size.x = right - left - 2 * (rail + gap)
	var activation: Rect2 = emp.activation_bounds()
	var warning_edge: float = maxf(emp.get_rect().end.x, activation.end.x) + tokens.related_gap * 2 + view.hud.player_panel.HANDLE_WIDTH
	view.get_node("SystemsFailureDisplay").fit(warning_edge,
		right - rail - gap - view.hud.enemy_panel.HANDLE_WIDTH, allocation.position.y - gap)


static func _measure_resource_rows(view: Control) -> Vector3:
	# Share the tallest measured row on either side so the rails mirror even
	# when shaped text uses a different fallback font.
	var rows := Vector3.ZERO
	for side in ["Player", "Enemy"]:
		for i in FAMILIES.size():
			var tile := view.get_node("%sResource%d" % [side, i + 1])
			rows.x = maxf(rows.x, _line_height(tile.get_node("FamilyLabel")))
			rows.y = maxf(rows.y, _line_height(tile.get_node(FAMILIES[i])))
			rows.z = maxf(rows.z, _line_height(tile.get_node(PRODUCTION[i])) + 2 * PRODUCTION_VERTICAL_PAD)
	return rows


static func _line_height(label: Label) -> float:
	return ceilf(maxf(label.get_line_height(), label.get_minimum_size().y))


static func _fit_resource(tile: Control, index: int, pad: float, rows: Vector3, min_height: float) -> void:
	var width := tile.size.x - 2 * pad
	var reserve: Label = tile.get_node(FAMILIES[index])
	var production: Label = tile.get_node(PRODUCTION[index])
	var family: Label = tile.get_node("FamilyLabel")
	var badge: Control = tile.get_node("ProductionBadge")
	# Grow the insets and gaps with spare height. All three rows keep the
	# same type sizes when the viewport changes.
	var extra := (tile.size.y - min_height) * 0.25
	var gap := RESOURCE_ROW_GAP + extra
	family.position = Vector2(pad, RESOURCE_VERTICAL_PAD + extra)
	family.size = Vector2(width, rows.x)
	reserve.position = Vector2(pad, family.get_rect().end.y + gap)
	reserve.size = Vector2(width, rows.y)
	badge.position = Vector2(pad, reserve.get_rect().end.y + gap)
	badge.size = Vector2(width, rows.z)
	production.position = badge.position + Vector2(0, PRODUCTION_VERTICAL_PAD)
	production.size = Vector2(width, rows.z - 2 * PRODUCTION_VERTICAL_PAD)
