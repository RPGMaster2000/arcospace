extends Control
# RESPONSIBILITY: Route exploration screens and connect their choices to ExpeditionState.
# DOES NOT: Calculate rewards, generate encounters or implement combat rules.
# EXTEND: Route choices to State; _clear resets UI only, never the expedition ledger.
const Save = preload("res://scripts/persistence/expedition_save.gd")
var save_store = Save.new()
var persistence_enabled: bool = true
var resume_data: Dictionary = {}
var save_error: AcceptDialog
var _battle_checkpoint: Dictionary = {}
var _battle_marker: Dictionary = {}
var _previous_auto_quit: bool = true
var _previous_back_quit: bool = true
const State = preload("res://scripts/expedition_state.gd")
const BOARD = preload("res://scenes/board_3d.tscn")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const Tile = preload("res://scripts/ui/encounter_tile.gd")
const CardGallery = preload("res://scripts/ui/card_gallery.gd")
const VisualEffects = preload("res://scripts/visual/visual_effects.gd")
@export var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
const OutpostScreen = preload("res://scripts/ui/outpost_screen.gd")
const ExpeditionScreen = preload("res://scripts/ui/expedition_screen.gd")
const ExpeditionText = preload("res://scripts/ui/expedition_text.gd")
const DeckReplacement = preload("res://scripts/ui/deck_replacement.gd")
const FieldRepairControls = preload("res://scripts/ui/field_repair_controls.gd")
var outpost_screen: OutpostScreen
var screen: ExpeditionScreen
var replacement_panel: DeckReplacement
# Read-only aliases preserve the controller interface; the panel owns selection.
var replacement_key: String:
	get:
		return replacement_panel.selected_key if is_instance_valid(replacement_panel) else ""
var replacement_selection: Label:
	get:
		return replacement_panel.selection if is_instance_valid(replacement_panel) else null
var replace_button: Button:
	get:
		return replacement_panel.replace_button if is_instance_valid(replacement_panel) else null
var incoming_portrait: Button:
	get:
		return replacement_panel.incoming_portrait if is_instance_valid(replacement_panel) else null
var card_gallery: VBoxContainer
var card_inspector: CanvasLayer
# TUNE: Disable to restore the original grid; both presentations use the same encounter state.
@export var use_star_map: bool = true
# TUNE: Seconds before a selected map destination opens; no travel cost or rules change.
@export_range(0.1, 2.0, 0.1) var star_map_travel_duration: float = 1.4
@export_group("Hull warning")
## TUNE: Seconds per soft double heartbeat, maximum draw scale, and red tint strength.
@export_range(1.0, 3.0, 0.05) var hull_pulse_period: float = 1.45
@export_range(1.0, 1.04, 0.005) var hull_pulse_scale: float = 1.03
@export_range(0.0, 0.5, 0.01) var hull_pulse_intensity: float = 0.22
@export_group("")
var settings_button: Button
var field_repairs: VBoxContainer
var station_preview: VBoxContainer
var star_map: Control
var map_system: int = -1
var map_destination: int = -1

@export var rules: Resource = preload("res://encounters/expedition_rules.tres")
## Optional accessibility preference; bundled emoji render by default on Android.
@export var text_icons_on_android: bool = false
var approach_note: Label
var repair_selector: HSlider
var service_confirmation_revision: int:
	get:
		return outpost_screen.revision if is_instance_valid(outpost_screen) else -1
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

#region Screen initialization


func _ready() -> void:
	_build_ui()
	card_inspector = preload("res://scripts/ui/card_inspector.gd").new()
	add_child(card_inspector)
	card_inspector.confirmed.connect(_confirm_card)
	card_inspector.opened.connect(
		func():
			if is_instance_valid(card_gallery):
				card_gallery.set_interaction_enabled(false)
	)
	card_inspector.closed.connect(
		func():
			if is_instance_valid(card_gallery):
				card_gallery.set_interaction_enabled(true)
	)
	current_deck_viewer = preload("res://scripts/ui/deck_viewer.gd").new()
	add_child(current_deck_viewer)
	outcome_flash = preload("res://scripts/ui/outcome_flash.gd").new()
	outcome_flash.visual_settings = visual_settings
	add_child(outcome_flash)
	_setup_field_repairs()
	if persistence_enabled:
		_previous_auto_quit = get_tree().auto_accept_quit
		get_tree().auto_accept_quit = false
		_previous_back_quit = get_tree().quit_on_go_back
		get_tree().quit_on_go_back = false
		settings_button.menu.configure_save_quit(_save_and_quit)
	if resume_data.is_empty():
		start_expedition()
	else:
		state = resume_data.state
		selected_ship = state.player_ship
		_bind_progress()
		var marker: Dictionary = resume_data.get("battle", {})
		if marker.is_empty():
			show_system()
		else:
			start_battle(int(marker.index), int(marker.seed))


