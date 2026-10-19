extends CanvasLayer

# RESPONSIBILITY: Present owned card identities, capacity and inspection without modifying the deck.
const Gallery = preload("res://scripts/ui/card_gallery.gd")
const Inspector = preload("res://scripts/ui/card_inspector.gd")
const Library = preload("res://scripts/card_library.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var shade: ColorRect
var gallery: VBoxContainer
var inspector: CanvasLayer
var title: Label
var return_button: Button
var previous_focus: Control


func _ready() -> void:
	layer = 110
	shade = ColorRect.new()
	shade.color = Color("101d2b")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	shade.add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)
	return_button = Button.new()
	return_button.text = "Return"
	return_button.custom_minimum_size = Vector2(140, 52)
	Style.action(return_button)
	return_button.pressed.connect(dismiss)
	header.add_child(return_button)
	gallery = Gallery.new()
	gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(gallery)
	inspector = Inspector.new()
	add_child(inspector)
	inspector.opened.connect(func(): gallery.set_interaction_enabled(false))
	inspector.closed.connect(func(): gallery.set_interaction_enabled(true))
	gallery.card_selected.connect(func(card): inspector.present(card, null, true))
	shade.hide()


func show_ship(ship: Resource) -> void:
	show_cards(
		ship.starting_cards if not ship.starting_cards.is_empty() else Library.CARDS,
		ship.ship_name + " · Starting deck · Read only"
	)


func show_cards(values: Array, caption: String) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	inspector.dismiss()
	title.text = caption
	gallery.set_cards(values)
	shade.show()
	return_button.grab_focus()


func dismiss() -> void:
	inspector.dismiss()
	shade.hide()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()


func _input(event: InputEvent) -> void:
	var inspection: Node = get_node_or_null("/root/CardInspection")
	if inspection != null and inspection.is_open():
		return
	if shade.visible and not inspector.shade.visible and event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
