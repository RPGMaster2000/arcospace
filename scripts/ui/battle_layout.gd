extends RefCounted
# RESPONSIBILITY: Fit battle utility controls; never move ships, cards or combat status bars.
const BUTTON_SIZE = Vector2(52, 48)


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


static func fit(view: Control, menu: Button, allocation: Button) -> void:
	var inset := safe_insets(view)
	# Keep the left column at the content edge; a display-wide inset creates a second gutter.
	menu.position = Vector2(23, 16 + inset.y)
	menu.size = Vector2(48, 48)
	for path in ["TurnLabel", "SalvageLabel"]:
		view.get_node(path).position.x = menu.position.x + menu.size.x + 12
		view.get_node(path).position.y = (15 if path == "TurnLabel" else 50) + inset.y
	for index in range(1, 4):
		view.get_node("PlayerResource%d" % index).position.x = 23
		view.get_node("PlayerResource%d" % index).position.y = 92 + (index - 1) * 82 + inset.y
		view.get_node("EnemyResource%d" % index).position.x = view.size.x - 94 - inset.z
	var hull: Control = view.get_node("PlayerHullBar")
	var emp: Control = view.get_node("FTLPanel")
	emp.position = Vector2(hull.position.x, hull.position.y + hull.size.y + 6)
	var charge: Label = emp.get_node("Charge")
	charge.size.x = emp.get_node("Progress").size.x
	charge.clip_text = true
	charge.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	allocation.size = BUTTON_SIZE
	var resources: Control = view.get_node("PlayerResource3")
	allocation.position = Vector2(resources.position.x, resources.position.y + resources.size.y + 8)
	# The optional 2D fallback has a visible action log in the newly occupied strip.
	# Its 3D counterpart is already hidden; leave that presentation unchanged.
	var action_log: Control = view.get_node("LastActionLabel")
	if action_log.visible:
		action_log.position = Vector2(140 + inset.x, 76 + inset.y)
		action_log.size.x = view.size.x - 280 - inset.x - inset.z
	view.get_node("SystemsFailureDisplay").fit(
		view.size, resources.position.y + resources.size.y + 6
	)
	var modifier: Control = view.get_node("ModifierDisplay")
	modifier.fit_panel(
		view.size, maxf(inset.x, inset.z), view.get_node(view.card_slots[0]).position.y
	)
