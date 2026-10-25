extends Control

const Sound = preload("res://scripts/audio/sfx.gd")
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
@export var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
const OutpostScreen = preload("res://scripts/ui/outpost_screen.gd")
const ExpeditionScreen = preload("res://scripts/ui/expedition_screen.gd")
const ExpeditionText = preload("res://scripts/ui/expedition_text.gd")
const CardManagement = preload("res://scripts/ui/card_management_screen.gd")
const FieldRepairControls = preload("res://scripts/ui/field_repair_controls.gd")
var outpost_screen: OutpostScreen
var screen: ExpeditionScreen
var card_management: CardManagement
var _card_owner: Resource
var _card_revision: int = -1
# Presentation aliases for existing expedition callers.
var replacement_key: String:
	get: return card_management.selected_card.identity_key() if is_instance_valid(card_management) and card_management.selected_card != null else ""
var replacement_selection: Label:
	get: return card_management.selection if is_instance_valid(card_management) else null
var replace_button: Button:
	get: return card_management.confirm_button if is_instance_valid(card_management) else null
var incoming_portrait: Button:
	get: return card_management.incoming_portrait if is_instance_valid(card_management) else null
var card_gallery: VBoxContainer:
	get: return card_management.gallery if is_instance_valid(card_management) and card_management.shade.visible else null
# TUNE: Disable to restore the original grid; both presentations use the same encounter state.
@export var use_star_map: bool = true
## Disable for the temporary 2D map fallback.
@export var use_3d_star_map: bool = true
@export var star_system_settings: Resource = preload("res://resources/presentation/star_system_settings.tres")
# TUNE: Seconds before a selected map destination opens; no travel cost or rules change.
@export_range(0.1, 2.0, 0.1) var star_map_travel_duration: float = 1.4
@export_group("Hull warning")
## TUNE: Seconds per soft double heartbeat, maximum draw scale, and red tint strength.
@export_range(1.0, 3.0, 0.05) var hull_pulse_period: float = 1.45
@export_range(1.0, 1.04, 0.005) var hull_pulse_scale: float = 1.03
@export_range(0.0, 0.5, 0.01) var hull_pulse_intensity: float = 0.22
@export_group("")
var settings_button: Button:
	get: return screen.settings_button if is_instance_valid(screen) else null
var field_repairs: VBoxContainer
var station_preview: VBoxContainer:
	get: return outpost_screen.preview if is_instance_valid(outpost_screen) else null
var star_map: Control
var transition: CanvasLayer
# Ephemeral presentation only; authoritative travel/rewards remain in State/Deck.
enum Phase { OVERVIEW, TRAVELING, CHASEDOWN, DESTINATION, RESOLVING, REWARD, BATTLE_ENTRY, BATTLE, FTL, EXITED }
var phase: Phase = Phase.OVERVIEW
var _presentation_revision: int = 0
var transitioning: bool:
	get: return phase in [Phase.BATTLE_ENTRY, Phase.FTL]
var map_system: int = -1
var map_destination: int = -1

@export var rules: Resource = preload("res://encounters/expedition_rules.tres")
## Optional accessibility preference; bundled emoji render by default on Android.
@export var text_icons_on_android: bool = false
var approach_note: Label:
	get: return outpost_screen.note if is_instance_valid(outpost_screen) else screen.approach_note
var repair_selector: HSlider:
	get: return outpost_screen.selector if is_instance_valid(outpost_screen) else null
var service_confirmation_revision: int:
	get:
		return outpost_screen.revision if is_instance_valid(outpost_screen) else -1
var return_to_outpost: bool = false
var selected_ship: int = 0
var state: Resource
var battle: Node
var view: VBoxContainer:
	get: return screen.view if is_instance_valid(screen) else null
var resource_bar: HFlowContainer:
	get: return screen.resource_bar if is_instance_valid(screen) else null
var legend: Button:
	get: return screen.legend if is_instance_valid(screen) else null
var deck_button: Button:
	get: return screen.deck_button if is_instance_valid(screen) else null
