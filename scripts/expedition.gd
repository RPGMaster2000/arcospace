extends Control
# UI routing only; ExpeditionState owns all rewards, requirements and progression.
const State = preload("res://scripts/expedition_state.gd")
const BOARD = preload("res://scenes/board_3d.tscn")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Tile = preload("res://scripts/ui/encounter_tile.gd")
const TouchScroll = preload("res://scripts/ui/encounter_scroll.gd")
const Header = preload("res://scenes/poi_header.tscn")
const CardGallery = preload("res://scripts/ui/card_gallery.gd")
var card_gallery: VBoxContainer
var card_inspector: CanvasLayer
@export var rules: Resource = preload("res://encounters/expedition_rules.tres")
## Optional accessibility preference; bundled emoji render by default on Android.
@export var text_icons_on_android: bool = false
var approach_note: Label
var repair_selector: HSlider
var service_confirmation_revision: int = -1
var return_to_outpost: bool = false
var selected_ship: int = 0
var state: Resource
var battle: Node
var view: VBoxContainer
var resource_bar: HFlowContainer
var legend: Button
var deck_button: Button
var current_deck_viewer: CanvasLayer
var outcome_flash: CanvasLayer
var presenting_outcome: bool = false
var mission_header: Label
var heading_row: HBoxContainer
var jump_button: Button
var return_button: Button
var confirmation: CanvasLayer
var confirm_button: Button
var title: Label
var ui: MarginContainer
var scroll: ScrollContainer
var header: PanelContainer
var footer: HBoxContainer
var more_hint: Label
var grid: GridContainer
var selected_approach: int = -1
var approach_buttons: Array[Button] = []
var view_kind: String = ""
var selected_encounter: int = -1

func _ready() -> void:
	_build_ui()
	card_inspector = preload("res://scripts/ui/card_inspector.gd").new()
	add_child(card_inspector)
	card_inspector.confirmed.connect(_confirm_card)
	card_inspector.opened.connect(func():
		if is_instance_valid(card_gallery): card_gallery.set_interaction_enabled(false))
	card_inspector.closed.connect(func():
		if is_instance_valid(card_gallery): card_gallery.set_interaction_enabled(true))
	current_deck_viewer = preload("res://scripts/ui/deck_viewer.gd").new()
	add_child(current_deck_viewer)
	outcome_flash = preload("res://scripts/ui/outcome_flash.gd").new()
	add_child(outcome_flash)
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
		ui.add_theme_constant_override("margin_" + edge, 24)
	add_child(ui)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	ui.add_child(column)
	title = _label("", 30)
	heading_row = HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 8)
	column.add_child(heading_row)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(title)
	deck_button = Button.new()
	deck_button.text = "Deck"
	deck_button.custom_minimum_size = Vector2(90, 48)
	Presentation.action(deck_button)
	deck_button.pressed.connect(_show_current_deck)
	heading_row.add_child(deck_button)
	legend = Button.new()
	legend.text = "Legend"
	legend.custom_minimum_size = Vector2(100, 48)
	Presentation.action(legend)
	heading_row.add_child(legend)
	resource_bar = preload("res://scripts/ui/resource_bar.gd").new()
	column.add_child(resource_bar)
	legend.pressed.connect(func(): resource_bar.overlay.show_legend())
	header = Header.instantiate()
	column.add_child(header)
	header.return_requested.connect(show_system)
	return_button = header.return_button
	scroll = TouchScroll.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	view = VBoxContainer.new()
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.add_theme_constant_override("separation", 10)
	scroll.add_child(view)
	more_hint = _label("More options below — swipe or scroll", 16)
	more_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(more_hint)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	confirmation = preload("res://scripts/ui/approach_confirmation.gd").new()
	add_child(confirmation)
	confirmation.cancelled.connect(_cancel_approach)
	confirmation.column.add_child(footer)
	confirmation.column.move_child(footer, 1)
	var shared = _label("", 20)
	approach_note = shared
	shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(shared)
	repair_selector = HSlider.new()
	repair_selector.custom_minimum_size = Vector2(180, 60)
	repair_selector.step = 1
	repair_selector.value_changed.connect(_repair_selection_changed)
	footer.add_child(repair_selector)
	confirm_button = confirmation.initiate
	confirm_button.pressed.connect(_confirm_approach)
	jump_button = Button.new()
	jump_button.custom_minimum_size.y = 48
	jump_button.add_theme_font_size_override("font_size", 21)
	jump_button.add_theme_font_override("font", Presentation.UI_FONT)
	Presentation.action(jump_button)
	jump_button.pressed.connect(_jump)
	column.add_child(jump_button)

