extends Control
# UI routing only; ExpeditionState owns all rewards, requirements and progression.
const State = preload("res://scripts/expedition_state.gd")
const BOARD = preload("res://scenes/board_3d.tscn")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Tile = preload("res://scripts/ui/encounter_tile.gd")
const TouchScroll = preload("res://scripts/ui/encounter_scroll.gd")
const Header = preload("res://scenes/poi_header.tscn")
@export var rules: Resource = preload("res://encounters/expedition_rules.tres")
## Android font availability varies; readable abbreviations are the reliable default.
@export var text_icons_on_android: bool = true
var approach_note: Label
var repair_selector: HSlider
var service_confirmation_revision: int = -1
var return_to_outpost: bool = false
var selected_ship: int = 0
var state: Resource
var battle: Node
var view: VBoxContainer
var stats: Label
var pending: Label
var jump_button: Button
var return_button: Button
var confirm_button: Button
var title: Label
var ui: MarginContainer
var scroll: ScrollContainer
var header: PanelContainer
var footer: HBoxContainer
var more_hint: Label
var progress: ProgressBar
var grid: GridContainer
var selected_approach: int = -1
var approach_buttons: Array[Button] = []
var view_kind: String = ""
var selected_encounter: int = -1

func _ready() -> void:
	_build_ui()
	start_expedition()

func _build_ui() -> void:
	var backdrop = ColorRect.new()
	backdrop.color = Color("0e1a28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	ui = MarginContainer.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		ui.add_theme_constant_override("margin_" + edge, 16)
	add_child(ui)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	ui.add_child(column)
	title = _label("", 30)
	column.add_child(title)
	stats = _label("", 20)
	column.add_child(stats)
	pending = _label("", 18)
	column.add_child(pending)
	header = Header.instantiate()
	column.add_child(header)
	header.return_requested.connect(show_system)
	return_button = header.return_button
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 8
	progress.show_percentage = false
	progress.add_theme_stylebox_override("background", Presentation.style(Color("394653")))
	progress.add_theme_stylebox_override("fill", Presentation.style(Presentation.COLORS.special, true))
	column.add_child(progress)
	scroll = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	view = VBoxContainer.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 10)
	scroll.add_child(view)
	more_hint = _label("More options below — swipe or scroll", 16)
	more_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(more_hint)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	var shared = _label("All approaches grant +1 FTL Drive charge", 20)
	approach_note = shared
	shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(shared)
	repair_selector = HSlider.new()
	repair_selector.custom_minimum_size = Vector2(180, 60)
	repair_selector.step = 1
	repair_selector.value_changed.connect(_repair_selection_changed)
	footer.add_child(repair_selector)
	confirm_button = Button.new()
	confirm_button.text = "Confirm Approach"
	confirm_button.custom_minimum_size = Vector2(330, 60)
	confirm_button.add_theme_font_size_override("font_size", 23)
	Presentation.action(confirm_button, true)
	confirm_button.pressed.connect(_confirm_approach)
	footer.add_child(confirm_button)
	jump_button = Button.new()
	jump_button.custom_minimum_size.y = 56
	jump_button.add_theme_font_size_override("font_size", 21)
	Presentation.action(jump_button)
	jump_button.pressed.connect(_jump)
	column.add_child(jump_button)

func _process(_delta: float) -> void:
	if not ui.visible: return
	var bar = scroll.get_v_scroll_bar()
	more_hint.visible = bar.max_value > bar.page + 1 and bar.value + bar.page < bar.max_value - 1
	if view_kind == "system" and is_instance_valid(grid):
		# Fit six tiles plus the separate service button in the existing scroll area.
		var available_height: float = scroll.size.y - 12
		for child in view.get_children():
			if child != grid: available_height -= child.size.y + view.get_theme_constant("separation")
		for tile in grid.get_children(): tile.minimum_height = maxf(100, available_height / 2)

func _label(text: String, font_size: int = 20) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(text: String, callback: Callable, disabled: bool = false, height: float = 64) -> Button:
	var button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 22)
	button.disabled = disabled
	Presentation.action(button)
	button.pressed.connect(func():
		if scroll.allows_activation(): callback.call())
	view.add_child(button)
	return button

