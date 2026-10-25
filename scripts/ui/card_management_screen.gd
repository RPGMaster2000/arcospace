extends CanvasLayer

# Presentation only. Emits one intent per selection; State/Deck validate and commit it.
signal confirmed(mode: String, card: Resource, revision: int)
signal declined(revision: int)
signal closed
signal save_quit_requested
const Gallery = preload("res://scripts/ui/card_gallery.gd")
const Portrait = preload("res://scripts/ui/card_portrait.gd")
const EffectText = preload("res://scripts/ui/card_effect_text.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
const Scroll = preload("res://scripts/ui/encounter_scroll.gd")
const FADE_TIME = 0.22
var shade: ColorRect
var margin: MarginContainer
var heading: Label
var instruction: Label
var gallery: VBoxContainer
var details_scroll: ScrollContainer
var details: VBoxContainer
var incoming_header: HBoxContainer
var incoming_identity: Label
var footer: HBoxContainer
var context: Label
var save_quit_button: Button
var confirm_button: Button
var decline_button: Button
var selection: Label
var incoming_portrait: Button
var selected_card: Resource
var incoming: Resource
var mode: String = ""
var revision: int = 0
var consumed: bool = true
var closing: bool = false
var motion: Tween
var previous_focus: Control

func _ready() -> void:
	layer = 140
	shade = ColorRect.new()
	shade.color = Color("09121e")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	heading = _label("", 27)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	save_quit_button = _button("Save & Quit", header)
	save_quit_button.pressed.connect(save_quit_requested.emit)
	instruction = _label("", 18)
	column.add_child(instruction)
	var body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	gallery = Gallery.new()
	gallery.inspection_enabled = true
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.size_flags_stretch_ratio = 0.63
	body.add_child(gallery)
	gallery.card_selected.connect(select_card)
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.37
	panel.add_theme_stylebox_override("panel", Style.style(Style.COLORS.special))
	body.add_child(panel)
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	panel.add_child(right)
	incoming_header = HBoxContainer.new()
	incoming_header.add_theme_constant_override("separation", 14)
	right.add_child(incoming_header)
	incoming_identity = _label("", 19)
	incoming_identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	incoming_header.add_child(incoming_identity)
	details_scroll = Scroll.new()
	details_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(details_scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	details_scroll.add_child(details)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	column.add_child(footer)
	context = _label("", 18)
	context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(context)
	decline_button = _button("Keep Current Deck", footer)
	decline_button.pressed.connect(_decline)
	confirm_button = _button("", footer)
	for action in [decline_button, confirm_button]:
		action.custom_minimum_size.y = 60
	confirm_button.pressed.connect(_confirm)
	shade.resized.connect(_fit)
	shade.hide()

func _label(text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_font_override("font", Style.UI_FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, parent: Node) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 52)
	button.add_theme_font_size_override("font_size", 20)
	Style.action(button)
	parent.add_child(button)
	return button

# Inputs are disposable presentation snapshots, never an inventory or transaction owner.
func present(
	operation: String, cards: Array, remaining: int = 0,
	incoming_card: Resource = null, capacity: int = 0, result_context: String = ""
) -> void:
	var opening: bool = not shade.visible or closing
	_stop_motion()
	if opening:
		previous_focus = get_viewport().gui_get_focus_owner()
	revision += 1
	mode = operation
	incoming = incoming_card
	selected_card = null
	consumed = false
	closing = false
	confirm_button.disabled = true
	decline_button.visible = mode == "replace"
	decline_button.disabled = false
	match mode:
		"card":
			heading.text = "Acquire Card"
			instruction.text = "Choose one reward. Select a card to compare its details."
			context.text = "One card reward"
			confirm_button.text = "Acquire Card"
		"upgrade":
			heading.text = "Upgrade Card — %d upgrades remaining" % remaining
			instruction.text = "Choose different cards. All available upgrades must be spent."
			context.text = "%d remaining" % remaining
			confirm_button.text = "Apply Upgrade"
		"replace":
			heading.text = "Replace Card — Deck full: %d/%d cards" % [cards.size(), capacity]
			instruction.text = "Select an owned card to remove in exchange for the reward."
			context.text = "Keep or replace"
			confirm_button.text = "Replace Selected Card"
	if not result_context.is_empty():
		instruction.text = result_context + " · " + instruction.text
	gallery.show_toolbar = mode != "card"
	gallery.filters.visible = gallery.show_toolbar
	gallery.category = "All"
	gallery.sort_mode = 0
	gallery.sorting.select(0)
	gallery.set_category("All")
	gallery.set_cards(cards)
	gallery.select_identity("")
	incoming_header.visible = mode == "replace"
	if is_instance_valid(incoming_portrait):
		incoming_header.remove_child(incoming_portrait)
		incoming_portrait.queue_free()
	incoming_portrait = null
	if mode == "replace":
		incoming_identity.text = (
			"RECEIVE\n%s\n%d %s · Tier %d · Upgrade %d"
			% [incoming.card_name, incoming.cost, incoming.family.capitalize(), incoming.tier, incoming.upgrade_level]
		)
		incoming_portrait = Portrait.new()
		incoming_portrait.card_data = incoming
		incoming_portrait.card_scale = 0.45
		incoming_portrait.inspection_enabled = false
		incoming_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		incoming_portrait.focus_mode = Control.FOCUS_NONE
		incoming_header.add_child(incoming_portrait)
	_refresh_details()
	shade.show()
	_fit()
	shade.modulate.a = 0.0 if opening else 1.0
	if opening:
		motion = create_tween()
		motion.tween_property(shade, "modulate:a", 1.0, FADE_TIME)
	# Remove keyboard focus from the covered expedition UI.
	get_viewport().gui_release_focus()
	if not gallery.grid.get_children().is_empty():
		gallery.grid.get_child(0).grab_focus()

func select_card(card: Resource) -> void:
	if consumed or closing or not shade.visible or not gallery.scroll.allows_activation():
		return
	var valid: bool = false
	for candidate in gallery.cards:
		if candidate == card:
			valid = true
	if not valid:
		return
	selected_card = card
	gallery.select_identity(card.identity_key())
	confirm_button.disabled = false
	_refresh_details()

func _refresh_details() -> void:
	for child in details.get_children():
		details.remove_child(child)
		child.queue_free()
	selection = _label("Select a card", 21)
	details.add_child(selection)
	if selected_card != null:
		selection.text = selected_card.card_name
	if mode == "replace":
		if selected_card != null:
			_card_section("REMOVE", selected_card, false)
		else:
			details.add_child(_label("REMOVE\nSelect an owned card from the gallery.", 18))
		details.add_child(_label("RECEIVE · Effects", 21))
		details.add_child(_label(incoming.description, 18))
	elif selected_card != null:
		if mode == "upgrade":
			var next: Resource = selected_card.with_upgrade(selected_card.upgrade_level + 1)
			_card_section("AFTER UPGRADE · Level %d" % next.upgrade_level, next, true, 1.0)
			_card_section("CURRENT · Level %d" % selected_card.upgrade_level, selected_card, false)
			details.add_child(_label("CHANGES", 21))
			var comparison = RichTextLabel.new()
			comparison.bbcode_enabled = true
			comparison.fit_content = true
			comparison.scroll_active = false
			comparison.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			comparison.add_theme_font_size_override("normal_font_size", 18)
			comparison.text = EffectText.comparison(next, selected_card)
			details.add_child(comparison)
		else:
			_card_section("SELECTED", selected_card, true)
	details_scroll.scroll_vertical = 0

func _card_section(title: String, card: Resource, art: bool, portrait_scale: float = 0.65) -> Button:
	details.add_child(_label(title, 21))
	var portrait: Button
	if art:
		portrait = Portrait.new()
		portrait.card_data = card
		portrait.card_scale = portrait_scale
		portrait.inspection_enabled = false
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.focus_mode = Control.FOCUS_NONE
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		details.add_child(portrait)
	details.add_child(_label(
		"%s · %d %s · Tier %d · Upgrade %d"
		% [card.card_name, card.cost, card.family.capitalize(), card.tier, card.upgrade_level], 18
	))
	details.add_child(_label(card.description, 18))
	return portrait

func _confirm() -> void:
	if consumed or closing or not shade.visible or selected_card == null or confirm_button.disabled:
		return
	consumed = true
	confirm_button.disabled = true
	decline_button.disabled = true
	confirmed.emit(mode, selected_card, revision)

func _decline() -> void:
	if consumed or closing or not shade.visible or mode != "replace":
		return
	consumed = true
	confirm_button.disabled = true
	decline_button.disabled = true
	declined.emit(revision)

func dismiss(immediate: bool = false) -> void:
	revision += 1
	consumed = true
	_stop_motion()
	if not shade.visible:
		return
	closing = true
	confirm_button.disabled = true
	decline_button.disabled = true
	if immediate:
		_finish_close()
	else:
		motion = create_tween()
		motion.tween_property(shade, "modulate:a", 0.0, FADE_TIME)
		motion.tween_callback(_finish_close)

func _finish_close() -> void:
	shade.hide()
	closing = false
	mode = ""
	selected_card = null
	incoming = null
	closed.emit()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func _stop_motion() -> void:
	if motion and motion.is_valid():
		motion.kill()

func _fit() -> void:
	# Small margins; no reserved expedition HUD height. Honor actual desktop/mobile safe area.
	var safe: Rect2i = DisplayServer.get_display_safe_area() if OS.has_feature("android") else Rect2i()
	var window: Vector2i = DisplayServer.window_get_size()
	var inset = Vector4.ZERO
	if OS.has_feature("android") and window.x > 0 and window.y > 0:
		var scale_factor: Vector2 = shade.size / Vector2(window)
		inset = Vector4(
			safe.position.x * scale_factor.x, safe.position.y * scale_factor.y,
			(window.x - safe.end.x) * scale_factor.x, (window.y - safe.end.y) * scale_factor.y
		)
	for pair in [["left", inset.x], ["top", inset.y], ["right", inset.z], ["bottom", inset.w]]:
		margin.add_theme_constant_override("margin_" + pair[0], 12 + maxi(0, roundi(pair[1])))

func _input(event: InputEvent) -> void:
	var inspection: Node = get_node_or_null("/root/CardInspection")
	if inspection != null and inspection.is_open():
		return
	if shade.visible and event.is_action_pressed("ui_cancel"):
		# Mandatory rewards have no new cancel path; replacement has its explicit decline.
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	revision += 1
	_stop_motion()