# Construct exploration controls at runtime; many of these nodes do not exist in expedition.tscn.
func _build_ui() -> void:
	screen = ExpeditionScreen.new()
	screen.hull_pulse_period = hull_pulse_period
	screen.hull_pulse_scale = hull_pulse_scale
	screen.hull_pulse_intensity = hull_pulse_intensity
	add_child(screen)
	ui = screen.ui
	title = screen.title
	heading_row = screen.heading_row
	deck_button = screen.deck_button
	legend = screen.legend
	settings_button = screen.settings_button
	resource_bar = screen.resource_bar
	header = screen.header
	return_button = screen.return_button
	scroll = screen.scroll
	view = screen.view
	more_hint = screen.more_hint
	footer = screen.footer
	confirmation = screen.confirmation
	approach_note = screen.approach_note
	confirm_button = screen.confirm_button
	jump_button = screen.jump_button
	screen.deck_requested.connect(_show_current_deck)
	screen.main_menu_requested.connect(_exit)
	screen.hull_requested.connect(_show_hull_info)
	screen.return_requested.connect(show_system)
	screen.cancel_requested.connect(_cancel_approach)
	screen.confirm_requested.connect(_confirm_approach)
	screen.jump_requested.connect(_jump)


func _process(_delta: float) -> void:
	if not ui.visible:
		return
	var bar = scroll.get_v_scroll_bar()
	more_hint.visible = bar.max_value > bar.page + 1 and bar.value + bar.page < bar.max_value - 1
	if view_kind == "system" and is_instance_valid(grid):
		# Fit six tiles plus the separate service button in the existing scroll area.
		var available_height: float = scroll.size.y - 14
		for child in view.get_children():
			if child != grid:
				available_height -= child.size.y + view.get_theme_constant("separation")
		for tile in grid.get_children():
			tile.minimum_height = maxf(100, available_height / 2)


func _label(text: String, font_size: int = 20) -> Label:
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(
	text: String, callback: Callable, disabled: bool = false, height: float = 64
) -> Button:
	var button = Button.new()
	button.text = text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 22)
	button.disabled = disabled
	Presentation.action(button)
	button.pressed.connect(
		func():
			if scroll.allows_activation():
				callback.call()
	)
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


func _tile(
	parent: Node,
	heading: String,
	details: String,
	color: Color,
	callback: Callable,
	disabled: bool = false,
	centered: bool = false
) -> Button:
	var button = Tile.new()
	button.configure(heading, details, color, centered)
	button.disabled = disabled
	button.refresh_style()
	button.pressed.connect(
		func():
			if button.is_inside_tree() and scroll.allows_activation() and not button.disabled:
				callback.call()
	)
	parent.add_child(button)
	return button


func _icon(key: String) -> String:
	return Presentation.icon(
		key, get_theme_default_font(), text_icons_on_android and OS.has_feature("android")
	)


