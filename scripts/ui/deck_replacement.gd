extends VBoxContainer
# RESPONSIBILITY: Own replacement selection and controls. ExpeditionState remains responsible for acquisition.
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const CardGallery = preload("res://scripts/ui/card_gallery.gd")

signal inspect_incoming
signal replace_requested
signal decline_requested

var selected_key: String = ""
var selection: Label
var replace_button: Button
var incoming_portrait: Button
var gallery: VBoxContainer
var owned_cards: Array = []


func configure(incoming_card: Resource, cards: Array, allows_activation: Callable) -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 10)
	owned_cards = cards.duplicate()
	var incoming = HBoxContainer.new()
	incoming.add_theme_constant_override("separation", 20)
	add_child(incoming)
	incoming_portrait = preload("res://scripts/ui/card_portrait.gd").new()
	incoming_portrait.card_data = incoming_card
	incoming_portrait.card_scale = 0.6
	incoming.add_child(incoming_portrait)
	incoming_portrait.pressed.connect(inspect_incoming.emit)
	var explanation = _label(
		"Your deck is full. Replace an existing card to acquire your new card, or keep your current deck.\n\nNew card: "
		+ incoming_card.card_name + "\nChoose a card to remove below.", 22
	)
	explanation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	incoming.add_child(explanation)
	gallery = CardGallery.new()
	gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gallery.custom_minimum_size.y = 250
	add_child(gallery)
	gallery.set_cards(cards)
	gallery.card_selected.connect(select_card)
	selection = _label("Selected: None", 20)
	add_child(selection)
	replace_button = _button("Replace Card", replace_requested.emit, allows_activation)
	replace_button.disabled = true
	_button("Keep Current Deck", decline_requested.emit, allows_activation)


func select_card(card: Resource) -> void:
	for owned in owned_cards:
		if owned.identity_key() == card.identity_key():
			selected_key = card.identity_key()
			selection.text = (
				"Selected: %s · %s · Tier %d · Upgrade %d"
				% [card.card_name, card.family.capitalize(), card.tier, card.upgrade_level]
			)
			replace_button.disabled = false
			return


func _label(text: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, callback: Callable, allows_activation: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size", 22)
	Presentation.action(button)
	button.pressed.connect(
		func():
			if allows_activation.call():
				callback.call()
	)
	add_child(button)
	return button
