extends CanvasLayer

# RESPONSIBILITY: Present one read-only enlarged original card and its full effect/upgrade panel.
# One lazily created, read-only overlay per SceneTree. Uses the original card scene, never a second renderer.
const Data = preload("res://scripts/cards/card_data.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var shade: ColorRect
var info: PanelContainer
var column: VBoxContainer
var details: VBoxContainer
var info_scroll: ScrollContainer
var close_button: Button
var heading: Label
var metadata: Label
var visual: Button
var source: Control
var source_visual: Control
var settings: Resource
var current_card: Resource
var level_panels: Array[PanelContainer] = []
var previous_focus: Control
var suspended_scrolls: Array = []
var source_tooltips: Array = []
var tween: Tween
var closing: bool = false
var combined_rect: Rect2
var panel_size: Vector2


func _ready() -> void:
	layer = 200
	shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0)
	add_child(shade)
	shade.gui_input.connect(_outside)
	info = PanelContainer.new()
	shade.add_child(info)
	column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	info.add_child(column)
	var row = HBoxContainer.new()
	column.add_child(row)
	heading = _label("", 22)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	close_button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(72, 48)
	Style.action(close_button)
	row.add_child(close_button)
	close_button.pressed.connect(dismiss)
	metadata = _label("", 18)
	column.add_child(metadata)
	info_scroll = ScrollContainer.new()
	info_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	info_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(info_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	info_scroll.add_child(details)
	shade.resized.connect(_resize)
	shade.hide()


func _label(text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func is_open() -> bool:
	return is_instance_valid(shade) and shade.visible


func present(owner: Control, original: Control, configuration: Resource) -> void:
	if is_open():
		dismiss(true)
	source = owner
	source_visual = original
	settings = configuration
	current_card = original.card_data
	previous_focus = get_viewport().gui_get_focus_owner()
	closing = false
	source_tooltips.clear()
	for control in [owner, original]:
		if owner == original and not source_tooltips.is_empty():
			continue
		source_tooltips.append([weakref(control), control.tooltip_text])
		control.tooltip_text = ""
	# Freeze global touch-drag adapters behind this modal; native GUI input is blocked by shade.
	suspended_scrolls.clear()
	for scroll in get_tree().root.find_children("*", "ScrollContainer", true, false):
		if scroll == info_scroll:
			continue
		suspended_scrolls.append([weakref(scroll), scroll.is_processing_input()])
		scroll.set_process_input(false)
		if scroll.has_method("allows_activation"):
			scroll.touch_index = -1
			scroll.dragged = false
			scroll.blocked_until = Time.get_ticks_msec() + 180
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	level_panels.clear()
	var base: Resource = current_card.get_meta("inspection_base", current_card)
	heading.text = base.card_name.trim_suffix("++").trim_suffix("+")
	metadata.text = (
		"%s · Cost %d · Tier %d · %s\nCurrent: %s"
		% [
			current_card.family.capitalize(),
			current_card.cost,
			current_card.tier,
			current_card.allocation_category.capitalize(),
			["Base", "Upgrade I", "Upgrade II"][current_card.upgrade_level]
		]
	)
	metadata.add_theme_font_size_override("font_size", settings.information_panel_text_size)
	var accent: Color = {
		"materials": Color("ec8277"), "energy": Color("7dcbea"), "crew": Color("8bdfa1")
	}[current_card.family]
	var box: StyleBoxFlat = Style.style(accent).duplicate()
	for edge in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(edge, 12)
	info.add_theme_stylebox_override("panel", box)
	for level in range(3):
		var panel = PanelContainer.new()
		var active: bool = level == current_card.upgrade_level
		var style: StyleBoxFlat = Style.style(accent if active else Color("34495b")).duplicate()
		style.bg_color = Color("183243") if active else Color("101e2a")
		for edge in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			style.set_content_margin(edge, 8)
		panel.add_theme_stylebox_override("panel", style)
		details.add_child(panel)
		level_panels.append(panel)
		panel.set_meta("current_level", active)
		var rows = VBoxContainer.new()
		panel.add_child(rows)
		rows.add_child(
			_label(
				(
					["BASE EFFECT", "UPGRADE I", "UPGRADE II"][level]
					+ (" · CURRENT" if active else "")
				),
				settings.information_panel_text_size
			)
		)
		var effects: Dictionary = (
			base.effects
			if level == 0
			else base.upgrade_effects[level - 1] if level <= base.upgrade_effects.size() else {}
		)
		var text: String = Data.describe_effects(effects)
		if base.play_again:
			text += "; play again"
		rows.add_child(
			_label(
				text if not text.is_empty() else "No upgrade defined.",
				settings.information_panel_text_size
			)
		)
	# Show actual temporary preview separately when Ion Storm changes the selected level.
	var actual: Dictionary = (
		base.effects
		if current_card.upgrade_level == 0
		else base.upgrade_effects[current_card.upgrade_level - 1]
	)
	if current_card.effects != actual:
		details.add_child(
			_label(
				"CURRENT COMBAT PREVIEW\n" + Data.describe_effects(current_card.effects),
				settings.information_panel_text_size
			)
		)
	visual = load("res://scenes/card.tscn").instantiate()
	visual.inspection_enabled = false
	visual.presentation_settings = original.presentation_settings
	visual.discard_target_height = original.discard_target_height
	visual.card_data = current_card
	shade.add_child(visual)
	visual.get_node("DiscardButton").hide()
	visual.tooltip_text = ""
	for control in [visual] + visual.find_children("*", "Control", true, false):
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.focus_mode = Control.FOCUS_NONE
	# Keep current preview styling/tints, rather than rebuilding an approximation of the selected card.
	for name in [
		"TitleLabel",
		"CostLabel",
		"TierLabel",
		"DescriptionLabel",
		"ResourceIcon",
		"ArtPlaceholder",
		"CostRule"
	]:
		visual.get_node(name).modulate = original.get_node(name).modulate
	for name in ["normal", "hover", "pressed", "disabled"]:
		visual.add_theme_stylebox_override(name, original.get_theme_stylebox(name).duplicate())
	visual.modulate = original.modulate
	visual.self_modulate = original.self_modulate
	visual.border_time = original.border_time
	if owner.has_method("set_card_scale") and is_instance_valid(owner.badge):
		visual.add_child(owner.badge.duplicate())
	info_scroll.scroll_vertical = 0
	shade.show()
	_layout()
	var target: Vector2 = visual.position
	var scale_target: Vector2 = visual.scale
	visual.position = original.get_global_transform_with_canvas().origin
	visual.scale = Vector2.ONE * original.get_global_transform_with_canvas().get_scale().x
	info.modulate.a = 0
	shade.color.a = 0
	tween = create_tween().set_parallel(true)
	(
		tween
		. tween_property(visual, "position", target, settings.inspection_tween_duration)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(visual, "scale", scale_target, settings.inspection_tween_duration)
	tween.tween_property(info, "modulate:a", 1.0, settings.inspection_tween_duration)
	tween.tween_property(
		shade, "color:a", settings.background_dim_opacity, settings.inspection_tween_duration
	)
	close_button.grab_focus()


func _layout() -> void:
	var available: Vector2 = shade.size - Vector2(32, 32)
	var gap: float = settings.panel_card_spacing
	var width: float = minf(settings.information_panel_width, available.x - gap - 99)
	width = maxf(180, width)
	var enlarged: float = minf(
		settings.enlarged_card_scale, minf(available.y / 294.0, (available.x - width - gap) / 198.0)
	)
	enlarged = maxf(0.1, enlarged)
	var height: float = minf(available.y, maxf(420, 294 * enlarged))
	var combined: Vector2 = Vector2(198 * enlarged + gap + width, height)
	var origin: Vector2 = (shade.size - combined) / 2
	combined_rect = Rect2(origin, combined)
	visual.position = origin + Vector2(0, (height - 294 * enlarged) / 2)
	visual.scale = Vector2.ONE * enlarged
	info.position = origin + Vector2(198 * enlarged + gap, 0)
	panel_size = Vector2(width, height)
	info.size = panel_size


func _resize() -> void:
	if not is_open() or not is_instance_valid(visual):
		return
	if closing:
		if tween:
			tween.kill()
		_finish()
		return
	if tween:
		tween.kill()
	_layout()
	info.modulate.a = 1
	shade.color.a = settings.background_dim_opacity


func dismiss(immediate: bool = false) -> void:
	if not is_open() or (closing and not immediate):
		return
	closing = true
	if tween:
		tween.kill()
	if immediate or not is_instance_valid(source_visual) or not source_visual.is_visible_in_tree():
		_finish()
		return
	tween = create_tween().set_parallel(true)
	tween.tween_property(
		visual,
		"position",
		source_visual.get_global_transform_with_canvas().origin,
		settings.inspection_tween_duration
	)
	tween.tween_property(
		visual,
		"scale",
		Vector2.ONE * source_visual.get_global_transform_with_canvas().get_scale().x,
		settings.inspection_tween_duration
	)
	tween.tween_property(info, "modulate:a", 0.0, settings.inspection_tween_duration)
	tween.tween_property(shade, "color:a", 0.0, settings.inspection_tween_duration)
	tween.chain().tween_callback(_finish)


func _finish() -> void:
	shade.hide()
	if is_instance_valid(visual):
		visual.queue_free()
	visual = null
	source = null
	source_visual = null
	for saved in suspended_scrolls:
		var scroll = saved[0].get_ref()
		if is_instance_valid(scroll):
			scroll.set_process_input(saved[1])
	suspended_scrolls.clear()
	for saved in source_tooltips:
		var control = saved[0].get_ref()
		if is_instance_valid(control):
			control.tooltip_text = saved[1]
	source_tooltips.clear()
	if (
		is_instance_valid(previous_focus)
		and previous_focus.is_inside_tree()
		and not previous_focus.is_queued_for_deletion()
		and previous_focus.is_visible_in_tree()
	):
		previous_focus.grab_focus()
	closing = false


func _process(_delta: float) -> void:
	# Wrapped labels can transiently expand a Container before its width settles.
	if is_open() and not closing and info.size != panel_size:
		info.size = panel_size
	if (
		is_open()
		and not closing
		and (
			not is_instance_valid(source)
			or not source.is_visible_in_tree()
			or source.is_queued_for_deletion()
		)
	):
		dismiss(true)


func _outside(event: InputEvent) -> void:
	var pressed: bool = (
		(event is InputEventMouseButton and event.pressed)
		or (event is InputEventScreenTouch and event.pressed)
	)
	if pressed and not combined_rect.has_point(event.position):
		shade.accept_event()
		dismiss()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		dismiss()
	elif (
		event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion
	):
		# Keep keyboard/controller actions inside the read-only modal, including global shortcuts.
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_down"):
			info_scroll.scroll_vertical += settings.information_panel_text_size * 3
		elif event.is_action_pressed("ui_up"):
			info_scroll.scroll_vertical -= settings.information_panel_text_size * 3
		elif event is InputEventKey and event.pressed and event.keycode == KEY_PAGEDOWN:
			info_scroll.scroll_vertical += roundi(info_scroll.size.y)
		elif event is InputEventKey and event.pressed and event.keycode == KEY_PAGEUP:
			info_scroll.scroll_vertical -= roundi(info_scroll.size.y)
		close_button.grab_focus()