# Rebuild only the current exploration view while keeping ExpeditionState and map destination alive.
func _clear(kind: String) -> void:
	if is_instance_valid(current_deck_viewer):
		current_deck_viewer.dismiss()
	mission_header = null
	if is_instance_valid(card_inspector):
		card_inspector.dismiss()
	card_gallery = null
	view.alignment = BoxContainer.ALIGNMENT_END if kind == "poi" else BoxContainer.ALIGNMENT_BEGIN
	resource_bar.overlay.dismiss()
	field_repairs.clear()
	confirmation.dismiss()
	if is_instance_valid(outpost_screen):
		outpost_screen.clear()
	outpost_screen = null
	confirmation = screen.confirmation
	confirm_button = screen.confirm_button
	footer = screen.footer
	approach_note = screen.approach_note
	station_preview = null
	repair_selector = null
	view_kind = kind
	state.field_repairs_open = kind == "system" and state.hull > 0
	resource_bar.field_repairs_enabled = state.field_repairs_open
	selected_approach = -1
	approach_buttons = []
	grid = null
	for child in view.get_children():
		view.remove_child(child)
		child.queue_free()
	star_map = null
	replacement_panel = null
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
		if kind == "system" and use_star_map
		else ScrollContainer.SCROLL_MODE_AUTO
	)
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
	jump_button.text = (
		"%s FTL Drive %d/%d · %s"
		% [
			_icon("travel"),
			state.ftl_charge,
			state.required_ftl_charge,
			(
				"Jump to Next System"
				if state.ftl_charge >= state.required_ftl_charge
				else "Requires %d more charge" % (state.required_ftl_charge - state.ftl_charge)
			)
		]
	)
	if state.mandatory_boss_pending():
		jump_button.text = (
			"%s FTL Drive %d/%d · Resolve Boss first"
			% [_icon("travel"), state.ftl_charge, state.required_ftl_charge]
		)
		jump_button.tooltip_text = "Defeat the mandatory Boss or escape by EMP Pulse before leaving this system."
	else:
		jump_button.tooltip_text = "FTL resets to zero when entering the next system."
	jump_button.disabled = not state.can_jump()
	jump_button.visible = state.hull > 0


#endregion

#region System navigation


func start_expedition() -> bool:
	var candidate = State.new()
	candidate.start(selected_ship, rules)
	if persistence_enabled and not save_store.save_run(candidate):
		_show_save_error()
		return false
	map_system = -1
	map_destination = -1
	if state != null and state.progress_committed.is_connected(_progress_committed):
		state.progress_committed.disconnect(_progress_committed)
	state = candidate
	_battle_checkpoint = {}
	_battle_marker = {}
	_bind_progress()
	show_system()
	return true


func _bind_progress() -> void:
	if not state.progress_committed.is_connected(_progress_committed):
		state.progress_committed.connect(_progress_committed)


func _progress_committed() -> void:
	if is_instance_valid(battle) and battle.result_recorded:
		battle.settings_button.menu.battle_restart_notice = false
	if persistence_enabled and not _save_progress():
		_show_save_error()


func _save_progress() -> bool:
	if not persistence_enabled: return true
	if state == null: return false
	if state.run_ended or state.hull <= 0:
		return save_store.clear_run()
	if is_instance_valid(battle) and not battle.result_recorded:
		return save_store.save_data(_battle_checkpoint, _battle_marker)
	return save_store.save_run(state)


func _show_save_error() -> void:
	if not is_instance_valid(save_error):
		save_error = AcceptDialog.new()
		save_error.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(save_error)
	save_error.dialog_text = save_store.error
	save_error.popup_centered(Vector2i(520, 180))


func _save_and_quit() -> bool:
	if not _save_progress():
		_show_save_error()
		return false
	_go_to_menu()
	return true


func _notification(what: int) -> void:
	if not persistence_enabled or state == null: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var menu = battle.settings_button.menu if is_instance_valid(battle) else settings_button.menu
		menu.present()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if not _save_progress(): _show_save_error()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _save_progress():
			_prepare_departure()
			get_tree().quit()
		else: _show_save_error()


func _exit_tree() -> void:
	if persistence_enabled:
		get_tree().auto_accept_quit = _previous_auto_quit
		get_tree().quit_on_go_back = _previous_back_quit