func _grid(columns: int) -> GridContainer:
	var result = GridContainer.new()
	result.columns = columns
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.add_theme_constant_override("h_separation", 12)
	result.add_theme_constant_override("v_separation", 12)
	view.add_child(result)
	grid = result
	return result

func _tile(parent: Node, heading: String, details: String, color: Color, callback: Callable, disabled: bool = false, centered: bool = false) -> Button:
	var button = Tile.new()
	button.configure(heading, details, color, centered)
	button.disabled = disabled
	button.refresh_style()
	button.pressed.connect(func():
		if button.is_inside_tree() and scroll.allows_activation() and not button.disabled: callback.call())
	parent.add_child(button)
	return button

func _icon(key: String) -> String:
	return Presentation.icon(key, get_theme_default_font(), text_icons_on_android and OS.has_feature("android"))

func _clear(kind: String) -> void:
	view_kind = kind
	selected_approach = -1
	service_confirmation_revision = -1
	repair_selector.hide()
	repair_selector.set_value_no_signal(0)
	approach_buttons.clear()
	grid = null
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
	scroll.scroll_vertical = 0
	ui.show()
	header.visible = kind == "poi"
	return_button.visible = kind == "poi"
	footer.visible = kind == "poi"
	confirm_button.disabled = true
	title.visible = kind != "poi"
	progress.visible = kind == "system"
	progress.max_value = state.required_ftl_charge
	progress.value = state.ftl_charge
	title.text = "System Encounters — " + state.system_name if kind == "system" else "Encounter Result"
	stats.text = "%s · Hull %d/%d · Salvage %d · Fabricator %d / Reactor %d / Hangar %d" % [
		state.ship().ship_name, state.hull, state.ship().hull_capacity, state.salvage,
		state.production("synthesizer"), state.production("reactor"), state.production("quarters")]
	pending.text = "Next battle: " + state.pending_description()
	pending.visible = state.pending_description() != "None"
	jump_button.text = "FTL Drive %d / %d · %s" % [state.ftl_charge, state.required_ftl_charge,
		"Jump to Next System" if state.ftl_charge >= state.required_ftl_charge else "Requires %d more charge" % (state.required_ftl_charge - state.ftl_charge)]
	jump_button.disabled = not state.can_jump()
	jump_button.visible = state.hull > 0

func start_expedition() -> void:
	state = State.new()
	state.start(selected_ship, rules)
	show_system()

func show_system() -> void:
	if not state.pending_choice.is_empty():
		show_outcome()
		return
	return_to_outpost = false
	_clear("system")
	if state.hull <= 0:
		view.add_child(_label("Expedition ended — your ship was lost.", 26))
		_button("Start a new expedition", _restart)
		_button("Choose another ship", _exit)
		return
	var cards = _grid(3)
	for index in range(state.encounters.size()):
		var encounter: Dictionary = state.encounters[index]
		var category: String = Presentation.classification(encounter)
		var key: String = "battle" if encounter.kind == "battle" else Presentation.poi_key(encounter.poi)
		var descriptor: String = {"ordinary":"Ordinary PoI", "hazard":"Hazardous PoI", "battle":"Enemy", "special":"Anomalous PoI"}[category]
		if encounter.kind == "battle": descriptor = ["Enemy", "Elite enemy", "Boss enemy"][state.enemy_profile(encounter).enemy_rank]
		var status: String = "Completed" if encounter.completed else "%s · +%d FTL" % [descriptor, state.encounter_charge(index)]
		_tile(cards, _icon(key) + "\n" + encounter.title, status, Presentation.COLORS[category], visit.bind(index), encounter.completed, true)

	if not state.service.is_empty():
		_button("Trading Outpost · Service station · No travel FTL · Free to return", visit.bind(state.SERVICE_INDEX))

func visit(index: int) -> void:
	if not state.can_visit(index): return
	if state.encounter_at(index).kind == "battle": start_battle(index)
	else: show_poi(index)

