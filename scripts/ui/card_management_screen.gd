extends CanvasLayer

# Presentation only. Emits one intent per selection; State/Deck validate and commit it.
signal confirmed(mode: String, card: Resource, revision: int)
signal declined(revision: int)
signal closed
signal save_quit_requested
signal view_deck_requested
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Safe = preload("res://scripts/ui/card_screen_margins.gd")
const Effects = preload("res://scripts/ui/card_effect_text.gd")
const CommitFeedback = preload("res://scripts/ui/card_commit_feedback.gd")
const Gallery = preload("res://scripts/ui/card_gallery.gd")
const Portrait = preload("res://scripts/ui/card_portrait.gd")
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
var footer: HBoxContainer
var context: Label
var save_quit_button: Button
var confirm_button: Button
var decline_button: Button
var selection: Label
var incoming_portrait: Button
var purchase_prices: Dictionary = {}
var purchase_balance: int = 0
var selected_card: Resource
var incoming: Resource
var mode: String = ""
var revision: int = 0
var consumed: bool = true
var closing: bool = false
var motion: Tween
var previous_focus: Control
var view_deck_button: Button
var deck_open := false
var body: BoxContainer
var details_panel: PanelContainer
var comparison: HBoxContainer
var compared: Array[Button] = []
var feedback: CommitFeedback

func _ready() -> void:
	layer = 140
	shade = ColorRect.new()
	shade.color = Holo.DEFAULT.surface_depth
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(margin)
	Holo.plate(margin, Holo.frame("dialog"))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	heading = _label("", 27)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	heading.add_theme_color_override("font_color", Holo.DEFAULT.edge)
	view_deck_button = _button("View Deck", header)
	view_deck_button.pressed.connect(view_deck_requested.emit)
	save_quit_button = _button("Save & Quit", header)
	save_quit_button.pressed.connect(save_quit_requested.emit)
	instruction = _label("", 18)
	column.add_child(instruction)
	body = BoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	column.add_child(body)
	gallery = Gallery.new()
	gallery.inspection_enabled = true
	gallery.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery.size_flags_stretch_ratio = 0.63
	body.add_child(gallery)
	gallery.card_selected.connect(select_card)
	details_panel = PanelContainer.new()
	details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_panel.size_flags_stretch_ratio = 0.37
	details_panel.add_theme_stylebox_override("panel", Holo.frame("compact"))
	body.add_child(details_panel)
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 12)
	details_panel.add_child(right)

	comparison = HBoxContainer.new()
	comparison.add_theme_constant_override("separation", 10)
	comparison.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_child(comparison)
	details_scroll = Scroll.new()
	details_scroll.resized.connect(func(): _fit_comparison.call_deferred())
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
	feedback = CommitFeedback.new()
	add_child(feedback)
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
	button.custom_minimum_size = Vector2(124, 52)
	button.add_theme_font_size_override("font_size", 20)
	Style.action(button)
	parent.add_child(button)
	return button

