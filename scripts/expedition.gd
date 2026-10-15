extends Control
# Owns the run and routes between the existing battle scene and one reusable text UI.
const State = preload("res://scripts/expedition_state.gd")
const BOARD = preload("res://scenes/board_3d.tscn")
@export var rules: Resource = preload("res://encounters/expedition_rules.tres")
var selected_ship: int = 0
var state: Resource
var battle: Node
var view: VBoxContainer
var stats: Label
var pending: Label
var jump_button: Button
var title: Label
var ui: MarginContainer
var view_kind: String = ""
var selected_encounter: int = -1

func _ready() -> void:
	_build_ui()
	start_expedition()

func _build_ui() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = Color(0.025, 0.04, 0.065)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	ui = MarginContainer.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		ui.add_theme_constant_override("margin_" + edge, 24)
	add_child(ui)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	ui.add_child(column)
	title = _label("", 28)
	column.add_child(title)
	stats = _label("", 20)
	column.add_child(stats)
	pending = _label("", 17)
	column.add_child(pending)
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	view = VBoxContainer.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 10)
	scroll.add_child(view)
	jump_button = Button.new()
	jump_button.text = "Jump to Next System — free"
	jump_button.custom_minimum_size.y = 52
	jump_button.add_theme_font_size_override("font_size", 21)
	jump_button.pressed.connect(_jump)
	column.add_child(jump_button)

func _label(text: String, font_size: int = 20) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, callback: Callable, disabled: bool = false, height: float = 64) -> Button:
	var button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 20)
	button.disabled = disabled
	button.pressed.connect(callback)
	view.add_child(button)
	return button

func _clear(kind: String) -> void:
	view_kind = kind
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
	ui.show()
	title.text = state.system_name + " — " + state.ship().ship_name
	stats.text = "Hull %d/%d  ·  Salvage %d  ·  Fabricator %d / Reactor %d / Hangar %d  ·  Cards acquired %d" % [
		state.hull, state.ship().hull_capacity, state.salvage, state.production("synthesizer"),
		state.production("reactor"), state.production("quarters"), state.acquired_cards.size()]
	pending.text = "Next battle: " + state.pending_description()
	jump_button.disabled = not state.pending_choice.is_empty() or state.hull <= 0
	jump_button.visible = state.hull > 0

func start_expedition() -> void:
	state = State.new()
	state.start(selected_ship, rules)
	# No mandatory opening encounter: every battle returns here through victory.
	show_system()

func show_system() -> void:
	if not state.pending_choice.is_empty():
		show_outcome()
		return
	_clear("system")
	if state.hull <= 0:
		view.add_child(_label("Expedition ended — your ship was lost.", 26))
		_button("Start a new expedition", _restart)
		_button("Choose another ship", _exit)
		return
	view.add_child(_label("Choose any encounter. Completed encounters cannot be revisited."))
	for index in range(state.encounters.size()):
		var encounter: Dictionary = state.encounters[index]
		var prefix: String = "Battle" if encounter.kind == "battle" else "PoI"
		var suffix: String = " — Completed" if encounter.completed else ""
		_button("%d. %s · %s%s" % [index + 1, prefix, encounter.title, suffix], visit.bind(index), encounter.completed)
	view.add_child(_label("Travel is free. PoIs offer one approach or service per visit. Jumping preserves Hull, Salvage, cards, upgrades and pending bonuses.", 17))

func visit(index: int) -> void:
	if not state.can_visit(index):
		return
	if state.encounters[index].kind == "battle":
		start_battle(index)
	else:
		show_poi(index)