func _process(_delta: float) -> void:
	if not ui.visible: return
	var bar = scroll.get_v_scroll_bar()
	more_hint.visible = bar.max_value > bar.page + 1 and bar.value + bar.page < bar.max_value - 1
	if view_kind == "system" and is_instance_valid(grid):
		# Fit six tiles plus the separate service button in the existing scroll area.
		var available_height: float = scroll.size.y - 14
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
	result.add_theme_constant_override("h_separation", 10)
	result.add_theme_constant_override("v_separation", 10)
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
	if is_instance_valid(current_deck_viewer): current_deck_viewer.dismiss()
	mission_header = null
	if is_instance_valid(card_inspector): card_inspector.dismiss()
	card_gallery = null
	view.alignment = BoxContainer.ALIGNMENT_END if kind == "poi" else BoxContainer.ALIGNMENT_BEGIN
	resource_bar.overlay.dismiss()
	confirmation.dismiss()
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
	footer.hide()
	confirm_button.disabled = true
	heading_row.show()
	title.visible = true
	title.text = "System Encounters — " + state.system_name
	resource_bar.exploration(state)
	jump_button.text = "%s FTL Drive %d/%d · %s" % [_icon("travel"), state.ftl_charge, state.required_ftl_charge, "Jump to Next System" if state.ftl_charge >= state.required_ftl_charge else "Requires %d more charge" % (state.required_ftl_charge - state.ftl_charge)]
	if state.mandatory_boss_pending():
		jump_button.text = "%s FTL Drive %d/%d · Resolve Boss first" % [_icon("travel"), state.ftl_charge, state.required_ftl_charge]
		jump_button.tooltip_text = "Defeat the mandatory Boss or escape by Emergency Jump before leaving this system."
	else:
		jump_button.tooltip_text = "Surplus FTL carries forward, up to %d." % state.rules.progression.ftl_carryover_cap
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
		_button("Select Ship", _exit)
		return
	var cards = _grid(3)
	for index in range(state.encounters.size()):
		var encounter: Dictionary = state.encounters[index]
		var category: String = Presentation.classification(encounter)
		var key: String = "battle" if encounter.kind == "battle" else Presentation.poi_key(encounter.poi)
		var descriptor: String = {"ordinary":"Ordinary PoI", "hazard":"Hazardous PoI", "battle":"Enemy", "special":"Anomalous PoI"}[category]
		if encounter.kind == "battle":
			var rank: int = state.enemy_profile(encounter).enemy_rank
			descriptor = "Mandatory Boss" if encounter.get("mandatory_boss", false) else ["Enemy", "Elite enemy", "Boss enemy"][rank]
			key = ["battle", "elite", "boss"][rank]
		var status: String = "Completed" if encounter.completed else "%s · +%d FTL" % [descriptor, state.encounter_charge(index)]
		if encounter.kind == "battle" and not encounter.completed:
			status += "\n" + _icon(Presentation.modifier_key(encounter.modifier)) + " " + State.Modifiers.NAMES[encounter.modifier]
		_tile(cards, _icon(key) + "\n" + encounter.title, status, Presentation.COLORS[category], visit.bind(index), encounter.completed, true)

	if not state.service.is_empty():
		_button("Trading Outpost · Service station · No travel FTL · Free to return", visit.bind(state.SERVICE_INDEX))

func visit(index: int) -> void:
	if not state.can_visit(index): return
	if state.encounter_at(index).kind == "battle": show_battle_preview(index)
	else: show_poi(index)