var current_deck_viewer: CanvasLayer
var outcome_flash: CanvasLayer
var presenting_outcome: bool:
	get: return phase == Phase.RESOLVING
var mission_header: Label:
	get: return screen.mission_header if is_instance_valid(screen) else null
var heading_row: HBoxContainer:
	get: return screen.heading_row if is_instance_valid(screen) else null
var jump_button: Button:
	get: return screen.jump_button if is_instance_valid(screen) else null
var return_button: Button:
	get: return screen.return_button if is_instance_valid(screen) else null
var confirmation: CanvasLayer:
	get: return outpost_screen.confirmation if is_instance_valid(outpost_screen) else screen.confirmation
var confirm_button: Button:
	get: return outpost_screen.confirm_button if is_instance_valid(outpost_screen) else screen.confirm_button
var title: Label:
	get: return screen.title if is_instance_valid(screen) else null
var ui: MarginContainer:
	get: return screen.ui if is_instance_valid(screen) else null
var scroll: ScrollContainer:
	get: return screen.scroll if is_instance_valid(screen) else null
var header: PanelContainer:
	get: return screen.header if is_instance_valid(screen) else null
var footer: HBoxContainer:
	get: return outpost_screen.footer if is_instance_valid(outpost_screen) else screen.footer
var more_hint: Control:
	get: return screen.more_hint if is_instance_valid(screen) else null
var grid: GridContainer:
	get: return outpost_screen.options if is_instance_valid(outpost_screen) else screen.grid
var selected_approach: int:
	get: return outpost_screen.selected_slot if is_instance_valid(outpost_screen) else screen.selected_approach
var approach_buttons: Array[Button]:
	get: return outpost_screen.buttons if is_instance_valid(outpost_screen) else screen.approach_buttons
var view_kind: String:
	get:
		if is_instance_valid(card_management) and card_management.shade.visible and not card_management.closing:
			return "replacement" if card_management.mode == "replace" else "outcome"
		return screen.kind if is_instance_valid(screen) else ""
var selected_encounter: int = -1

#region Screen initialization


func _ready() -> void:
	_build_ui()
	card_management = CardManagement.new()
	add_child(card_management)
	card_management.confirmed.connect(_management_confirmed)
	card_management.declined.connect(_management_declined)
	card_management.save_quit_button.visible = persistence_enabled
	card_management.save_quit_requested.connect(func():
		if phase == Phase.REWARD and not card_management.closing: _save_and_quit())
	card_management.closed.connect(func():
		screen.process_mode = Node.PROCESS_MODE_INHERIT
		_card_owner = null
		_card_revision = -1)
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
	transition = preload("res://scripts/presentation/star_system/white_transition.gd").new()
	add_child(transition)
	screen = ExpeditionScreen.new()
	screen.hull_pulse_period = hull_pulse_period
	screen.hull_pulse_scale = hull_pulse_scale
	screen.hull_pulse_intensity = hull_pulse_intensity
	add_child(screen)
	screen.deck_requested.connect(_show_current_deck)
	screen.main_menu_requested.connect(_exit)
	screen.hull_requested.connect(_show_hull_info)
	screen.return_requested.connect(show_system)
	screen.cancel_requested.connect(_cancel_approach)
	screen.confirm_requested.connect(_confirm_approach)
	screen.jump_requested.connect(_jump)


func _label(text: String, font_size: int = 20) -> Label:
	return screen._label(text, font_size)


func _button(
	text: String, callback: Callable, disabled: bool = false, height: float = 64
) -> Button:
	return screen.add_action(text, callback, disabled, height)


func _grid(columns: int) -> GridContainer:
	return screen.add_grid(columns)


func _tile(
	parent: Node,
	heading: String,
	details: String,
	color: Color,
	callback: Callable,
	disabled: bool = false,
	centered: bool = false
) -> Button:
	return screen.add_tile(parent, heading, details, color, callback, disabled, centered)


func _icon(key: String) -> String:
	return Presentation.icon(
		key, get_theme_default_font(), text_icons_on_android and OS.has_feature("android")
	)


