extends CanvasLayer

const Holo = preload("res://scripts/ui/holographic/skin.gd")
const HoloMotion = preload("res://scripts/ui/holographic/motion.gd")

# RESPONSIBILITY: Present owned card identities, capacity and inspection without modifying the deck.
signal closed
const Composition = preload("res://scripts/ui/deck_composition.gd")
const Safe = preload("res://scripts/ui/card_screen_margins.gd")
const Gallery = preload("res://scripts/ui/card_gallery.gd")
const Inspector = preload("res://scripts/ui/card_inspector.gd")
const Library = preload("res://scripts/cards/card_library.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var shade: ColorRect
var gallery: VBoxContainer
var inspector: CanvasLayer
var title: Label
var return_button: Button
var previous_focus: Control
var composition: VBoxContainer
var margin: MarginContainer


func _ready() -> void:
	layer = 110
	shade = ColorRect.new()
	shade.color = Holo.DEFAULT.surface_depth
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(margin)
	shade.resized.connect(func(): Safe.fit(margin, 20))
	Safe.fit(margin, 20)
	Holo.plate(margin, Holo.frame("dialog"))
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var header = HBoxContainer.new()
	column.add_child(header)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_font_override("font", Style.UI_FONT)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_color", Holo.DEFAULT.edge)
	header.add_child(title)
	return_button = Button.new()
	return_button.text = "Return"
	return_button.custom_minimum_size = Vector2(140, 52)
	Style.action(return_button)
	return_button.pressed.connect(dismiss)
	header.add_child(return_button)
	composition = Composition.new()
	column.add_child(composition)
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
		ship.ship_name + " · Starting Deck"
	)


func show_cards(values: Array, caption: String, capacity: int = 0, over_reward: bool = false) -> void:
	previous_focus = get_viewport().gui_get_focus_owner()
	inspector.dismiss()
	layer = 150 if over_reward else 110
	inspector.layer = layer + 10
	title.text = caption
	composition.display(values, capacity)
	gallery.set_cards(values)
	shade.show()
	HoloMotion.reveal(shade, 0.32)
	_reveal_cards.call_deferred()
	return_button.grab_focus()


func _reveal_cards() -> void:
	if shade.visible: gallery.reveal_visible()


func dismiss() -> void:
	if not shade.visible: return
	HoloMotion.restore_panel(shade)
	inspector.dismiss()
	shade.hide()
	closed.emit()
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()


func _input(event: InputEvent) -> void:
	var inspection: Node = get_node_or_null("/root/CardInspection")
	if inspection != null and inspection.is_open():
		return
	if not shade.visible or inspector.shade.visible: return
	if event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control] = [return_button]
		for control in gallery.filters.get_children() + gallery.grid.get_children():
			if control is Button and control.is_visible_in_tree(): controls.append(control)
		var step := 1 if event.is_action_pressed("ui_focus_next") else -1
		controls[posmod(controls.find(get_viewport().gui_get_focus_owner()) + step, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()