func show_system() -> void:
	if state.hull > 0 and state.chasedown_unresolved():
		if state.active_battle < 0:
			if state.encounters[state.chasedown_index].response < 0:
				_show_chasedown()
			else:
				start_battle(state.chasedown_index)
		return
	get_node("/root/Music").play_starmap()
	if not state.pending_choice.is_empty():
		show_outcome()
		return
	return_to_outpost = false
	_clear("system")
	if state.hull <= 0:
		view.add_child(_label("Expedition ended — your ship was lost.", 26))
		_button("Main Menu", _exit)
		return
	if use_star_map:
		_show_star_map()
		return
	var cards = _grid(3)
	for index in range(state.encounters.size()):
		var encounter: Dictionary = state.encounters[index]
		var category: String = Presentation.classification(encounter)
		var key: String = (
			"battle" if encounter.kind == "battle" else Presentation.poi_key(encounter.poi)
		)
		var descriptor: String = {
			"ordinary": "Ordinary PoI",
			"hazard": "Hazardous PoI",
			"battle": "Enemy",
			"special": "Anomalous PoI"
		}[category]
		if encounter.kind == "battle":
			var rank: int = state.enemy_profile(encounter).enemy_rank
			descriptor = (
				"Mandatory Boss"
				if encounter.get("mandatory_boss", false)
				else ["Enemy", "Elite enemy", "Boss enemy"][rank]
			)
			key = ["battle", "elite", "boss"][rank]
		var status: String = (
			"Completed"
			if encounter.completed
			else "%s · +%d FTL" % [descriptor, state.encounter_charge(index)]
		)
		if encounter.kind == "battle" and not encounter.completed:
			status += (
				"\n"
				+ _icon(Presentation.modifier_key(encounter.modifier))
				+ " "
				+ State.Modifiers.NAMES[encounter.modifier]
			)
		if encounter.get("chasedown", false):
			continue
		_tile(
			cards,
			_icon(key) + "\n" + encounter.title,
			status,
			Presentation.COLORS[category],
			_grid_travel.bind(index),
			encounter.completed,
			true
		)

	if not state.service.is_empty():
		_button(
			"Trading Outpost · Service station · No travel FTL · Free to return",
			_grid_travel.bind(state.SERVICE_INDEX)
		)

	var destination: int = state.pending_destination if state.pending_destination >= 0 else state.travel_destination
	if destination != -1:
		_grid_travel.call_deferred(destination)


# Adapt generated encounters to presentation entries; arrival uses visit, exactly like grid selection.
func _show_star_map() -> void:
	if map_system != state.system_number:
		map_system = state.system_number
		map_destination = state.navigation_origin
	var entries: Array = []
	for index in range(state.encounters.size()):
		var encounter: Dictionary = state.encounters[index]
		if encounter.get("chasedown", false):
			continue
		var key: String = (
			"battle" if encounter.kind == "battle" else Presentation.poi_key(encounter.poi)
		)
		var detail: String = "+%d FTL" % state.encounter_charge(index)
		if encounter.kind == "battle":
			key = ["battle", "elite", "boss"][state.enemy_profile(encounter).enemy_rank]
			if encounter.get("mandatory_boss", false):
				detail = "Mandatory Boss · " + detail
		var tooltip: String = detail
		if encounter.kind == "battle":
			tooltip += "\n" + State.Modifiers.NAMES[encounter.modifier]
		entries.append(
			{
				"index": index,
				"text":
				(
					("✓ " if encounter.completed else _icon(key) + " ")
					+ encounter.title
					+ "\n"
					+ ("Completed" if encounter.completed else detail)
				),
				"tooltip": tooltip,
				"color": Presentation.COLORS[Presentation.classification(encounter)],
				"completed": encounter.completed
			}
		)
	if not state.service.is_empty():
		entries.append(
			{
				"index": state.SERVICE_INDEX,
				"text": _icon("trading_outpost") + " Trading Outpost\nFree return · 0 FTL",
				"tooltip": "Independent service station",
				"color": Color("8fcab7"),
				"completed": false
			}
		)
	star_map = preload("res://scripts/ui/star_map.gd").new()
	star_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	star_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.add_child(star_map)
	star_map.configure(
		entries, map_destination, star_map_travel_duration,
		hash("%d:%d:sky" % [state.seed_used, state.system_number])
	)
	star_map.before_travel = state.can_visit
	star_map.intercept_travel = state.begin_travel
	star_map.interrupted.connect(_show_chasedown)
	star_map.arrived.connect(visit)
	var destination: int = state.pending_destination if state.pending_destination >= 0 else state.travel_destination
	if destination != -1:
		star_map.travel.call_deferred(destination)


func visit(index: int) -> void:
	if not state.can_visit(index):
		return
	map_destination = index
	state.arrive_destination(index)
	if state.encounter_at(index).kind == "battle":
		show_battle_preview(index)
	else:
		show_poi(index)


func _jump() -> void:
	if state.generate_system():
		show_system()


func _request_travel(index: int) -> bool:
	if not state.can_visit(index):
		return false
	if state.begin_travel(index):
		_show_chasedown()
		return false
	return true