func show_poi(index: int) -> void:
	selected_encounter = index
	_clear("poi")
	var poi: Resource = state.encounters[index].poi
	view.add_child(_label(poi.title + " — " + poi.description, 24))
	for slot in range(poi.approaches.size()):
		var approach: Resource = poi.approaches[slot]
		var reason: String = state.locked_reason(approach)
		var requirement: String = "No production requirement" if approach.requirement.is_empty() else "%s ≥%d" % [state.LABELS[approach.requirement], approach.minimum_production]
		var cost: String = "Free" if approach.salvage_cost == 0 else "%d Salvage" % approach.salvage_cost
		var text: String = "%s · %s · %s\n%d%%: %s" % [approach.title, requirement, cost, roundi(approach.success_chance * 100), state.describe_outcome(approach.success)]
		if approach.success_chance < 1:
			text += "\n%d%%: %s" % [roundi((1.0 - approach.success_chance) * 100), state.describe_outcome(approach.failure)]
		if not reason.is_empty():
			text += "\nLOCKED — " + reason
		_button(text, _approach.bind(index, slot), not reason.is_empty(), 100)
	_button("Back to encounters", show_system)

func _approach(index: int, slot: int) -> void:
	if state.resolve_approach(index, slot):
		show_outcome()

func show_outcome() -> void:
	_clear("outcome")
	view.add_child(_label(state.last_outcome, 22))
	match state.pending_choice:
		"card":
			view.add_child(_label("Choose exactly one card. It adds a draw opportunity to the shared pool; existing cards remain.", 18))
			for index in range(state.card_offers.size()):
				_button(_card_text(state.card_offers[index]), _choose_card.bind(index), false, 110)
		"upgrade":
			view.add_child(_label("Choose a player card to upgrade. Costs fall; effects and enemy copies stay unchanged.", 18))
			for card in state.upgrade_candidates():
				var reduction: int = mini(card.upgrade_cost_reduction, card.cost - 1)
				_button(_card_text(card) + "\nUpgrade: cost −%d" % reduction, _upgrade.bind(card.identity_key()), false, 110)
		"resource", "production":
			var keys: Array = state.RESOURCES if state.pending_choice == "resource" else state.PRODUCTION
			for key in keys:
				_button("+%d %s" % [state.choice_amount, state.LABELS[key]], _attribute.bind(key))
		_:
			if state.hull <= 0:
				view.add_child(_label("The damage destroyed your ship. This expedition is over.", 22))
			_button("Continue", show_system)

func _card_text(card: Resource) -> String:
	var rarity: String = ["Common", "Uncommon", "Rare"][clampi(card.tier - 1, 0, 2)]
	return "%s%s · %s · Cost %d %s · %s\n%s" % [card.card_name,
		" +%d" % card.upgrade_level if card.upgrade_level > 0 else "",
		card.family.capitalize(), card.cost, card.family.capitalize(), rarity, card.description]

func _choose_card(index: int) -> void:
	if state.choose_card(index): show_outcome()

func _upgrade(key: String) -> void:
	if state.choose_upgrade(key): show_outcome()

func _attribute(key: String) -> void:
	if state.choose_attribute(key): show_outcome()

func _jump() -> void:
	if state.generate_system():
		show_system()

func start_battle(index: int) -> void:
	if not state.can_visit(index) or state.encounters[index].kind != "battle":
		return
	var encounter: Dictionary = state.encounters[index]
	ui.hide()
	view_kind = "battle"
	battle = BOARD.instantiate()
	battle.expedition = state
	battle.expedition_encounter = index
	battle.setup_settings = {"player_ship":state.player_ship, "enemy_ship":encounter.enemy, "modifier":encounter.modifier}
	battle.expedition_continue.connect(_battle_finished)
	battle.expedition_restart.connect(_restart)
	battle.expedition_exit.connect(_exit)
	add_child(battle)

func _battle_finished() -> void:
	state.sync_battle(battle)
	state.active_battle = -1
	_remove_battle()
	show_system()

func _remove_battle() -> void:
	if is_instance_valid(battle):
		remove_child(battle)
		battle.queue_free()
	battle = null

func _restart() -> void:
	_remove_battle()
	start_expedition()

func _exit() -> void:
	var setup = load("res://scenes/battle_setup.tscn").instantiate()
	setup.initial_settings = {"player_ship":selected_ship}
	get_parent().add_child(setup)
	get_tree().current_scene = setup
	queue_free()
