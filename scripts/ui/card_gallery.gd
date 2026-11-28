extends VBoxContainer

# RESPONSIBILITY: Display a filterable, scrollable card gallery and emit the selected identity.
signal card_selected(card: Resource)
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Accent = preload("res://scripts/ui/battle_signal.gd")
const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Portrait = preload("res://scripts/ui/card_portrait.gd")
const Scroll = preload("res://scripts/ui/encounter_scroll.gd")
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var cards: Array[Resource] = []
var visible_cards: Array[Resource] = []
var category: String = "All"
var offer_layout := false
var prices: Dictionary = {}
var balance := 0
var empty: Label
var show_toolbar: bool = true
var inspection_enabled: bool = true
var selected_identity: String = ""
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
	for value in ["Name", "Cost", "Rarity", "Family"]:
		sorting.add_item(value)
	sorting.item_selected.connect(
		func(index):
			sort_mode = index
			scroll.scroll_vertical = 0
			rebuild()
	)
	filters.add_child(sorting)
	count = Label.new()
	count.add_theme_color_override("font_color", Holo.DEFAULT.muted)
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
	var clearance := MarginContainer.new()
	clearance.add_theme_constant_override("margin_top", 6)
	clearance.add_theme_constant_override("margin_bottom", 6)
	centering.add_child(clearance)
	var content := VBoxContainer.new()
	clearance.add_child(content)
	content.add_child(grid)
	empty = Label.new()
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.add_theme_font_size_override("font_size", 19)
	empty.add_theme_color_override("font_color", Holo.DEFAULT.muted)
	content.add_child(empty)
	scroll.resized.connect(_fit)
	rebuild()


static func matches(card: Resource, value: String) -> bool:
	return matches_effects(card.effects, value) or (value == "Utility" and card.play_again)


static func matches_effects(effects: Dictionary, value: String) -> bool:
	var conditional: Dictionary = effects.get("conditional", {})
	if (
		not conditional.is_empty()
		and (
			matches_effects(conditional.get("then", {}), value)
			or matches_effects(conditional.get("else", {}), value)
		)
	):
		return true
	match value:
		"Attack":
			return (
				effects.has("damage")
				or effects.has("break_shields")
				or effects.has("shield_collapse")
				or effects.has("shield_collapse_below")
			)
		"Defense":
			return effects.has("hull") or effects.has("shields") or effects.has("swap_shields")
		"Production":
			return (
				effects.has("production_other")
				or effects.has("synthesizer")
				or effects.has("reactor")
				or effects.has("quarters")
				or effects.has("enemy_production")
			)
		"Utility":
			return (
				effects.has("drain")
				or effects.has("steal")
				or effects.has("sabotage")
				or effects.has("random_sabotage")
				or effects.has("random_gain")
				or effects.has("random_gain_other")
				or effects.has("random_gain_range_other")
				or effects.has("materials")
				or effects.has("energy")
				or effects.has("crew")
				or effects.has("swap_resource")
				or effects.has("enemy_production")
			)
	return true


func set_cards(values: Array) -> void:
	cards.assign(values)
	if is_node_ready():
		scroll.scroll_vertical = 0
		rebuild()


func set_category(value: String) -> void:
	category = value
	for child in filters.get_children():
		if child is Button and not child is OptionButton:
			child.button_pressed = child.text == value
	scroll.scroll_vertical = 0
	rebuild()


func rebuild() -> void:
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	visible_cards.clear()
	for card in cards:
		if matches(card, category):
			visible_cards.append(card)
	if not offer_layout: visible_cards.sort_custom(
		func(a, b):
			var first = [a.card_name, a.cost, a.tier, a.family][sort_mode]
			var second = [b.card_name, b.cost, b.tier, b.family][sort_mode]
			return a.card_name < b.card_name if first == second else first < second
	)
	for card in visible_cards:
		var portrait = Portrait.new()
		portrait.card_data = card
		portrait.inspection_enabled = inspection_enabled
		if prices.has(card.identity_key()):
			portrait.price = prices[card.identity_key()]
			portrait.purchase_balance = balance
		grid.add_child(portrait)
		portrait.pressed.connect(
			func():
				if scroll.allows_activation():
					card_selected.emit(card)
		)
	select_identity(selected_identity)
	count.text = "%d / %d cards" % [visible_cards.size(), cards.size()]
	empty.visible = visible_cards.is_empty()
	empty.text = "No cards in this collection" if cards.is_empty() else "No cards match this filter"
	_fit.call_deferred()


func _fit() -> void:
	if not is_instance_valid(grid):
		return
	var width := maxf(1.0, scroll.size.x - 16)
	var gap := float(grid.get_theme_constant("h_separation"))
	var columns := maxi(1, floori((width + gap) / (190.0 + gap)))
	if offer_layout:
		columns = mini(maxi(1, visible_cards.size()), maxi(1, floori((width + gap) / 157.0)))
	grid.columns = columns
	var ratio := minf(1.08 if offer_layout else 1.0, (width - gap * (columns - 1)) / (198.0 * columns))
	if offer_layout:
		ratio = minf(ratio, maxf(0.70, (scroll.size.y - (39 if not prices.is_empty() else 12)) / 294.0))
	for portrait in grid.get_children():
		portrait.set_card_scale(clampf(ratio, 0.65, 1.08))


func reveal_visible() -> void:
	var seconds := Motion.duration(0.27)
	if seconds <= 0.0 or not is_visible_in_tree(): return
	_fit()
	var cards_per_row := grid.columns
	var row_extent := maxf(1, grid.get_child(0).custom_minimum_size.y + 18) if grid.get_child_count() > 0 else 1.0
	var limit := mini(grid.get_child_count(), cards_per_row * maxi(1, ceili(scroll.size.y / row_extent)))
	for index in limit:
		var portrait: Control = grid.get_child(index)
		portrait.modulate.a = 0.0
		var animation := Motion.start(portrait, &"gallery_reveal")
		var delay := index * (0.052 if offer_layout else 0.020)
		animation.tween_property(portrait, "modulate:a", 1.0, seconds).set_delay(delay)
		if offer_layout:
			var card: Resource = portrait.card_data
			var ink := Holo.family(card.family)
			if card.tier == 2: ink = Holo.DEFAULT.rarity_two
			if card.tier == 3: ink = Holo.DEFAULT.rarity_three
			animation.parallel().tween_callback(Accent.sweep.bind(portrait.rendering, ink,
				Motion.duration(0.24, card.tier > 1))).set_delay(delay + 0.05)


func set_interaction_enabled(enabled: bool) -> void:
	scroll.set_process_input(enabled)
	scroll.touch_index = -1
	scroll.dragged = false


func select_identity(key: String) -> void:
	selected_identity = key
	for portrait in grid.get_children():
		portrait.set_selected(portrait.card_data.identity_key() == key)