func _grid_travel(index: int) -> void:
	if _request_travel(index):
		visit(index)


func _show_chasedown() -> void:
	_clear("chasedown")
	jump_button.hide()
	title.text = "Sublight Chasedown"
	(
		view
		. add_child(
			_label(
				"A hostile vessel emerges from sensor range and accelerates toward your ship. You have moments to respond before weapons come online.",
				22
			)
		)
	)
	view.add_child(
		_label("Destination preserved: " + state.encounters[state.pending_destination].title, 18)
	)
	var choices = _grid(2)
	for index in range(state.rules.chasedown_responses.size()):
		var response: Dictionary = state.rules.chasedown_responses[index]
		var details: String = state.describe_modifiers(response.get("modifiers", {}))
		if int(response.get("hull", 0)) != 0:
			details += " · %+d Hull (minimum 1)" % int(response.hull)
		if details.is_empty():
			details = "No starting modifiers"
		_tile(
			choices,
			str(response.title),
			details,
			Presentation.COLORS.battle,
			_chasedown_response.bind(index)
		)


func _chasedown_response(index: int) -> void:
	if state.choose_chasedown_response(index):
		start_battle(state.chasedown_index)


#endregion

#region Approaches and outposts


func show_battle_preview(index: int) -> void:
	if not state.can_visit(index):
		return
	_clear("preview")
	var encounter: Dictionary = state.encounters[index]
	var enemy: Resource = state.enemy_profile(encounter)
	var heading: String = (
		encounter.title
		+ " · "
		+ State.Modifiers.NAMES[encounter.modifier]
		+ " · Lv %d" % state.difficulty_level()
	)
	if encounter.get("mandatory_boss", false):
		heading = "Mandatory Boss · " + heading
	var preview_title = _label(heading, 28)
	preview_title.tooltip_text = "Hull %d · Shields %d" % [enemy.hull_capacity, enemy.shields]
	view.add_child(preview_title)
	var details: String = State.Modifiers.description(encounter.modifier)
	if encounter.get("mandatory_boss", false):
		details += "\nResolve by victory or EMP Pulse."
	view.add_child(_label(details, 24))
	view.add_child(_label("Pending effects: " + state.pending_description(), 22))
	_button("Enter combat", start_battle.bind(index))
	_button("Return", show_system)


# Keep balance/state descriptions intact; compact only the exploration presentation.
func compact_text(value: String) -> String:
	return ExpeditionText.compact_text(value)


func compact_outcome(outcome: Resource) -> String:
	return ExpeditionText.compact_outcome(state, outcome)


func highlight_outcome(value: String) -> String:
	return ExpeditionText.highlight_outcome(value)


func approach_text(approach: Resource) -> String:
	return ExpeditionText.approach_text(state, approach)


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
		var button = _tile(
			options,
			_icon(key) + "  " + approach.title,
			approach_text(approach),
			Presentation.COLORS[Presentation.classification(state.encounter_at(index))],
			_select_approach.bind(slot),
			not state.locked_reason(approach).is_empty()
		)
		button.set_rich_details(highlight_outcome(approach_text(approach)))
		approach_buttons.append(button)
	if state.can_survey(index):
		var survey = _tile(
			options,
			_icon("approach") + "  Navigation survey",
			"No loot · " + state.describe_modifiers(state.rules.survey_penalty),
			Presentation.COLORS.special,
			_select_approach.bind(-2)
		)
		approach_buttons.append(survey)


func show_outpost() -> void:
	if not state.can_visit(state.SERVICE_INDEX):
		if not state.pending_choice.is_empty():
			show_outcome()
		else:
			show_system()
		return
	return_to_outpost = false
	selected_encounter = state.SERVICE_INDEX
	_clear("poi")
	header.configure(state.service.poi)
	jump_button.hide()
	outpost_screen = OutpostScreen.new()
	view.add_child(outpost_screen)
	outpost_screen.configure(state, scroll.allows_activation)
	outpost_screen.purchase_requested.connect(_purchase_outpost_service.bind(outpost_screen))
	outpost_screen.selection_changed.connect(_outpost_selection_changed.bind(outpost_screen))
	# Preserve existing control accessors while the component owns their lifecycle.
	grid = outpost_screen.options
	approach_buttons = outpost_screen.buttons
	confirmation = outpost_screen.confirmation
	confirm_button = outpost_screen.confirm_button
	footer = outpost_screen.footer
	approach_note = outpost_screen.note
	station_preview = outpost_screen.preview
	repair_selector = outpost_screen.selector
	ui.set_deferred("size", size)


