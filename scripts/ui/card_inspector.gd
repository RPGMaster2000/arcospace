extends CanvasLayer
# Confirm/cancel presentation only. Owners perform the existing validated state mutation.
signal confirmed(card: Resource)
signal opened
signal closed
const Portrait = preload("res://scripts/ui/card_portrait.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var shade: ColorRect
var panel: VBoxContainer
var heading: Label
var cards_row: HBoxContainer
var cancel_button: Button
var confirm_button: Button
var current_card: Resource
var next_card: Resource
var portraits: Array[Button] = []
var comparison_scroll: ScrollContainer
var comparison_text: RichTextLabel
var previous_focus: Control
var tween: Tween
var consumed: bool = true
var read_only: bool = false

func _ready() -> void:
	layer = 130
	shade = ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.04, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 16)
	shade.add_child(panel)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	panel.add_child(heading)
	cards_row = HBoxContainer.new()
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_row.add_theme_constant_override("separation", 24)
	panel.add_child(cards_row)
	comparison_scroll = ScrollContainer.new()
	comparison_scroll.custom_minimum_size.y = 100
	comparison_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(comparison_scroll)
	comparison_text = RichTextLabel.new()
	comparison_text.bbcode_enabled = true
	comparison_text.fit_content = true
	comparison_text.scroll_active = false
	comparison_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	comparison_text.add_theme_font_size_override("normal_font_size",18)
	comparison_scroll.add_child(comparison_text)
	var actions = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	panel.add_child(actions)
	cancel_button = Button.new()
	cancel_button.text = "Cancel"
	confirm_button = Button.new()
	confirm_button.text = "Confirm"
	for button in [cancel_button, confirm_button]:
		button.custom_minimum_size = Vector2(200, 52)
		button.add_theme_font_size_override("font_size", 22)
		Style.action(button, button == confirm_button)
		actions.add_child(button)
	cancel_button.pressed.connect(dismiss)
	confirm_button.pressed.connect(_confirm)
	shade.resized.connect(_fit)
	shade.hide()

func present(card: Resource, upgraded: Resource = null, inspect_only: bool = false) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	current_card = card
	next_card = upgraded
	read_only = inspect_only
	consumed = false
	for child in cards_row.get_children():
		cards_row.remove_child(child)
		child.queue_free()
	portraits.clear()
	heading.text = "Current card   →   Upgrade " + ("II" if upgraded.upgrade_level == 2 else "I") if upgraded != null else ("Inspect card" if inspect_only else "Acquire card")
	for value in [card, upgraded]:
		if value == null: continue
		var portrait = Portrait.new()
		portrait.card_data = value
		portrait.comparison_base = card if value == upgraded else null
		portrait.mouse_filter = Control.MOUSE_FILTER_STOP
		portrait.focus_mode = Control.FOCUS_NONE
		cards_row.add_child(portrait)
		portraits.append(portrait)
	comparison_scroll.visible = upgraded != null
	comparison_text.text = preload("res://scripts/ui/card_effect_text.gd").comparison(upgraded,card) if upgraded != null else ""
	confirm_button.visible = not inspect_only
	confirm_button.disabled = false
	confirm_button.text = "Confirm upgrade" if upgraded != null else "Acquire card"
	cancel_button.text = "Return to deck" if inspect_only else "Cancel"
	for button in [cancel_button, confirm_button]:
		var neighbor: Button = cancel_button if inspect_only or button == confirm_button else confirm_button
		for direction in ["left", "right", "top", "bottom"]:
			button.set("focus_neighbor_" + direction, button.get_path_to(neighbor))
	shade.show()
	opened.emit()
	_fit()
	shade.modulate.a = 0
	if tween: tween.kill()
	tween = create_tween()
	tween.tween_property(shade, "modulate:a", 1.0, 0.16)
	cancel_button.grab_focus()
	_fit.call_deferred()

func _fit() -> void:
	if portraits.is_empty(): return
	var scale_value: float = minf(1.55, minf((shade.size.y - (280 if next_card != null else 160)) / 294.0, (shade.size.x - 80 - 24 * (portraits.size() - 1)) / (198.0 * portraits.size())))
	for portrait in portraits: portrait.set_card_scale(maxf(0.5, scale_value))
	panel.size = Vector2(minf(shade.size.x - 32, maxf(440, 198 * scale_value * portraits.size() + 24)), 0)
	panel.position = (shade.size - panel.size) / 2
	# Containers settle on the following frame; center again using the resulting size.
	panel.set_deferred("position", Vector2((shade.size.x - panel.size.x) / 2, maxf(16, (shade.size.y - (294 * scale_value + (236 if next_card != null else 116))) / 2)))

func _confirm() -> void:
	if consumed or read_only or not shade.visible: return
	consumed = true
	confirm_button.disabled = true
	var chosen: Resource = current_card
	dismiss()
	confirmed.emit(chosen)

func dismiss() -> void:
	var was_visible: bool = shade.visible
	consumed = true
	if tween: tween.kill()
	shade.hide()
	if was_visible: closed.emit()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree(): previous_focus.grab_focus()

func _input(event: InputEvent) -> void:
	var inspection: Node = get_node_or_null("/root/CardInspection")
	if inspection != null and inspection.is_open(): return
	if not shade.visible: return
	if event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		if confirm_button.visible:
			(cancel_button if get_viewport().gui_get_focus_owner() == confirm_button else confirm_button).grab_focus()
		get_viewport().set_input_as_handled()