# Rebuild only the current exploration view while keeping ExpeditionState and map destination alive.
func _clear(kind: String, preserve_transition: bool = false) -> void:
	if not preserve_transition:
		_cancel_presentation()
	current_deck_viewer.dismiss()
	field_repairs.clear()
	if is_instance_valid(outpost_screen):
		outpost_screen.clear()
	outpost_screen = null
	card_management.dismiss()
	state.field_repairs_open = kind == "system" and state.hull > 0
	if not _uses_3d_map():
		if is_instance_valid(star_map) and star_map.get_parent() == screen:
			screen.remove_child(star_map)
			star_map.queue_free()
			screen.map_layer = null
		star_map = null
	screen.reset_view(kind, state, use_star_map, _icon)
	if _uses_3d_map() and is_instance_valid(star_map) and not star_map.visual_data.is_empty():
		title.text = star_map.visual_data.name
	if not preserve_transition:
		phase = {"system": Phase.OVERVIEW, "chasedown": Phase.CHASEDOWN,
			"poi": Phase.DESTINATION, "preview": Phase.DESTINATION}.get(kind, Phase.REWARD)
	if _uses_3d_map():
		var split: bool = kind in ["poi", "preview", "chasedown"] or (
			kind == "outcome" and state.pending_choice.is_empty() and map_destination != -1
		)
		var show_map: bool = kind == "system" or split
		screen.map_layout(show_map, split)
		if is_instance_valid(star_map):
			star_map.set_active(state.hull > 0 and show_map)
			if kind == "system":
				star_map.overview()
			else:
				star_map.interactive = false
				if split:
					star_map.focus(map_destination)
	else:
		screen.map_layout(false, false)


func _begin_presentation(next: Phase) -> int:
	card_management.dismiss(true)
	_presentation_revision += 1
	phase = next
	return _presentation_revision


func _presentation_current(revision: int, owner: Resource) -> bool:
	return revision == _presentation_revision and state == owner and is_inside_tree() and not is_queued_for_deletion() and phase != Phase.EXITED


func _cancel_presentation() -> void:
	# Invalidate first: cancellation wakes waiters synchronously.
	_presentation_revision += 1
	if is_instance_valid(screen):
		screen.cancel_pending()
	if is_instance_valid(outcome_flash):
		outcome_flash.cancel()
	if is_instance_valid(transition):
		transition.cancel()
	if is_instance_valid(star_map) and star_map.has_method("cancel_presentation"):
		if star_map.traveling or transitioning:
			star_map.cancel_presentation()


# Both scene handoffs reveal only after the new presentation has initialized.
func _reveal_presentation(revision: int, owner: Resource, next: Phase) -> void:
	await get_tree().process_frame
	if not _presentation_current(revision, owner):
		return
	if await transition.fade(0.0, star_system_settings.white_fade_duration):
		if _presentation_current(revision, owner):
			phase = next
	else:
		_abort_presentation(revision, owner, next)


func _abort_presentation(revision: int, owner: Resource, next: Phase) -> void:
	if _presentation_current(revision, owner):
		_cancel_presentation()
		phase = next
		if is_instance_valid(star_map) and _uses_3d_map():
			star_map.overview()


func _travel_started() -> void:
	if phase == Phase.OVERVIEW:
		phase = Phase.TRAVELING


#endregion

#region System navigation


func start_expedition() -> bool:
	var candidate = State.new()
	candidate.start(selected_ship, rules)
	if persistence_enabled and not save_store.save_run(candidate):
		_show_save_error()
		return false
	_cancel_presentation()
	phase = Phase.OVERVIEW
	if is_instance_valid(star_map) and star_map.get_parent() == screen:
		screen.remove_child(star_map)
		star_map.queue_free()
		star_map = null
		screen.map_layer = null
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
	if phase == Phase.EXITED:
		return true
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
	if is_instance_valid(card_management): card_management.dismiss(true)
	_cancel_presentation()
	phase = Phase.EXITED
	if persistence_enabled:
		get_tree().auto_accept_quit = _previous_auto_quit
		get_tree().quit_on_go_back = _previous_back_quit