func _repair_selection_changed(value: float) -> void:
	if is_instance_valid(outpost_screen):
		outpost_screen.update_quantity(value)


func _purchase_finished() -> void:
	if not state.pending_choice.is_empty():
		show_outcome()
	elif return_to_outpost:
		show_outpost()
		outpost_screen.show_purchase_complete()
	else:
		show_outcome()


func _select_approach(slot: int) -> void:
	if view_kind != "poi" or not state.can_visit(selected_encounter):
		return
	if selected_encounter == state.SERVICE_INDEX:
		if is_instance_valid(outpost_screen):
			outpost_screen.select_service(slot)
		return
	if slot == -2:
		if not state.can_survey(selected_encounter):
			return
	else:
		var poi: Resource = state.encounter_at(selected_encounter).poi
		if (
			slot < 0
			or slot >= poi.approaches.size()
			or not state.locked_reason(poi.approaches[slot]).is_empty()
		):
			return
	selected_approach = slot
	footer.hide()
	for index in range(approach_buttons.size()):
		var button = approach_buttons[index]
		button.selected = index == slot or (slot == -2 and index == approach_buttons.size() - 1)
		button.refresh_style()
	confirm_button.disabled = false
	var selected_title: String = (
		"Navigation survey"
		if slot == -2
		else state.encounter_at(selected_encounter).poi.approaches[slot].title
	)
	confirmation.present(selected_title)


func _cancel_approach() -> void:
	if is_instance_valid(outpost_screen):
		outpost_screen.cancel_selection()
		return
	confirmation.dismiss()
	selected_approach = -1
	confirm_button.disabled = true
	for button in approach_buttons:
		button.selected = false
		button.refresh_style()


func _confirm_approach() -> void:
	if is_instance_valid(outpost_screen):
		outpost_screen.confirm_purchase()
		return
	if (
		presenting_outcome
		or view_kind != "poi"
		or not confirmation.shade.visible
		or confirm_button.disabled
	):
		return
	confirm_button.disabled = true
	confirmation.dismiss()
	if selected_approach == -2:
		_survey(selected_encounter)
	elif selected_approach >= 0:
		_approach(selected_encounter, selected_approach)


func _outpost_selection_changed(slot: int, source: OutpostScreen) -> void:
	if source == outpost_screen:
		selected_approach = slot


func _purchase_outpost_service(
	slot: int, amount: int, revision: int, source: OutpostScreen
) -> void:
	if (
		presenting_outcome
		or view_kind != "poi"
		or not is_instance_valid(source)
		or source != outpost_screen
	):
		return
	if state.purchase_service(slot, revision, amount):
		return_to_outpost = true
		_purchase_finished()


func _survey(index: int) -> void:
	if state.survey(index):
		show_outcome()


func _approach(index: int, slot: int) -> void:
	if presenting_outcome:
		return
	if index == state.SERVICE_INDEX:
		if is_instance_valid(outpost_screen):
			_purchase_outpost_service(
				slot, int(repair_selector.value), service_confirmation_revision, outpost_screen
			)
		return
	if state.resolve_approach(index, slot):
		presenting_outcome = true
		var resolved_state: Resource = state
		await outcome_flash.play(state.last_poi_success == 1)
		presenting_outcome = false
		if not is_queued_for_deletion() and state == resolved_state:
			show_outcome()


#endregion

#region Rewards and decks


