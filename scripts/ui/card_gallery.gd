extends VBoxContainer
signal card_selected(card: Resource)
const Portrait = preload("res://scripts/ui/card_portrait.gd")
const Scroll = preload("res://scripts/ui/encounter_scroll.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var cards: Array[Resource] = []
var visible_cards: Array[Resource] = []
var category: String = "All"
var show_toolbar: bool = true
var sort_mode: int = 0
var filters: HFlowContainer
var sorting: OptionButton
var scroll: ScrollContainer
var grid: GridContainer
var count: Label

func _ready() -> void:
	add_theme_constant_override("separation", 12)
	filters = HFlowContainer.new()
	filters.add_theme_constant_override("h_separation", 8)
	add_child(filters)
	filters.visible = show_toolbar
	for value in ["All", "Attack", "Defense", "Production", "Utility"]:
		var button = Button.new()
		button.text = value
		button.toggle_mode = true
		button.button_pressed = value == category
		button.custom_minimum_size = Vector2(92, 48)
		Style.action(button)
		filters.add_child(button)
		button.pressed.connect(set_category.bind(value))
	sorting = OptionButton.new()
	sorting.custom_minimum_size = Vector2(140, 48)
	sorting.tooltip_text = "Sort cards"
	Style.action(sorting)
	for value in ["Name", "Cost", "Rarity", "Family"]: sorting.add_item(value)
	sorting.item_selected.connect(func(index): sort_mode = index; scroll.scroll_vertical = 0; rebuild())
	filters.add_child(sorting)
	count = Label.new()
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_size_override("font_size", 18)
	filters.add_child(count)
	scroll = Scroll.new()
	scroll.explicit_touch_drag = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	grid = GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	var centering = CenterContainer.new()
	centering.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centering.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	scroll.add_child(centering)
	centering.add_child(grid)
	scroll.resized.connect(_fit)
	rebuild()

static func matches(card: Resource, value: String) -> bool:
	return matches_effects(card.effects, value) or (value == "Utility" and card.play_again)

static func matches_effects(effects: Dictionary, value: String) -> bool:
	var conditional: Dictionary = effects.get("conditional", {})
	if not conditional.is_empty() and (matches_effects(conditional.get("then", {}), value) or matches_effects(conditional.get("else", {}), value)): return true
	match value:
		"Attack": return effects.has("damage") or effects.has("break_shields") or effects.has("shield_collapse") or effects.has("shield_collapse_below")
		"Defense": return effects.has("hull") or effects.has("shields") or effects.has("swap_shields")
		"Production": return effects.has("production_other") or effects.has("synthesizer") or effects.has("reactor") or effects.has("quarters") or effects.has("enemy_production")
		"Utility": return effects.has("drain") or effects.has("steal") or effects.has("sabotage") or effects.has("random_gain") or effects.has("random_gain_other") or effects.has("random_gain_range_other") or effects.has("materials") or effects.has("energy") or effects.has("crew") or effects.has("swap_resource") or effects.has("enemy_production")
	return true

func set_cards(values: Array) -> void:
	cards.assign(values)
	if is_node_ready():
		scroll.scroll_vertical = 0
		rebuild()

func set_category(value: String) -> void:
	category = value
	for child in filters.get_children():
		if child is Button and not child is OptionButton: child.button_pressed = child.text == value
	scroll.scroll_vertical = 0
	rebuild()

func rebuild() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	visible_cards.clear()
	for card in cards:
		if matches(card, category): visible_cards.append(card)
	visible_cards.sort_custom(func(a, b):
		var first = [a.card_name, a.cost, a.tier, a.family][sort_mode]
		var second = [b.card_name, b.cost, b.tier, b.family][sort_mode]
		return a.card_name < b.card_name if first == second else first < second)
	for card in visible_cards:
		var portrait = Portrait.new()
		portrait.card_data = card
		grid.add_child(portrait)
		portrait.pressed.connect(func():
			if scroll.allows_activation(): card_selected.emit(card))
	count.text = "%d / %d cards" % [visible_cards.size(), cards.size()]
	_fit.call_deferred()

func _fit() -> void:
	if not is_instance_valid(grid): return
	grid.columns = maxi(1, floori((scroll.size.x - 16 + 18) / (198 + 18)))

func set_interaction_enabled(enabled: bool) -> void:
	scroll.set_process_input(enabled)
	scroll.touch_index = -1
	scroll.dragged = false