func show_system(preserve_transition: bool = false) -> void:
	if phase == Phase.EXITED or presenting_outcome or (transitioning and not preserve_transition):
		return
	if state.hull > 0 and state.chasedown_unresolved():
		if state.active_battle < 0:
			if state.encounters[state.chasedown_index].response < 0:
				_show_chasedown()
			else:
				start_battle(state.chasedown_index)
		return
	if not state.pending_choice.is_empty():
		show_outcome()
		return
	get_node("/root/Music").play_starmap()
	return_to_outpost = false
	_clear("system", preserve_transition)
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

	var destination: int = state.travel_destination
	if destination != -1:
		_resume_navigation.call_deferred(destination, _presentation_revision, state)


# Adapt generated encounters to presentation entries; arrival uses visit, exactly like grid selection.
func _map_input_allowed() -> bool:
	return (
		phase != Phase.EXITED and not transitioning and not resource_bar.overlay.shade.visible
		and not current_deck_viewer.shade.visible
		and not card_management.shade.visible
		and not settings_button.menu.shade.visible
	)


func _uses_3d_map() -> bool:
	return use_star_map and use_3d_star_map


func _show_star_map(resume_travel: bool = true) -> void:
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
				"name": encounter.title,
				"model_kind": key,
				"profile": state.enemy_profile(encounter) if encounter.kind == "battle" else null,
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
				"name": "Trading Outpost",
				"model_kind": "trading_outpost",
				"text": _icon("trading_outpost") + " Trading Outpost\nFree return · 0 FTL",
				"tooltip": "Independent service station",
				"color": Color("8fcab7"),
				"completed": false
			}
		)
	var new_map: bool = not is_instance_valid(star_map)
	if _uses_3d_map():
		if new_map:
			star_map = preload("res://scenes/star_system_3d.tscn").instantiate()
			star_map.settings = star_system_settings
			screen.mount_map(star_map)
		star_map.run_seed = state.seed_used
		star_map.system_number = state.system_number
		star_map.player_profile = state.ship()
		star_map.input_allowed = _map_input_allowed
	else:
		star_map = preload("res://scripts/ui/star_map.gd").new()
		star_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
		star_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		view.add_child(star_map)
		new_map = true
	star_map.configure(
		entries, map_destination, star_map_travel_duration,
		hash("%d:%d:sky" % [state.seed_used, state.system_number])
	)
	if _uses_3d_map():
		title.text = star_map.visual_data.name
	var stopped: Array = state.intercepted_position()
	if stopped.size() == 3 and _uses_3d_map():
		star_map.orbit_index = -1
		star_map.ship.position = Vector3(stopped[0],stopped[1],stopped[2])
	elif stopped.size() == 2 and not _uses_3d_map():
		star_map.ship_position = Vector2(stopped[0],stopped[1])
	star_map.before_travel = state.can_visit
	star_map.intercept_travel = state.begin_travel
	if new_map:
		var source_map: Control = star_map
		star_map.travel_started.connect(func():
			if star_map == source_map: _travel_started())
		star_map.interrupted.connect(func():
			if star_map == source_map and phase == Phase.TRAVELING: _show_chasedown())
		star_map.arrived.connect(func(index: int):
			if star_map == source_map and phase == Phase.TRAVELING: visit(index))
	var destination: int = state.travel_destination
	if resume_travel and destination != -1:
		_resume_navigation.call_deferred(destination, _presentation_revision, state, star_map)


func visit(index: int) -> void:
	if phase == Phase.EXITED or transitioning or not state.can_visit(index):
		return
	map_destination = index
	state.arrive_destination(index)
	if state.encounter_at(index).kind == "battle":
		show_battle_preview(index)
	else:
		show_poi(index)


func _jump() -> void:
	if transitioning or presenting_outcome or not state.can_jump():
		return
	if not _uses_3d_map() or not is_instance_valid(star_map):
		if state.generate_system():
			show_system()
		return
	var revision: int = _begin_presentation(Phase.FTL)
	var departing_state: Resource = state
	if not await star_map.ftl_departure(transition):
		_abort_presentation(revision, departing_state, Phase.OVERVIEW)
		return
	if not _presentation_current(revision, departing_state):
		return
	# Sole progression call, after reaching white. Rebuild without unlocking input.
	if state.generate_system():
		show_system(true)
	else:
		star_map.overview()
	await _reveal_presentation(revision, departing_state, Phase.OVERVIEW)