func show_outcome() -> void:
	if state.pending_choice == "replace":
		_show_replacement()
		return
	_clear("outcome")
	if state.last_poi_success >= 0:
		mission_header = _label(
			"Mission Successful" if state.last_poi_success == 1 else "Mission Compromised", 32
		)
		mission_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mission_header.add_theme_color_override(
			"font_color",
			(
				Color(visual_settings.poi_success_color, 1.0)
				if state.last_poi_success == 1
				else Color(visual_settings.poi_failure_color, 1.0)
			)
		)
		view.add_child(mission_header)
		VisualEffects.reveal(mission_header, visual_settings)
	var result = PanelContainer.new()
	result.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	result.custom_minimum_size.x = minf(900, ui.size.x - 32)
	result.add_theme_stylebox_override("panel", Presentation.style(Presentation.COLORS.special))
	var picking_card: bool = state.pending_choice in ["card", "upgrade"]
	result.add_child(
		_label(
			(
				(
					"Acquire one card"
					if state.pending_choice == "card"
					else (
						"Upgrade different cards · %d remaining" % maxi(1, state.upgrades_remaining)
					)
				)
				if picking_card
				else compact_text(state.last_outcome)
			),
			26 if picking_card else 22
		)
	)
	result.tooltip_text = state.last_outcome if picking_card else ""
	view.add_child(result)
	var reward_text: Label = result.get_child(0)
	reward_text.add_theme_color_override(
		"font_color",
		Color.WHITE.lerp(visual_settings.card_selection_color, visual_settings.reward_text_emphasis)
	)
	VisualEffects.reveal(reward_text, visual_settings)
	match state.pending_choice:
		"card":
			_show_card_gallery(state.card_offers)
		"upgrade":
			_show_card_gallery(state.upgrade_candidates())
			_button("Finish upgrades", _finish_upgrades, false, 48)
		"resource", "production":
			var choices = _grid(3)
			var keys: Array = (
				state.RESOURCES if state.pending_choice == "resource" else state.PRODUCTION
			)
			for key in keys:
				_tile(
					choices,
					state.LABELS[key],
					"+%d" % state.choice_amount,
					Presentation.COLORS.special,
					_attribute.bind(key)
				)
		_:
			if state.hull <= 0:
				view.add_child(
					_label("The damage destroyed your ship. This expedition is over.", 22)
				)
			_button("Continue", show_system)


func _card_text(card: Resource) -> String:
	var rarity: String = ["Common", "Uncommon", "Rare"][clampi(card.tier - 1, 0, 2)]
	return (
		"Cost %d %s · %s%s\n%s"
		% [
			card.cost,
			card.family.capitalize(),
			rarity,
			" · Upgrade %d" % card.upgrade_level if card.upgrade_level > 0 else "",
			card.description
		]
	)


func _choose_card(index: int) -> void:
	if state.choose_card(index):
		_purchase_finished()


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
	if presenting_outcome:
		return
	card_inspector.dismiss()
	resource_bar.overlay.dismiss()
	current_deck_viewer.show_cards(
		state.player_pool(),
		(
			state.ship().ship_name
			+ " · Deck: %d / %d · Read only" % [state.player_pool().size(), state.deck_limit()]
		)
	)


func _confirm_card(card: Resource) -> void:
	# The existing state methods validate eligibility and consume each choice once.
	if state.pending_choice == "card":
		_choose_card(state.card_offers.find(card))
	elif state.pending_choice == "upgrade":
		_upgrade(card.identity_key())


func _upgrade(key: String) -> void:
	if state.choose_upgrade(key):
		show_outcome()


func _attribute(key: String) -> void:
	if state.choose_attribute(key):
		_purchase_finished()


func _finish_upgrades() -> void:
	state.finish_upgrades()
	show_outcome()


# Same outcome view/gallery: the incoming reward is fixed in ExpeditionState until confirmed/declined.
func _show_replacement() -> void:
	_clear("replacement")
	jump_button.hide()
	title.text = "Deck Full — %d/%d Cards" % [state.player_pool().size(), state.deck_limit()]
	replacement_panel = DeckReplacement.new()
	view.add_child(replacement_panel)
	replacement_panel.configure(state.pending_card, state.player_pool(), scroll.allows_activation)
	card_gallery = replacement_panel.gallery
	replacement_panel.inspect_incoming.connect(
		func(): card_inspector.present(state.pending_card, null, true)
	)
	replacement_panel.replace_requested.connect(_replace_card)
	replacement_panel.decline_requested.connect(_decline_card)


func _select_replacement(card: Resource) -> void:
	if state.pending_choice == "replace" and is_instance_valid(replacement_panel):
		replacement_panel.select_card(card)


func _replace_card() -> void:
	if state.replace_card(replacement_key):
		_purchase_finished()


func _decline_card() -> void:
	if state.decline_card():
		_purchase_finished()


#endregion

#region Battle handoff