# Inputs are disposable presentation snapshots, never an inventory or transaction owner.
func present(
	operation: String, cards: Array, remaining: int = 0,
	incoming_card: Resource = null, capacity: int = 0, result_context: String = "",
	prices: Dictionary = {}, balance: int = 0
) -> void:
	var opening: bool = not shade.visible or closing
	_stop_motion()
	if opening:
		previous_focus = get_viewport().gui_get_focus_owner()
	revision += 1
	mode = operation
	purchase_prices = prices
	purchase_balance = balance
	incoming = incoming_card
	selected_card = null
	consumed = false
	closing = false
	confirm_button.disabled = mode != "card_batch"
	decline_button.visible = mode in ["replace", "trim", "purchase"]
	decline_button.text = "Keep Current Deck" if mode == "replace" else "Back"
	decline_button.disabled = false
	match mode:
		"card":
			heading.text = "Acquire Card"
			instruction.text = "Choose one card to add to your deck."
			context.text = "%d offered" % cards.size()
			confirm_button.text = "Acquire Card"
		"purchase":
			heading.text = "Trading Outpost · Buy a Card"
			instruction.text = "Select a card to preview it. Salvage is spent on confirmation."
			context.text = "%s · Balance %d Salvage" % [result_context, purchase_balance]
			confirm_button.text = "Confirm Purchase"
		"card_batch":
			heading.text = "Two Tier 1 Cards"
			instruction.text = "Keep both rewards. Select either card to inspect it; confirmation awards both."
			context.text = "Both cards are yours · replace owned cards if the deck is full"
			confirm_button.text = "Keep Both Cards"
		"upgrade":
			heading.text = "Upgrade Card — %d upgrades remaining" % remaining
			instruction.text = "Choose different cards. All available upgrades must be spent."
			context.text = "%d remaining" % remaining
			confirm_button.text = "Apply Upgrade"
		"trim":
			heading.text = "Reduce Deck · %d / %d" % [cards.size(), capacity]
			instruction.text = "Choose one card to remove from this legacy deck."
			context.text = "Card acquisition resumes when the deck reaches the limit."
			confirm_button.text = "Remove Selected Card"
		"replace":
			heading.text = "Replace Card — Deck full: %d/%d cards" % [cards.size(), capacity]
			instruction.text = "Select an owned card to remove in exchange for the reward."
			context.text = "Keep or replace"
			confirm_button.text = "Replace Selected Card"
	if mode != "purchase" and not result_context.is_empty():
		instruction.text = result_context + " · " + instruction.text
	var offers := mode in ["card", "card_batch", "purchase"]
	view_deck_button.visible = offers
	view_deck_button.disabled = false
	body.vertical = offers
	details_panel.custom_minimum_size = Vector2(0, 116 if offers else 0)
	details_panel.size_flags_vertical = Control.SIZE_FILL
	gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery.offer_layout = offers
	gallery.prices = purchase_prices if mode == "purchase" else {}
	gallery.balance = purchase_balance
	gallery.show_toolbar = not offers
	gallery.filters.visible = gallery.show_toolbar
	gallery.category = "All"
	gallery.sort_mode = 0
	gallery.sorting.select(0)
	gallery.set_category("All")
	gallery.set_cards(cards)
	gallery.select_identity("")
	_refresh_details()
	shade.show()
	_fit()
	var seconds := Motion.duration(FADE_TIME)
	shade.modulate.a = 0.0 if opening and seconds > 0.0 else 1.0
	if opening and seconds > 0.0:
		motion = create_tween()
		motion.tween_property(shade, "modulate:a", 1.0, seconds)
	if offers:
		_reveal_offers.call_deferred(revision)
	# Remove keyboard focus from the covered expedition UI.
	get_viewport().gui_release_focus()
	if not gallery.grid.get_children().is_empty():
		gallery.grid.get_child(0).grab_focus()

func select_card(card: Resource) -> void:
	if deck_open or consumed or closing or not shade.visible or not gallery.scroll.allows_activation():
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
	if mode == "purchase" and purchase_prices.has(card.identity_key()):
		var price: int = purchase_prices[card.identity_key()]
		confirm_button.disabled = purchase_balance < price
		context.text = ("%d Salvage · Balance after purchase: %d" % [price, purchase_balance - price]
			if not confirm_button.disabled else "%d Salvage · You have %d" % [price, purchase_balance])
	_refresh_details()

func _reveal_offers(requested: int) -> void:
	if revision == requested and shade.visible: gallery.reveal_visible()


func set_deck_open(value: bool) -> void:
	deck_open = value
	gallery.set_interaction_enabled(not value)


func _refresh_details() -> void:
	for container in [details, comparison]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	compared.clear()
	incoming_portrait = null
	selection = _label("Both cards are included" if mode == "card_batch" else "Select a card", 19)
	selection.add_theme_color_override("font_color", Holo.DEFAULT.edge)
	details.add_child(selection)
	comparison.visible = mode in ["upgrade", "replace"]
	if mode == "replace":
		if selected_card != null: _comparison_card("REMOVE", selected_card, Holo.DEFAULT.hostile)
		incoming_portrait = _comparison_card("RECEIVE", incoming, Holo.DEFAULT.friendly)
		selection.text = selected_card.card_name + " → " + incoming.card_name if selected_card != null else "Choose an owned card to remove"
		_add_effects("RECEIVE", incoming)
		if selected_card != null: _add_effects("REMOVE", selected_card)
	elif selected_card != null:
		var card: Resource = selected_card
		selection.text = card.card_name
		if mode == "upgrade":
			var next: Resource = card.with_upgrade(card.upgrade_level + 1)
			_comparison_card("CURRENT", card, Holo.DEFAULT.muted)
			var arrow := _label("→", 24)
			arrow.custom_minimum_size.x = 26
			arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			comparison.add_child(arrow)
			_comparison_card("AFTER UPGRADE", next, Holo.DEFAULT.friendly)
			var change := _label("Cost %d → %d %s" % [card.cost, next.cost, card.family.capitalize()]
				if card.cost != next.cost else "Cost %d %s" % [next.cost, next.family.capitalize()], 15)
			details.add_child(change)
			var text := RichTextLabel.new()
			text.bbcode_enabled = true
			text.fit_content = true
			text.scroll_active = false
			text.add_theme_font_size_override("normal_font_size", 16)
			text.text = Effects.comparison(next, card)
			details.add_child(text)
		else:
			_add_effects("" if mode != "trim" else "REMOVE", card)
	details_scroll.scroll_vertical = 0
	_fit_comparison.call_deferred()