func approach_text(approach: Resource) -> String:
	var lines: Array[String] = []
	if not approach.requirement.is_empty():
		lines.append("%s ≥%d (ship: %d)" % [state.LABELS[approach.requirement], approach.minimum_production, state.production(approach.requirement)])
	if approach.salvage_cost > 0: lines.append("Cost: %d Salvage" % approach.salvage_cost)
	lines.append("%s%% — %s" % [String.num(approach.success_chance * 100, 2), state.describe_outcome(approach.success)])
	if approach.success_chance < 1:
		lines.append("%s%% — %s" % [String.num((1.0 - approach.success_chance) * 100, 2), state.describe_outcome(approach.failure)])
	var reason: String = state.locked_reason(approach)
	if not reason.is_empty(): lines.append("LOCKED — " + reason)
	return "\n".join(lines)

func show_poi(index: int) -> void:
	if index == state.SERVICE_INDEX:
		show_outpost()
		return
	selected_encounter = index
	_clear("poi")
	var poi: Resource = state.encounter_at(index).poi
	approach_note.text = "All approaches grant +1 FTL Drive charge"
	confirm_button.text = "Confirm Approach"
	header.configure(poi)
	var options = _grid(2)
	for slot in range(poi.approaches.size()):
		var approach: Resource = poi.approaches[slot]
		var key: String = approach.requirement if not approach.requirement.is_empty() else Presentation.poi_key(poi)
		var button = _tile(options, _icon(key) + "  " + approach.title, approach_text(approach),
			Presentation.COLORS[Presentation.classification(state.encounter_at(index))], _select_approach.bind(slot), not state.locked_reason(approach).is_empty())
		approach_buttons.append(button)
	if state.can_survey(index):
		var survey = _tile(options, _icon("approach") + "  Navigation survey", "No loot. Next battle: " + state.describe_modifiers(state.rules.survey_penalty), Presentation.COLORS.special, _select_approach.bind(-2))
		approach_buttons.append(survey)

func show_outpost() -> void:
	if not state.can_visit(state.SERVICE_INDEX):
		if not state.pending_choice.is_empty(): show_outcome()
		else: show_system()
		return
	return_to_outpost = false
	selected_encounter = state.SERVICE_INDEX
	_clear("poi")
	service_confirmation_revision = state.service_revision
	header.configure(state.service.poi)
	# Station choices do not need the travel bar or a long pending-combat ledger.
	jump_button.hide()
	pending.hide()
	approach_note.text = "Service station · No travel FTL · Free to leave"
	confirm_button.text = "Purchase Service"
	var options = _grid(2)
	for slot in range(state.service.poi.approaches.size()):
		var approach: Resource = state.service.poi.approaches[slot]
		var details: String
		if approach.success.hull > 0:
			details = "1 Salvage / Hull · Select repair amount"
		else:
			details = "%d Salvage · %s" % [state.service_cost(slot), state.describe_outcome(approach.success)]
		var reason: String = state.service_locked_reason(slot)
		if not reason.is_empty(): details += "\nLOCKED — " + reason
		approach_buttons.append(_tile(options, approach.title, details, Presentation.COLORS.special, _select_approach.bind(slot), not reason.is_empty()))
	# Wrapped labels can retain a tall temporary minimum after a choice screen.
	ui.set_deferred("size", size)

func _repair_selection_changed(_value: float) -> void:
	if selected_encounter != state.SERVICE_INDEX or not state.service_is_repair(selected_approach) or view_kind != "poi": return
	var amount: int = int(repair_selector.value)
	approach_note.text = "+%d Hull → %d/%d · Cost %d Salvage" % [amount, state.hull + amount, state.ship().hull_capacity, state.service_cost(selected_approach, amount)]
	confirm_button.disabled = amount <= 0 or amount > state.station_repair_limit() or service_confirmation_revision != state.service_revision

func _purchase_finished() -> void:
	if not state.pending_choice.is_empty():
		show_outcome()
	elif return_to_outpost:
		show_outpost()
		approach_note.text = "Purchase complete · No travel FTL · Free to leave"
	else:
		show_outcome()