func show_battle_preview(index: int) -> void:
	if not state.can_visit(index): return
	_clear("preview")
	var encounter: Dictionary = state.encounters[index]
	var enemy: Resource = state.enemy_profile(encounter)
	var heading: String = encounter.title + " · " + State.Modifiers.NAMES[encounter.modifier] + " · Lv %d" % state.difficulty_level()
	if encounter.get("mandatory_boss", false): heading = "Mandatory Boss · " + heading
	var preview_title = _label(heading, 28)
	preview_title.tooltip_text = "Hull %d · Shields %d" % [enemy.hull_capacity, enemy.shields]
	view.add_child(preview_title)
	var details: String = State.Modifiers.description(encounter.modifier)
	if encounter.get("mandatory_boss", false): details += "\nResolve by victory or Emergency Jump."
	view.add_child(_label(details, 24))
	view.add_child(_label("Pending effects: " + state.pending_description(), 22))
	_button("Enter combat", start_battle.bind(index))
	_button("Return", show_system)

# Keep balance/state descriptions intact; compact only the exploration presentation.
func compact_text(value: String) -> String:
	return value.replace(" next battle", "").replace("Next battle: ", "").replace("permanent Hull", "Hull").replace("starting resource of choice", "resource of choice").replace("for expedition", "(expedition)")

func compact_outcome(outcome: Resource) -> String:
	return compact_text(state.describe_outcome(outcome))

func highlight_outcome(value: String) -> String:
	var expression = RegEx.new()
	expression.compile(r"[+-]\d+[^·\n]*|\d+(?:\.\d+)?%")
	var result = ""
	var offset = 0
	for matched in expression.search_all(value):
		result += value.substr(offset, matched.get_start() - offset)
		var part: String = matched.get_string()
		if part.ends_with("%"):
			result += "[b]" + part + "[/b]"
		else:
			# Offline turns are a penalty despite their positive counter.
			var color = "f49b97" if part.begins_with("-") or part.to_lower().contains("offline") else "9ce3b2"
			result += "[b][color=" + color + "]" + part + "[/color][/b]"
		offset = matched.get_end()
	return result + value.substr(offset)

func approach_text(approach: Resource) -> String:
	var lines: Array[String] = []
	if not approach.requirement.is_empty():
		lines.append("%s ≥%d (ship: %d)" % [state.LABELS[approach.requirement], approach.minimum_production, state.production(approach.requirement)])
	if approach.salvage_cost > 0: lines.append("Cost: %d Salvage" % approach.salvage_cost)
	lines.append("%s%% — %s" % [String.num(approach.success_chance * 100, 2).trim_suffix(".0"), compact_outcome(approach.success)])
	if approach.success_chance < 1:
		lines.append("%s%% — %s" % [String.num((1.0 - approach.success_chance) * 100, 2).trim_suffix(".0"), compact_outcome(approach.failure)])
	var reason: String = state.locked_reason(approach)
	if not reason.is_empty(): lines.append("LOCKED" if reason.begins_with("Requires " + state.LABELS.get(approach.requirement, "missing")) else "LOCKED — " + reason)
	return "\n".join(lines)

func show_poi(index: int) -> void:
	if index == state.SERVICE_INDEX:
		show_outpost()
		return
	selected_encounter = index
	_clear("poi")
	var poi: Resource = state.encounter_at(index).poi
	approach_note.text = ""
	confirm_button.text = "Initiate"
	header.configure(poi)
	var options = _grid(2)
	for slot in range(poi.approaches.size()):
		var approach: Resource = poi.approaches[slot]
		var key: String = Presentation.approach_key(poi, slot)
		var button = _tile(options, _icon(key) + "  " + approach.title, approach_text(approach),
			Presentation.COLORS[Presentation.classification(state.encounter_at(index))], _select_approach.bind(slot), not state.locked_reason(approach).is_empty())
		button.set_rich_details(highlight_outcome(approach_text(approach)))
		approach_buttons.append(button)
	if state.can_survey(index):
		var survey = _tile(options, _icon("approach") + "  Navigation survey", "No loot · " + state.describe_modifiers(state.rules.survey_penalty), Presentation.COLORS.special, _select_approach.bind(-2))
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
	approach_note.text = "Service station · No travel FTL · Free to leave"
	confirm_button.text = "Initiate"
	var options = _grid(2)
	for slot in range(state.service.poi.approaches.size()):
		var approach: Resource = state.service.poi.approaches[slot]
		var details: String
		if approach.success.hull > 0:
			details = "1 Salvage / Hull · Select repair amount"
		else:
			details = "%d Salvage · %s" % [state.service_cost(slot), compact_outcome(approach.success)]
		var reason: String = state.service_locked_reason(slot)
		if not reason.is_empty(): details += "\nLOCKED — " + reason
		var button = _tile(options, approach.title, details, Presentation.COLORS.special, _select_approach.bind(slot), not reason.is_empty())
		button.set_rich_details(highlight_outcome(details))
		approach_buttons.append(button)
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
	footer.visible = selected_encounter == state.SERVICE_INDEX
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

	var selected_title: String = "Navigation survey" if slot == -2 else state.encounter_at(selected_encounter).poi.approaches[slot].title
	confirmation.present(selected_title)