# Deferred resume is scoped to its overview and model, not merely a still-live node.
func _resume_navigation(destination: int, revision: int, owner: Resource, source: Control = null) -> void:
	if not _presentation_current(revision, owner) or phase != Phase.OVERVIEW or view_kind != "system":
		return
	if source != null:
		if source == star_map and source.is_inside_tree():
			source.travel(destination)
	else:
		_grid_travel(destination)


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
	if transitioning or phase == Phase.EXITED:
		return
	if _uses_3d_map() and not is_instance_valid(star_map):
		_show_star_map(false)
	if is_instance_valid(star_map):
		var stopped: Array = [star_map.ship.position.x,star_map.ship.position.y,star_map.ship.position.z] if _uses_3d_map() else [star_map.ship_position.x,star_map.ship_position.y]
		state.stop_intercepted_travel(stopped)
		star_map.cancel_presentation()
		if _uses_3d_map():
			star_map.orbit_index = -1
			star_map._select_destination(-1)
	else:
		state.stop_intercepted_travel()
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
		_label("Travel cancelled · Previous destination: " + state.encounters[state.pending_destination].title, 18)
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
	if not transitioning and state.choose_chasedown_response(index):
		_enter_battle(state.chasedown_index)


#endregion

#region Approaches and outposts


func show_battle_preview(index: int) -> void:
	if transitioning or phase == Phase.EXITED:
		return
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
	_button("Enter combat", _enter_battle.bind(index))
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
	if transitioning or phase == Phase.EXITED:
		return
	if index == state.SERVICE_INDEX:
		show_outpost()
		return
	selected_encounter = index
	_clear("poi")
	var poi: Resource = state.encounter_at(index).poi
	approach_note.text = ""
	confirm_button.text = "Initiate"
	header.configure(poi)
	if _uses_3d_map():
		view.add_child(_label(poi.description, 18))
	var options = _grid(1 if _uses_3d_map() else 2)
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
	if transitioning or phase == Phase.EXITED:
		return
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
	if _uses_3d_map():
		view.add_child(_label(state.service.poi.description, 18))
	jump_button.hide()
	outpost_screen = OutpostScreen.new()
	view.add_child(outpost_screen)
	outpost_screen.configure(state, scroll.allows_activation)
	outpost_screen.purchase_requested.connect(_purchase_outpost_service.bind(outpost_screen))
	# Preserve existing control accessors while the component owns their lifecycle.
	if _uses_3d_map():
		outpost_screen.options.columns = 1
	ui.set_deferred("size", size)


func _purchase_finished() -> void:
	if not state.pending_choice.is_empty():
		show_outcome()
	elif return_to_outpost:
		show_outpost()
		outpost_screen.show_purchase_complete()
	else:
		show_outcome()


func _select_approach(slot: int) -> void:
	if presenting_outcome:
		return
	if view_kind != "poi" or not state.can_visit(selected_encounter):
		return
	if selected_encounter == state.SERVICE_INDEX:
		if is_instance_valid(outpost_screen):
			outpost_screen.select_service(slot)
		return
	if slot == -2:
		if not state.can_survey(selected_encounter, _uses_3d_map()):
			return
	else:
		var poi: Resource = state.encounter_at(selected_encounter).poi
		if (
			slot < 0
			or slot >= poi.approaches.size()
			or not state.locked_reason(poi.approaches[slot]).is_empty()
		):
			return
	var selected_title: String = (
		"Navigation survey"
		if slot == -2
		else state.encounter_at(selected_encounter).poi.approaches[slot].title
	)
	screen.select_approach(slot, selected_title)


func _cancel_approach() -> void:
	if is_instance_valid(outpost_screen):
		outpost_screen.cancel_selection()
		return
	screen.cancel_approach()


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
		_approach(selected_encounter, selected_approach, _uses_3d_map())