func _select_approach(slot: int) -> void:
	if view_kind != "poi" or not state.can_visit(selected_encounter): return
	if selected_encounter == state.SERVICE_INDEX:
		if not state.service_locked_reason(slot).is_empty(): return
	elif slot == -2:
		if not state.can_survey(selected_encounter): return
	else:
		var poi: Resource = state.encounter_at(selected_encounter).poi
		if slot < 0 or slot >= poi.approaches.size() or not state.locked_reason(poi.approaches[slot]).is_empty(): return
	selected_approach = slot
	for index in range(approach_buttons.size()):
		var button = approach_buttons[index]
		button.selected = index == slot or (slot == -2 and index == approach_buttons.size() - 1)
		button.refresh_style()
	confirm_button.disabled = false
	if selected_encounter == state.SERVICE_INDEX:
		repair_selector.visible = state.service_is_repair(slot)
		if state.service_is_repair(slot):
			repair_selector.max_value = state.station_repair_limit()
			repair_selector.set_value_no_signal(0)
			_repair_selection_changed(0)
		else:
			approach_note.text = "Cost %d Salvage · Balance after purchase: %d" % [state.service_cost(slot), state.salvage - state.service_cost(slot)]

func _confirm_approach() -> void:
	if view_kind != "poi" or confirm_button.disabled: return
	confirm_button.disabled = true
	if selected_approach == -2: _survey(selected_encounter)
	elif selected_approach >= 0: _approach(selected_encounter, selected_approach)

func _survey(index: int) -> void:
	if state.survey(index): show_outcome()

func _approach(index: int, slot: int) -> void:
	if index == state.SERVICE_INDEX:
		if state.purchase_service(slot, service_confirmation_revision, int(repair_selector.value)):
			return_to_outpost = true
			_purchase_finished()
		return
	if state.resolve_approach(index, slot): show_outcome()

func show_outcome() -> void:
	_clear("outcome")
	var result = PanelContainer.new()
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result.custom_minimum_size.x = minf(900, ui.size.x - 32)
	result.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	result.add_child(_label(state.last_outcome, 22))
	view.add_child(result)
	match state.pending_choice:
		"card":
			view.add_child(_label("Choose one card to add to the shared draw pool.", 20))
			var offers = _grid(3)
			for index in range(state.card_offers.size()):
				var card: Resource = state.card_offers[index]
				_tile(offers, _icon("card") + " " + card.card_name, _card_text(card), Presentation.COLORS.special, _choose_card.bind(index))
		"upgrade":
			view.add_child(_label("Upgrade a player card. Enemy copies remain unchanged.", 20))
			var choices = _grid(3)
			for card in state.upgrade_candidates():
				var reduction: int = mini(card.upgrade_cost_reduction, card.cost - 1)
				_tile(choices, card.card_name, _card_text(card) + "\nUpgrade: cost −%d" % reduction, Presentation.COLORS.special, _upgrade.bind(card.identity_key()))
		"resource", "production":
			var choices = _grid(3)
			var keys: Array = state.RESOURCES if state.pending_choice == "resource" else state.PRODUCTION
			for key in keys:
				_tile(choices, state.LABELS[key], "+%d" % state.choice_amount, Presentation.COLORS.special, _attribute.bind(key))
		_:
			if state.hull <= 0: view.add_child(_label("The damage destroyed your ship. This expedition is over.", 22))
			_button("Continue", show_system)

func _card_text(card: Resource) -> String:
	var rarity: String = ["Common", "Uncommon", "Rare"][clampi(card.tier - 1, 0, 2)]
	return "Cost %d %s · %s%s\n%s" % [card.cost, card.family.capitalize(), rarity,
		" · Upgrade %d" % card.upgrade_level if card.upgrade_level > 0 else "", card.description]


func _choose_card(index: int) -> void:
	if state.choose_card(index): _purchase_finished()

func _upgrade(key: String) -> void:
	if state.choose_upgrade(key): show_outcome()

func _attribute(key: String) -> void:
	if state.choose_attribute(key): _purchase_finished()

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
	battle.setup_settings = {"player_ship":state.player_ship, "enemy_ship":encounter.enemy, "enemy_data":state.enemy_profile(encounter), "modifier":encounter.modifier}
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