func _cancel_approach() -> void:
	confirmation.dismiss()
	selected_approach = -1
	confirm_button.disabled = true
	repair_selector.hide()
	repair_selector.set_value_no_signal(0)
	for button in approach_buttons:
		button.selected = false
		button.refresh_style()

func _confirm_approach() -> void:
	if presenting_outcome or view_kind != "poi" or not confirmation.shade.visible or confirm_button.disabled: return
	confirm_button.disabled = true
	confirmation.dismiss()
	if selected_approach == -2: _survey(selected_encounter)
	elif selected_approach >= 0: _approach(selected_encounter, selected_approach)

func _survey(index: int) -> void:
	if state.survey(index): show_outcome()

func _approach(index: int, slot: int) -> void:
	if presenting_outcome: return
	if index == state.SERVICE_INDEX:
		if state.purchase_service(slot, service_confirmation_revision, int(repair_selector.value)):
			return_to_outpost = true
			_purchase_finished()
		return
	if state.resolve_approach(index, slot):
		presenting_outcome = true
		var resolved_state: Resource = state
		await outcome_flash.play(state.last_poi_success == 1)
		presenting_outcome = false
		if not is_queued_for_deletion() and state == resolved_state: show_outcome()

func show_outcome() -> void:
	_clear("outcome")
	if state.last_poi_success >= 0:
		mission_header = _label("Mission Successful" if state.last_poi_success == 1 else "Mission Compromised", 32)
		mission_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_header.add_theme_color_override("font_color", Color("91e6ad") if state.last_poi_success == 1 else Color("ee928b"))
		view.add_child(mission_header)
	var result = PanelContainer.new()
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result.custom_minimum_size.x = minf(900, ui.size.x - 32)
	result.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	var picking_card: bool = state.pending_choice in ["card", "upgrade"]
	result.add_child(_label(("Acquire one card" if state.pending_choice == "card" else "Upgrade a card") if picking_card else compact_text(state.last_outcome), 26 if picking_card else 22))
	result.tooltip_text = state.last_outcome if picking_card else ""
	view.add_child(result)
	match state.pending_choice:
		"card":
			_show_card_gallery(state.card_offers)
		"upgrade":
			_show_card_gallery(state.upgrade_candidates())
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

func _show_card_gallery(cards: Array) -> void:
	jump_button.hide()
	card_gallery = CardGallery.new()
	card_gallery.show_toolbar = state.pending_choice != "card"
	card_gallery.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_gallery.custom_minimum_size.y = 250
	view.add_child(card_gallery)
	card_gallery.set_cards(cards)
	card_gallery.card_selected.connect(_preview_card)

func _preview_card(card: Resource) -> void:
	if state.pending_choice == "card" and card in state.card_offers:
		card_inspector.present(card)
	elif state.pending_choice == "upgrade" and card in state.upgrade_candidates():
		card_inspector.present(card, card.with_upgrade(card.upgrade_level + 1))

func _show_current_deck() -> void:
	if presenting_outcome: return
	card_inspector.dismiss()
	resource_bar.overlay.dismiss()
	current_deck_viewer.show_cards(state.player_pool(), state.ship().ship_name + " · Current deck · Read only")

func _confirm_card(card: Resource) -> void:
	# The existing state methods validate eligibility and consume each choice once.
	if state.pending_choice == "card": _choose_card(state.card_offers.find(card))
	elif state.pending_choice == "upgrade": _upgrade(card.identity_key())

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