func _purchase_outpost_service(
	slot: int, amount: int, revision: int, source: OutpostScreen
) -> void:
	if (
		(presenting_outcome or transitioning or phase == Phase.EXITED)
		or view_kind != "poi"
		or not is_instance_valid(source)
		or source != outpost_screen
	):
		return
	if state.purchase_service(slot, revision, amount):
		return_to_outpost = true
		_purchase_finished()


func _survey(index: int, suspense: bool = false) -> void:
	if presenting_outcome or transitioning:
		return
	if state.survey(index):
		await _present_resolved_outcome(suspense, false)


# One presentation-only insertion point; the outcome was already committed/autosaved.
func _present_resolved_outcome(suspense: bool, flash: bool) -> void:
	var revision: int = _begin_presentation(Phase.RESOLVING)
	var resolved_state: Resource = state
	if suspense and not await screen.result_suspense(star_system_settings.result_suspense_duration):
		return
	if not _presentation_current(revision, resolved_state):
		return
	if flash:
		await outcome_flash.play(state.last_poi_success == 1)
	if _presentation_current(revision, resolved_state):
		phase = Phase.DESTINATION
		show_outcome()


func _approach(index: int, slot: int, suspense: bool = false) -> void:
	if presenting_outcome or transitioning:
		return
	if index == state.SERVICE_INDEX:
		if is_instance_valid(outpost_screen):
			_purchase_outpost_service(slot, int(repair_selector.value), service_confirmation_revision, outpost_screen)
		return
	if state.resolve_approach(index, slot):
		await _present_resolved_outcome(suspense, true)


#endregion

#region Rewards and decks


func show_outcome() -> void:
	if transitioning or phase == Phase.EXITED:
		return
	if state.pending_choice == "upgrade" and (state.upgrades_remaining <= 0 or state.upgrade_candidates().is_empty()):
		state.finish_upgrades()
	if state.pending_choice in ["card", "upgrade", "replace"]:
		_present_card_management()
		return
	_clear("outcome")
	screen.present_result(state, visual_settings, _uses_3d_map())
	match state.pending_choice:
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


func _choose_card(index: int) -> void:
	if state.choose_card(index):
		Sound.play(&"upgrade_acquired", self)
		_purchase_finished()


func _present_card_management() -> void:
	# Keep the underlying view intact. The modal alone owns gallery/details/input.
	if not card_management.shade.visible or card_management.closing:
		_cancel_presentation()
	phase = Phase.REWARD
	_card_owner = state
	_card_revision = _presentation_revision
	current_deck_viewer.dismiss()
	screen.resource_bar.overlay.dismiss()
	screen.confirmation.dismiss()
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var cards: Array = state.card_offers if state.pending_choice == "card" else (
		state.player_pool() if state.pending_choice == "replace" else state.upgrade_candidates())
	var result_context: String = ""
	if state.last_poi_success >= 0:
		result_context = "Mission Successful" if state.last_poi_success == 1 else "Mission Compromised"
	card_management.present(state.pending_choice, cards, state.upgrades_remaining, state.pending_card, state.deck_limit(), result_context)


func _management_current(revision: int) -> bool:
	return (
		_presentation_current(_card_revision, _card_owner) and phase == Phase.REWARD
		and revision == card_management.revision and state.pending_choice == card_management.mode
	)


func _management_confirmed(mode: String, card: Resource, revision: int) -> void:
	if not _management_current(revision):
		return
	match mode:
		"card": _choose_card(state.card_offers.find(card))
		"upgrade": _upgrade(card.identity_key())
		"replace": _replace_card()


func _management_declined(revision: int) -> void:
	if _management_current(revision):
		_decline_card()


func _preview_card(card: Resource) -> void:
	card_management.select_card(card)


func _show_current_deck() -> void:
	if presenting_outcome or card_management.shade.visible:
		return
	resource_bar.overlay.dismiss()
	current_deck_viewer.show_cards(
		state.player_pool(),
		(
			state.ship().ship_name
			+ " · Deck: %d / %d · Read only" % [state.player_pool().size(), state.deck_limit()]
		)
	)