func _add_effects(role: String, card: Resource) -> void:
	details.add_child(_label("%s%d %s · Tier %d · Upgrade %d" % [
		role + " · " if not role.is_empty() else "", card.cost, card.family.capitalize(), card.tier, card.upgrade_level], 15))
	details.add_child(_label(card.description, 17))


func _comparison_card(role: String, card: Resource, tint: Color) -> Button:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	comparison.add_child(column)
	var label := _label(role, 14)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", tint)
	column.add_child(label)
	var portrait := Portrait.new()
	portrait.card_data = card
	portrait.card_scale = 0.42
	portrait.inspection_enabled = false
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.focus_mode = Control.FOCUS_NONE
	column.add_child(portrait)
	compared.append(portrait)
	return portrait


func _fit_comparison() -> void:
	if compared.is_empty(): return
	var width: float = details_scroll.size.x - (52 if mode == "upgrade" else 22)
	var height: float = body.size.y * 0.57 - 20
	var scale_value := clampf(minf(width / (198 * compared.size()), height / 294.0), 0.32, 0.85)
	for portrait in compared: portrait.set_card_scale(scale_value)


func confirmation_snapshot(kind: String) -> Array:
	var result: Array = []
	if not shade.visible: return result
	for portrait in gallery.grid.get_children():
		if kind == "card_batch" or portrait.card_data == selected_card:
			var card: Resource = portrait.card_data
			if kind == "upgrade": card = card.with_upgrade(card.upgrade_level + 1)
			result.append({"card": card, "rect": portrait.get_global_rect()})
	return result


func accepted(kind: String, snapshot: Array, received: Resource = null) -> void:
	feedback.play(kind, snapshot, received)
	if Motion.duration(CommitFeedback.SECONDS) == 0.0: return
	if kind in ["card", "card_batch", "purchase"]:
		for portrait in gallery.grid.get_children():
			var acquired: bool = kind == "card_batch" or portrait.card_data == selected_card
			Motion.stop(portrait, &"gallery_reveal")
			if acquired:
				portrait.modulate.a = 0.0
			else:
				Motion.start(portrait, &"gallery_reveal").tween_property(portrait, "modulate:a", 0.25, 0.14)


func _confirm() -> void:
	if deck_open or consumed or closing or not shade.visible or (selected_card == null and mode != "card_batch") or confirm_button.disabled:
		return
	consumed = true
	confirm_button.disabled = true
	decline_button.disabled = true
	confirmed.emit(mode, selected_card, revision)

func _decline() -> void:
	if deck_open or consumed or closing or not shade.visible or mode not in ["replace", "trim", "purchase"] or not decline_button.visible:
		return
	consumed = true
	confirm_button.disabled = true
	decline_button.disabled = true
	declined.emit(revision)

func dismiss(immediate: bool = false) -> void:
	revision += 1
	consumed = true
	_stop_motion()
	if immediate: feedback.clear()
	if not shade.visible:
		return
	closing = true
	set_deck_open(false)
	confirm_button.disabled = true
	decline_button.disabled = true
	if immediate or Motion.duration(FADE_TIME) <= 0.0:
		_finish_close()
	else:
		motion = create_tween()
		motion.tween_property(shade, "modulate:a", 0.0, CommitFeedback.SECONDS if feedback.get_child_count() > 0 else FADE_TIME)
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
	Safe.fit(margin, 20)
	_fit_comparison.call_deferred()


func _input(event: InputEvent) -> void:
	var inspection: Node = get_node_or_null("/root/CardInspection")
	if inspection != null and inspection.is_open():
		return
	if not deck_open and shade.visible and event.is_action_pressed("ui_cancel"):
		if mode == "purchase":
			_decline()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	revision += 1
	_stop_motion()