# Set expedition/profile references and signal callbacks before add_child triggers Board initialization.
func start_battle(index: int, battle_seed: int = -1) -> void:
	if not state.can_visit(index) or state.encounters[index].kind != "battle":
		return
	var checkpoint: Dictionary = Save.encode(state)
	if battle_seed < 0:
		var generator := RandomNumberGenerator.new()
		generator.randomize()
		battle_seed = generator.randi()
	var marker: Dictionary = {"index": index, "seed": str(battle_seed)}
	if persistence_enabled and not save_store.save_data(checkpoint, marker):
		_show_save_error()
		if view_kind.is_empty():
			_clear("save_error")
			view.add_child(_label("The battle could not be resumed until its checkpoint can be saved."))
			_button("Retry Battle", start_battle.bind(index, battle_seed))
		return
	_battle_checkpoint = checkpoint
	_battle_marker = marker
	state.field_repairs_open = false
	resource_bar.set_heartbeat(false)
	resource_bar.overlay.dismiss()
	ui.hide()
	view_kind = "battle"
	battle = BOARD.instantiate()
	battle.expedition = state
	var setup = state.prepare_battle(index)
	setup.battle_seed = battle_seed
	preload("res://scripts/combat/battle_adapter.gd").configure(battle, setup)
	battle.expedition_continue.connect(_battle_finished)
	battle.expedition_restart.connect(_restart)
	battle.expedition_exit.connect(_exit)
	add_child(battle)
	if persistence_enabled:
		battle.settings_button.menu.configure_save_quit(_save_and_quit, true)


# Continue returns here after result recording; sync post-battle repairs before removing the board.
func _battle_finished() -> void:
	state.sync_battle(battle.battle_result())
	state.active_battle = -1
	_remove_battle()
	show_system()


func _remove_battle() -> void:
	if is_instance_valid(battle):
		if not battle.result_recorded: battle.checkpoint_exit = true
		remove_child(battle)
		battle.queue_free()
	battle = null


func _restart() -> void:
	if not persistence_enabled or state.run_ended or state.hull <= 0:
		if start_expedition(): _remove_battle()
		return
	var notice := ConfirmationDialog.new()
	notice.dialog_text = "Starting a new expedition will permanently abandon your current run."
	add_child(notice)
	notice.confirmed.connect(func():
		if start_expedition(): _remove_battle()
		notice.queue_free())
	notice.canceled.connect(notice.queue_free)
	notice.popup_centered(Vector2i(520, 180))


func _exit() -> void:
	_save_and_quit()


func _prepare_departure() -> void:
	if is_instance_valid(battle) and not battle.result_recorded:
		battle.checkpoint_exit = true
	if state != null and state.progress_committed.is_connected(_progress_committed):
		state.progress_committed.disconnect(_progress_committed)


func _go_to_menu() -> void:
	_prepare_departure()
	get_tree().paused = false
	var setup = load("res://scenes/battle_setup.tscn").instantiate()
	setup.initial_settings = {"player_ship": selected_ship}
	setup.save_store = save_store
	get_parent().add_child(setup)
	get_tree().current_scene = setup
	queue_free()


#endregion

#region Field repairs


# Install the UI component; state validation and spending stay in this controller.
func _setup_field_repairs() -> void:
	field_repairs = FieldRepairControls.new()
	resource_bar.overlay.extra.add_child(field_repairs)
	field_repairs.description_changed.connect(
		func(text: String): resource_bar.overlay.body.text = text
	)
	field_repairs.repair_requested.connect(_confirm_field_repair)


func _show_hull_info() -> void:
	var overlay: CanvasLayer = resource_bar.overlay
	overlay.show_text(resource_bar.entries.hull.get_meta("description"))
	if view_kind != "system" or not state.field_repairs_open:
		return
	overlay.desired_height = 480
	overlay.extra.show()
	field_repairs.present(state, resource_bar.heading("hull", "Hull"))
	overlay._fit()


func _confirm_field_repair(amount: int, revision: int) -> void:
	if (
		view_kind != "system"
		or not resource_bar.overlay.shade.visible
		or not resource_bar.overlay.extra.visible
		or field_repairs.confirm.disabled
	):
		return
	if not state.field_repair(amount, revision):
		return
	resource_bar.exploration(state)
	field_repairs.refresh_after_repair()

#endregion