func _upgrade(key: String) -> void:
	if state.choose_upgrade(key):
		Sound.play(&"upgrade_acquired", self)
		show_outcome()


func _attribute(key: String) -> void:
	if state.choose_attribute(key):
		Sound.play(&"upgrade_acquired", self)
		_purchase_finished()


func _select_replacement(card: Resource) -> void:
	if state.pending_choice == "replace":
		card_management.select_card(card)


func _replace_card() -> void:
	if state.replace_card(replacement_key):
		_purchase_finished()


func _decline_card() -> void:
	if state.decline_card():
		_purchase_finished()


#endregion

#region Battle handoff


# Presentation wrapper; checkpointing and combat setup remain in start_battle.
func _enter_battle(index: int) -> void:
	if transitioning or presenting_outcome or not state.can_visit(index):
		return
	if not _uses_3d_map() or not is_instance_valid(star_map):
		start_battle(index)
		return
	var revision: int = _begin_presentation(Phase.BATTLE_ENTRY)
	var entering_state: Resource = state
	if not await star_map.battle_entry(transition):
		_abort_presentation(revision, entering_state, Phase.DESTINATION)
		return
	if not _presentation_current(revision, entering_state):
		return
	start_battle(index)
	if not is_instance_valid(battle):
		star_map.overview()
	await _reveal_presentation(revision, entering_state, Phase.BATTLE if is_instance_valid(battle) else Phase.DESTINATION)


func start_battle(index: int, battle_seed: int = -1) -> void:
	if is_instance_valid(battle) or presenting_outcome or phase in [Phase.FTL, Phase.EXITED]:
		return
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
	screen.hide_for_battle()
	if not transitioning:
		phase = Phase.BATTLE
	if _uses_3d_map() and is_instance_valid(star_map):
		star_map.set_active(false)
	battle = BOARD.instantiate()
	battle.expedition = state
	var setup = state.prepare_battle(index)
	setup.battle_seed = battle_seed
	preload("res://scripts/combat/battle_adapter.gd").configure(battle, setup)
	battle.expedition_continue.connect(_battle_finished.bind(battle))
	battle.expedition_restart.connect(_restart_from_battle.bind(battle))
	battle.expedition_exit.connect(_exit_from_battle.bind(battle))
	add_child(battle)
	if persistence_enabled:
		battle.settings_button.menu.configure_save_quit(_save_and_quit, true)


# Continue returns here after result recording; sync post-battle repairs before removing the board.
func _battle_finished(source: Node = null) -> void:
	if source == null:
		source = battle
	if not is_instance_valid(source) or source != battle or phase == Phase.EXITED or not is_inside_tree() or is_queued_for_deletion():
		return
	state.sync_battle(source.battle_result())
	state.active_battle = -1
	_remove_battle()
	phase = Phase.OVERVIEW
	show_system()


func _remove_battle() -> void:
	var previous: Node = battle
	battle = null
	if is_instance_valid(previous):
		if not previous.result_recorded:
			previous.checkpoint_exit = true
		remove_child(previous)
		previous.queue_free()


func _restart_from_battle(source: Node) -> void:
	if source == battle and phase != Phase.EXITED:
		_restart()


func _exit_from_battle(source: Node) -> void:
	if source == battle and phase != Phase.EXITED:
		_exit()


func _restart() -> void:
	if not persistence_enabled or state.run_ended or state.hull <= 0:
		if start_expedition(): _remove_battle()
		return
	var notice := ConfirmationDialog.new()
	notice.dialog_text = "Starting a new expedition will permanently abandon your current run."
	add_child(notice)
	var revision: int = _presentation_revision
	var restarting_state: Resource = state
	notice.confirmed.connect(func():
		if _presentation_current(revision, restarting_state):
			if start_expedition(): _remove_battle()
		notice.queue_free())
	notice.canceled.connect(notice.queue_free)
	notice.popup_centered(Vector2i(520, 180))


func _exit() -> void:
	_save_and_quit()


func _prepare_departure() -> void:
	_cancel_presentation()
	phase = Phase.EXITED
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
