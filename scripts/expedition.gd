extends Control

const WarzoneVictoryBanner = preload("res://scripts/ui/warzone_victory_banner.gd")
const StrategicOverview = preload("res://scripts/presentation/star_system/strategic_time_overview.gd")
const MenuPreferences = preload("res://scripts/ui/menu_preferences.gd")
const Sound = preload("res://scripts/audio/sfx.gd")
const WarzoneIcons = preload("res://scripts/ui/warzone_indicators.gd")
# RESPONSIBILITY: Route exploration screens and connect their choices to ExpeditionState.
# DOES NOT: Calculate rewards, generate encounters or implement combat rules.
# EXTEND: Route choices to State; _clear resets UI only, never the expedition ledger.
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const BattleSession = preload("res://scripts/expedition/expedition_battle.gd")
var persistence = Persistence.new()
var battle_session = BattleSession.new()
# Compatibility properties forward to the component's single owner.
var save_store:
	get: return persistence.store
	set(value): persistence.store = value
var persistence_enabled: bool:
	get: return persistence.enabled
	set(value): persistence.enabled = value
var resume_data: Dictionary = {}
var strategic_overview: StrategicOverview
var warzone_victory_banner: WarzoneVictoryBanner
var _warzone_victory_seen := 0
var _strategic_shutdown := false
var _application_suspended := false
var capture_hud = preload("res://scripts/ui/warzone_capture_hud.gd").new()
var _capture_hold := -1
var _capture_clock_usec := 0
var _wait_hold_active := false
var _wait_hold_clock_usec := 0
var _wait_hold_elapsed := 0.0
var developer_test: Dictionary = {}
var _developer_one_hit_kill := false
var save_error: AcceptDialog
var _battle_checkpoint: Dictionary:
	get: return persistence.battle_checkpoint
	set(value): persistence.battle_checkpoint = value
var _battle_marker: Dictionary:
	get: return persistence.battle_marker
	set(value): persistence.battle_marker = value
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
enum Phase { OVERVIEW, TRAVELING, CHASEDOWN, DESTINATION, RESOLVING, REWARD, BATTLE_ENTRY, BATTLE, FTL, INTRO, EXITED }
var phase: Phase = Phase.OVERVIEW
var _deck_trim_previous_phase := -1
var _shop_slot := -1
var _shop_revision := -1
var _presentation_revision: int = 0
var transitioning: bool:
	get: return phase in [Phase.BATTLE_ENTRY, Phase.FTL, Phase.INTRO]
var inspecting: bool = false
var inspection_backing_color: Color
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
var play_system_intro := false
var selected_ship: int = 0
var state: Resource
var battle: Node:
	get: return battle_session.current if is_instance_valid(battle_session.current) else null
	set(value): battle_session.current = value
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
		if (is_instance_valid(card_management) and card_management.shade.visible
			and not card_management.closing and card_management.mode != "purchase"):
			return "replacement" if card_management.mode == "replace" else "outcome"
		return screen.kind if is_instance_valid(screen) else ""
var selected_encounter: int = -1

#region Screen initialization


var homeworld_sequence = preload("res://scripts/presentation/star_system/homeworld_sequence.gd").new()
var homeworld_previous_phase: Phase = Phase.OVERVIEW

func _ready() -> void:
	if resume_data.has("state"):
		developer_test = resume_data.state.developer_test
	if not developer_test.is_empty():
		persistence_enabled = false
	add_child(homeworld_sequence)
	homeworld_sequence.finished.connect(func():
		if state != null and not state.run_ended and phase == Phase.INTRO:
			phase = homeworld_previous_phase
			state.navigation.rebase_movement(state.navigation.position))
	_build_ui()
	strategic_overview = StrategicOverview.new()
	add_child(strategic_overview)
	add_child(capture_hud)
	capture_hud.cancel_requested.connect(_stop_capture_hold.bind("Hold cancelled"))
	warzone_victory_banner = WarzoneVictoryBanner.new()
	add_child(warzone_victory_banner)
	warzone_victory_banner.dismissed.connect(_finish_warzone_aftermath)
	screen.overview_hud.system_details_requested.connect(_show_system_details)
	screen.overview_hud.warzone_wait_requested.connect(_wait_in_warzone)
	screen.overview_hud.warzone_wait_held.connect(func(pressed: bool):
		if pressed: _start_hold_wait()
		else: _end_hold_wait())
	screen.overview_hud.lattice_overlay_changed.connect(func(enabled: bool):
		if is_instance_valid(star_map) and state.is_warzone(): star_map.set_lattice_overlay(enabled))
	_setup_decoy_controls()
	card_management = CardManagement.new()
	add_child(card_management)
	card_management.confirmed.connect(_management_confirmed)
	card_management.declined.connect(_management_declined)
	card_management.save_quit_button.visible = persistence_enabled or not developer_test.is_empty()
	if not developer_test.is_empty():
		card_management.save_quit_button.text = "Exit Test"
	card_management.save_quit_requested.connect(func():
		if (phase == Phase.REWARD or card_management.mode == "purchase") and not card_management.closing: _save_and_quit())
	card_management.closed.connect(func():
		screen.process_mode = Node.PROCESS_MODE_INHERIT
		_card_owner = null
		_card_revision = -1
		_shop_slot = -1
		_shop_revision = -1
		if _deck_trim_previous_phase >= 0:
			if phase == Phase.REWARD:
				phase = _deck_trim_previous_phase as Phase
			_deck_trim_previous_phase = -1)
	current_deck_viewer = preload("res://scripts/ui/deck_viewer.gd").new()
	add_child(current_deck_viewer)
	outcome_flash = preload("res://scripts/ui/outcome_flash.gd").new()
	outcome_flash.visual_settings = visual_settings
	add_child(outcome_flash)
	_setup_field_repairs()
	if persistence_enabled or not developer_test.is_empty():
		_previous_auto_quit = get_tree().auto_accept_quit
		get_tree().auto_accept_quit = false
		_previous_back_quit = get_tree().quit_on_go_back
		get_tree().quit_on_go_back = false
		_configure_settings_exit(settings_button.menu)
	if resume_data.is_empty():
		start_expedition()
	else:
		state = resume_data.state
		if state.is_warzone() and state.warzone.complete: _warzone_victory_seen = state.warzone.get_instance_id()
		selected_ship = state.player_ship
		_bind_progress()
		var marker: Dictionary = resume_data.get("battle", {})
		if marker.is_empty():
			show_system()
		else:
			start_battle(int(marker.index), int(marker.seed), marker.get("environment", {}), marker.get("combat", {}))

	if play_system_intro and not resume_data.is_empty() and view_kind == "system" and _uses_3d_map(): _introduce_system()

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
	screen.return_requested.connect(func():
		if inspecting: _dismiss_inspection()
		else: show_system())
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
	_end_hold_wait(false, false)
	_stop_capture_hold("", false)
	_cancel_decoy()
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
	screen.reset_view(kind, state, use_star_map or state.is_defense() or state.is_warzone(), _icon)
	if _uses_3d_map() and kind == "outcome" and not is_instance_valid(star_map) and state.navigation_origin != -1:
		_show_star_map(false)
	if _uses_3d_map() and is_instance_valid(star_map) and not star_map.visual_data.is_empty():
		_set_system_name(star_map.visual_data.name)
		screen.set_faction(_faction_profile())
	if not preserve_transition:
		phase = {"system": Phase.OVERVIEW, "chasedown": Phase.CHASEDOWN,
			"poi": Phase.DESTINATION, "preview": Phase.DESTINATION}.get(kind, Phase.REWARD)
	if _uses_3d_map():
		var split: bool = kind in ["poi", "preview", "chasedown"] or (
			kind == "outcome" and map_destination != -1
		)
		var show_map: bool = kind == "system" or split
		screen.map_layout(show_map and state.hull > 0, split)
		if is_instance_valid(star_map):
			star_map.set_active(state.hull > 0 and show_map)
			if kind == "system":
				star_map.overview()
			else:
				star_map.interactive = inspecting
				if split and not inspecting:
					star_map.focus(map_destination)
					if kind == "outcome":
						var context: Dictionary = state.encounter_at(map_destination)
						if context.kind in ["poi","service"]:
							header.configure(context.poi,"Trading Outpost" if context.kind == "service" else "")
							header.show()
	else:
		screen.map_layout(false, false)


func _begin_presentation(next: Phase) -> int:
	if state != null: state.navigation.rebase_movement()
	card_management.dismiss(true)
	_presentation_revision += 1
	phase = next
	return _presentation_revision


func _presentation_current(revision: int, owner: Resource) -> bool:
	return revision == _presentation_revision and state == owner and is_inside_tree() and not is_queued_for_deletion() and phase != Phase.EXITED


func _cancel_presentation() -> void:
	if is_instance_valid(warzone_victory_banner): warzone_victory_banner.finish()
	homeworld_sequence.cancel()
	if state != null: state.navigation.rebase_movement()
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
		if state.is_warzone(): screen.set_warzone_status(state)


#endregion

#region System navigation


func start_expedition() -> bool:
	var candidate = State.new()
	candidate.start(selected_ship, rules, 0, developer_test)
	if not persistence.save_candidate(candidate):
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
	_developer_one_hit_kill = false
	persistence.reset_battle()
	_bind_progress()
	show_system()
	if play_system_intro and _uses_3d_map(): _introduce_system()
	return true


func _bind_progress() -> void:
	if not state.defense_advanced.is_connected(_defense_span_committed): state.defense_advanced.connect(_defense_span_committed)
	if not state.defense_activity_updated.is_connected(_defense_updated): state.defense_activity_updated.connect(_defense_updated)
	if not state.warzone_advanced.is_connected(_warzone_updated): state.warzone_advanced.connect(_warzone_updated)
	if not state.progress_committed.is_connected(_progress_committed):
		state.progress_committed.connect(_progress_committed)


func _progress_committed() -> void:
	if state.is_defense(): _refresh_defense_hud()
	if state.is_warzone(): screen.set_warzone_status(state)
	if is_instance_valid(battle) and battle.result_recorded:
		battle.settings_button.menu.battle_restart_notice = false
	if persistence_enabled and strategic_overview.activity == null and not _save_progress():
		_show_save_error()


func _save_progress() -> bool:
	if strategic_overview.activity != null: _finish_strategic_action()
	_checkpoint_navigation_position()
	return persistence.save_progress(state, battle)


func _show_save_error() -> void:
	if not is_instance_valid(save_error):
		save_error = AcceptDialog.new()
		save_error.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(save_error)
	save_error.dialog_text = save_store.error
	save_error.popup_centered(Vector2i(520, 180))


func _configure_settings_exit(menu: CanvasLayer, in_battle: bool = false) -> void:
	if not developer_test.is_empty():
		menu.configure_test_exit(_save_and_quit)
	elif persistence_enabled:
		menu.configure_save_quit(_save_and_quit, in_battle)


func _run_strategic_action(action: Callable) -> bool:
	if strategic_overview.active or _capture_hold >= 0 or _wait_hold_active:
		return false
	var previous_phase := phase
	var owner: Resource = state
	var present := Callable()
	if is_instance_valid(star_map) and star_map.visible and not is_instance_valid(battle) \
		and MenuPreferences.strategic_time_overview():
		present = func(activity, settle):
			_begin_presentation(Phase.RESOLVING)
			strategic_overview.begin(activity, settle, star_map, screen)
			if state.is_warzone(): _warzone_updated(false)
	if not action.call(present):
		return false
	if strategic_overview.active:
		await strategic_overview.finished
		if owner != state or phase == Phase.EXITED or not is_inside_tree():
			return false
		phase = previous_phase
	return not _strategic_shutdown


func _finish_strategic_action() -> void:
	if is_instance_valid(strategic_overview):
		strategic_overview.finish_immediately()


func _save_and_quit() -> bool:
	if phase == Phase.EXITED:
		return true
	_end_hold_wait()
	_stop_capture_hold("", false)
	_strategic_shutdown = true
	_finish_strategic_action()
	_strategic_shutdown = false
	if developer_test.is_empty() and not _save_progress():
		_show_save_error()
		return false
	_go_to_menu()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_application_suspended = true
		_end_hold_wait(false, false)
		_stop_capture_hold("Hold paused")
		_finish_strategic_action()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_application_suspended = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_end_hold_wait()
		_stop_capture_hold("", false)
		_strategic_shutdown = true
		_finish_strategic_action()
		_strategic_shutdown = false
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(strategic_overview) and strategic_overview.active:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _wait_hold_active:
		_end_hold_wait()
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _capture_hold >= 0:
		_stop_capture_hold("Hold cancelled")
		return
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and _wait_hold_active:
		_end_hold_wait(false, false)
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and _capture_hold >= 0:
		_capture_clock_usec = Time.get_ticks_usec()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_instance_valid(warzone_victory_banner) and warzone_victory_banner.active:
		warzone_victory_banner.finish()
		return
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED] and is_instance_valid(strategic_overview):
		strategic_overview.rebase_clock()
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_RESUMED]:
		_navigation_clock = Time.get_ticks_msec()
		if state != null: state.navigation.rebase_movement()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and inspecting:
		_dismiss_inspection()
		return
	if (not persistence_enabled and developer_test.is_empty()) or state == null: return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var cinematic_board = battle
		if is_instance_valid(cinematic_board) and cinematic_board.has_method("_presentation_locked") and cinematic_board._presentation_locked():
			cinematic_board.cinematic_director.skip()
			return
	if phase == Phase.INTRO and what in [NOTIFICATION_WM_GO_BACK_REQUEST,NOTIFICATION_APPLICATION_PAUSED]:
		_cancel_presentation()
		phase = Phase.OVERVIEW
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen.system_details_overlay.shade.visible:
			screen.system_details_overlay.dismiss()
			return
		if not decoy_camera.is_empty() or decoy_confirmation.shade.visible:
			_cancel_decoy()
			return
		var construction: Control = _construction_panel()
		if is_instance_valid(construction) and construction.visible:
			construction.hide()
			return
		var menu = battle.settings_button.menu if is_instance_valid(battle) else settings_button.menu
		menu.present()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		if persistence_enabled and not _save_progress(): _show_save_error()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not persistence_enabled or _save_progress():
			_prepare_departure()
			get_tree().quit()
		else: _show_save_error()


func _exit_tree() -> void:
	_strategic_shutdown = true
	if is_instance_valid(card_management): card_management.dismiss(true)
	_cancel_presentation()
	phase = Phase.EXITED
	if persistence_enabled or not developer_test.is_empty():
		get_tree().auto_accept_quit = _previous_auto_quit
		get_tree().quit_on_go_back = _previous_back_quit


func _set_system_name(value: String) -> void:
	screen.set_system_name(value if developer_test.is_empty() else "Test · " + value)


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
	if not (state.is_defense() and state.run_ended) and not state.pending_choice.is_empty():
		show_outcome()
		return
	get_node("/root/Music").play_starmap()
	return_to_outpost = false
	_clear("system", preserve_transition)
	if state.hull <= 0 or state.run_ended:
		if state.is_defense() and state.defense.failed() and _uses_3d_map():
			_show_star_map(false)
			screen.map_layout(true,false)
			star_map.set_active(true)
			phase = Phase.INTRO
			homeworld_sequence.begin(star_map,state,true,_exit)
			return
		var defeat_message: String = "Expedition ended — your ship was lost."
		if _uses_3d_map():
			screen.map_layout(false, false)
			if is_instance_valid(star_map): star_map.set_active(false)
		view.add_child(_label(defeat_message, 26))
		_button("Main Menu", _exit)
		return
	if state.is_defense() and state.defense.contact >= 0:
		_show_star_map(false)
		show_battle_preview(state.defense.contact)
		return
	if state.is_defense() and state.defense.missiles.pending >= 0:
		_show_star_map(false)
		_show_missile(state.defense.missiles.pending)
		return
	if use_star_map or state.is_defense() or state.is_warzone():
		_show_star_map()
		return
	screen.present_system_grid(state, _icon, _grid_travel)
	if not developer_test.is_empty(): _set_system_name(state.system_name)

	var destination: int = state.travel_destination
	if destination != -1:
		_resume_navigation.call_deferred(destination, _presentation_revision, state)


# Adapt generated encounters to presentation entries; arrival uses visit, exactly like grid selection.
func _construction_panel() -> Control:
	if state == null or not state.is_defense() or not is_instance_valid(star_map): return null
	var effects: Node3D = star_map.defense_effects
	if not is_instance_valid(effects) or not is_instance_valid(effects.construction): return null
	return effects.construction.popup

func _map_input_allowed(block_construction: bool = true, during_capture: bool = false) -> bool:
	if block_construction:
		var construction: Control = _construction_panel()
		if is_instance_valid(construction) and construction.visible: return false
	return (
		phase != Phase.EXITED and not _wait_hold_active and (during_capture or _capture_hold < 0) and not _application_suspended and not warzone_victory_banner.active and not strategic_overview.active and not transitioning and not screen.focus_transition and not screen.confirmation.shade.visible and not resource_bar.overlay.shade.visible
		and (not is_instance_valid(decoy_confirmation) or not decoy_confirmation.shade.visible)
		and not current_deck_viewer.shade.visible
		and not card_management.shade.visible
		and not settings_button.menu.shade.visible
		and not screen.system_details_overlay.shade.visible
	)


func _uses_3d_map() -> bool:
	return (state != null and (state.is_defense() or state.is_warzone())) or (use_star_map and use_3d_star_map)


func _show_star_map(resume_travel: bool = true) -> void:
	var new_system: bool = map_system != state.system_number
	if map_system != state.system_number:
		map_system = state.system_number
		map_destination = state.navigation_origin
	var new_map: bool = not is_instance_valid(star_map)
	# The lattice scene and the fleet markers are already maintained by
	# warzone_advanced. Only discovery completion can change on this return.
	if not new_map and not new_system and state.is_warzone() and star_map.warzone_view == state.warzone \
		and not state.navigation.leg_active:
		for key in state.encounter_positions:
			var index := int(key)
			if star_map.markers.has(index):
				star_map.markers[index].disabled = state.encounters[index].completed
				star_map.markers[index].set_state(state.encounters[index].completed, false, false)
		_set_system_name(star_map.visual_data.name)
		screen.set_warzone_status(state)
		return
	var entries: Array = screen.map_entries(state, _icon)
	if _uses_3d_map():
		if new_map:
			star_map = preload("res://scenes/star_system_3d.tscn").instantiate()
			star_map.settings = star_system_settings
			screen.mount_map(star_map)
		star_map.environment_source = state.environment_view
		star_map.modifier_source = state.preview_modifier
		star_map.run_seed = state.seed_used
		star_map.system_number = state.system_number
		star_map.layout_expansion = state.layout_expansion
		star_map.orbit_clearance = state.orbit_clearance
		star_map.system_variation = state.system_variation.duplicate(true)
		star_map.system_profile = state.system_profile
		star_map.player_profile = state.ship()
		star_map.defense_view = state.defense_map_view() if state.is_defense() else {}
		star_map.warzone_view = state.warzone
		if state.is_warzone() and state.warzone.is_lattice():
			var lattice: Button = screen.overview_hud.lattice_button
			if new_system: lattice.set_pressed_no_signal(true)
			star_map.lattice_overlay_enabled = lattice.button_pressed
		star_map.locator_exclusions = func():
			var areas: Array = []
			for panel in screen.overview_hud.panels:
				if panel.is_visible_in_tree():
					var rect: Rect2 = panel.get_global_rect()
					rect.position -= star_map.global_position
					areas.append(rect)
			return areas
		star_map.speed_profile = state.travel_speed_profile
		star_map.physical_speed = state.rules.defense_tuning.player_speed if state.is_defense() or state.is_warzone() else 0.0
		star_map.hold_threshold_msec = roundi(state.rules.defense_tuning.inspection_hold_seconds * 1000.0)
		star_map.double_tap_msec = roundi(state.rules.defense_tuning.double_tap_seconds * 1000.0)
		star_map.touch_confirmation_required = state.is_defense() or state.is_warzone()
		star_map.input_allowed = _map_input_allowed
		star_map.turret_options = _turret_options if state.is_defense() else Callable()
		star_map.turret_requested = _deploy_turret if state.is_defense() else Callable()
		star_map.inspection_area = func(): return screen.sidebar.get_global_rect()
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
		_set_system_name(star_map.visual_data.name)
		screen.set_faction(_faction_profile())
	if _uses_3d_map():
		screen.overview_hud.attach_zoom(star_map)
		screen._sync_map_rect()
		if new_system: star_map.fit_overview()
	if _uses_3d_map() and state.navigation.position.size() == 3 and (state.is_defense() or state.is_warzone() or new_map or state.navigation.leg_active or state.navigation_origin == state.FREE_DESTINATION or not state.intercepted_position().is_empty()):
		var at: Array = state.navigation.position
		star_map.apply_navigation_position(Vector3(at[0], at[1], at[2]))
	var stopped: Array = state.intercepted_position()
	if stopped.size() == 3 and _uses_3d_map():
		star_map.orbit_index = -1
		star_map.ship.position = Vector3(stopped[0],stopped[1],stopped[2])
	elif stopped.size() == 2 and not _uses_3d_map():
		star_map.ship_position = Vector2(stopped[0],stopped[1])
	if _uses_3d_map(): star_map.destination_for = state.navigation_destination
	star_map.before_travel = state.can_visit
	star_map.intercept_travel = _begin_map_travel
	if _uses_3d_map():
		star_map.before_free_travel = func(_point: Vector3): return state.can_navigate()
		star_map.intercept_free_travel = _begin_free_travel
	if new_map:
		var source_map: Control = star_map
		if _uses_3d_map():
			star_map.inspect_requested.connect(_inspect_marker)
			star_map.inspection_dismissed.connect(_dismiss_inspection)
			star_map.free_move_requested.connect(func(point: Vector3):
				if star_map == source_map: source_map.travel_to_position(point))
			star_map.travel_boundary.connect(func():
				if star_map == source_map: _sample_navigation_position())
			star_map.free_arrived.connect(func():
				if star_map == source_map: _free_arrived())
		star_map.travel_started.connect(func():
			if star_map == source_map: _travel_started())
		star_map.interrupted.connect(func():
			if star_map == source_map and phase == Phase.TRAVELING: _show_chasedown())
		star_map.arrived.connect(func(index: int):
			if star_map == source_map and phase == Phase.TRAVELING: visit(index))
	if state.is_defense():
		_set_system_name(star_map.visual_data.name)
		screen.set_faction(_faction_profile())
		_refresh_defense_hud()
		if state.defense.reveal_pending: _reveal_mothership.call_deferred()
	elif state.is_warzone():
		_set_system_name(state.system_name)
		screen.set_warzone_status(state)
	var destination: int = state.travel_destination
	if resume_travel and destination != -1:
		_resume_navigation.call_deferred(destination, _presentation_revision, state, weakref(star_map))


func visit(index: int) -> void:
	if phase == Phase.EXITED or transitioning:
		return
	if index >= State.Defense.Missiles.FIRST_ID:
		_free_arrived()
		return
	var moving_hostile: bool = state.is_defense() and not state.defense.unit_for(index).is_empty()
	if not moving_hostile and not state.can_visit(index) and not state.objective_locked(index): return
	_sample_navigation_position(true)
	if state.is_warzone() and (phase != Phase.TRAVELING or not state.can_visit(index)):
		return
	if phase != Phase.TRAVELING and state.is_defense(): return
	_checkpoint_navigation_position()
	if state.is_warzone() and not state.warzone_fleet(index).is_empty() and not state.can_engage(index):
		if state.warzone.complete:
			state.cancel_travel()
			show_system()
		else:
			star_map.travel(index)
		return
	if moving_hostile:
		# The target has moved or arrived. Only a swept contact opens combat.
		state.arrive_destination(index)
		map_destination = -1
		phase = Phase.OVERVIEW
		_clear("system")
		return
	map_destination = index
	state.arrive_destination(index)
	state.identify_objective(index)
	if state.encounter_at(index).kind == "battle":
		show_battle_preview(index)
	else:
		show_poi(index)


func _jump() -> void:
	if not decoy_camera.is_empty(): return
	if transitioning or presenting_outcome or warzone_victory_banner.active or not state.can_jump():
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
		await _introduce_system(true)
		return
	else:
		star_map.overview()
	await _reveal_presentation(revision, departing_state, Phase.OVERVIEW)


func _introduce_system(reveal_white: bool = false) -> void:
	var revision: int = _begin_presentation(Phase.INTRO)
	var owner: Resource = state
	var hud: Control = screen.overview_hud
	hud.prepare_introduction(star_map.visual_data.name,state.system_number)
	star_map.begin_introduction()
	if reveal_white: transition.fade(0.0,star_system_settings.white_fade_duration)
	if not await hud.introduce(star_system_settings.introduction_duration): return
	if not _presentation_current(revision,owner): return
	star_map.finish_introduction()
	phase = Phase.OVERVIEW


# Deferred resume is scoped to its overview and model, not merely a still-live node.
func _resume_navigation(destination: int, revision: int, owner: Resource, source_ref: WeakRef = null) -> void:
	if not _presentation_current(revision, owner) or phase != Phase.OVERVIEW or view_kind != "system":
		return
	var source: Control = source_ref.get_ref() if source_ref != null else null
	if source != null:
		if source == star_map and source.is_inside_tree():
			if destination == state.FREE_DESTINATION and _uses_3d_map():
				var point: Array = state.navigation.target
				if point.size() == 3: source.travel_to_position(Vector3(point[0],point[1],point[2]), false)
			else: source.travel(destination)
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
	if screen.compact_focus:
		return_button.disabled = true
		return_button.tooltip_text = "Resolve the interception first"
	jump_button.hide()
	title.text = "Sublight Chasedown"
	var encounter: Dictionary = state.encounters[state.chasedown_index]
	if _uses_3d_map(): star_map.tactical_focus(state.chasedown_index,true,state.enemy_profile(encounter))
	_add_tactical_briefing(encounter,state.enemy_profile(encounter),true,state.chasedown_index)
	var choices = _grid(2)
	if screen.compact_focus: choices.add_theme_constant_override("v_separation",4)
	for index in range(state.rules.chasedown_responses.size()):
		var response: Dictionary = state.rules.chasedown_responses[index]
		var details: String = state.describe_modifiers(response.get("modifiers", {}))
		if int(response.get("hull", 0)) != 0:
			details += " · %+d Hull (minimum 1)" % int(response.hull)
		if details.is_empty():
			details = "No starting modifiers"
		var response_button = _tile(
			choices,
			str(response.title),
			details,
			Presentation.COLORS.battle,
			_chasedown_response.bind(index)
		)
		if screen.compact_focus:
			response_button.minimum_height = 52
			response_button.heading.add_theme_font_size_override("font_size",18)
			response_button.details.add_theme_font_size_override("font_size",16)
			response_button.set_rich_details(highlight_outcome(ExpeditionText.effect_indicators(details)))
			response_button.details.add_theme_font_size_override("normal_font_size",16)
			response_button.details.add_theme_font_size_override("bold_font_size",16)


func _chasedown_response(index: int) -> void:
	if not transitioning and state.choose_chasedown_response(index):
		_enter_battle(state.chasedown_index)


#endregion

#region Approaches and outposts


func show_battle_preview(index: int) -> void:
	if transitioning or phase == Phase.EXITED:
		return
	if not (state.can_visit(index) if inspecting else state.can_engage(index)):
		return
	_clear("preview")
	if state.is_defense(): return_button.hide()
	var encounter: Dictionary = state.encounters[index]
	var enemy: Resource = state.enemy_profile(encounter)
	if inspecting: view.add_child(_label("INSPECTION · Tap outside to close", 15))
	if _uses_3d_map() and not inspecting: star_map.tactical_focus(index)
	_add_tactical_briefing(encounter, enemy, false, index)
	if state.is_warzone():
		var fleet: Dictionary = state.warzone_fleet(index)
		var operation = state.warzone
		_add_fleet_readout(fleet, operation)
		var ally: Dictionary = operation.allied_support(fleet.id)
		if not ally.is_empty(): _add_fleet_readout(operation.fleet_at(ally.id), operation)
		if inspecting:
			view.add_child(_label("In range to intervene" if state.can_engage(index) else "Travel to engage", 15))
	var support: Dictionary = state.battle_support(index)
	if not support.is_empty():
		if state.is_warzone():
			view.add_child(_label("Support · %d damage / %d rounds · Half rewards" % [support.damage, support.interval], 15))
		else:
			view.add_child(_label("Friendly Turret Support · %d damage every %d rounds" % [support.damage, support.interval], 15))
	# Inspection only shows enemy information; entering combat requires arrival.
	if not inspecting:
		var enter = _button("Enter Combat", _enter_battle.bind(index))
		enter.name = "CombatEntry"
		if screen.compact_focus:
			enter.reparent(screen.sidebar)
		_style_combat_entry(enter)
	if not _uses_3d_map(): _button("Return", show_system)


func _add_fleet_readout(fleet: Dictionary, operation: RefCounted) -> void:
	var tint := WarzoneIcons.tint(fleet.side)
	_add_warzone_inspection_row(WarzoneIcons.icon("combat" if fleet.engaged >= 0 else "fleet", tint),
		"%s %s · %s" % [fleet.side.capitalize(), fleet.role, operation.fleet_status(fleet)], 16)
	var gauge := WarzoneIcons.bar(tint)
	gauge.name = "%sFleetStrength" % fleet.side.capitalize()
	gauge.max_value = fleet.get("strength_limit", operation.tuning.hostile_strength if fleet.side == "hostile"
		else operation.initial_allied_strength / operation.ALLIED_GROUPS)
	gauge.value = fleet.strength
	gauge.accessibility_name = "%s fleet strength %d of %d" % [fleet.side.capitalize(), fleet.strength, gauge.max_value]
	view.add_child(gauge)
	var order: String = operation.fleet_order_text(fleet) if operation.is_lattice() else operation.objective_name(fleet.destination)
	if operation.is_lattice() and fleet.engaged < 0:
		var distance: float = (fleet.position as Vector3).distance_to(operation.fleet_target_position(fleet))
		if distance > 0.1 and (not fleet.get("arriving", false) or operation.supplied[fleet.side].size() >= 2):
			order += " · ~%ds" % ceili(distance / operation.fleet_speed(fleet))
	view.add_child(_label("→ " + order, 15))


func _add_warzone_inspection_row(icon: Control, title: String, font_size: int) -> void:
	var row := HBoxContainer.new()
	row.add_child(icon)
	var label := _label(title, font_size)
	# Wrapped Labels report a zero minimum width. Give the text the space
	# left after the badge so a rebuild cannot collapse it to a narrow column.
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	view.add_child(row)


func _style_combat_entry(button: Button) -> void:
	screen.style_combat_entry(button)


func _add_tactical_briefing(encounter: Dictionary, enemy: Resource, pursuit: bool, index: int = -1) -> void:
	screen.add_tactical_briefing(state, encounter, enemy, pursuit, index)


# Keep balance/state descriptions intact; compact only the exploration presentation.
func compact_text(value: String) -> String:
	return ExpeditionText.compact_text(value)


func compact_outcome(outcome: Resource) -> String:
	return ExpeditionText.compact_outcome(state, outcome)


func highlight_outcome(value: String) -> String:
	return ExpeditionText.highlight_outcome(value)


func approach_text(approach: Resource) -> String:
	return ExpeditionText.approach_text(state, approach, _uses_3d_map())


func show_poi(index: int) -> void:
	if transitioning or phase == Phase.EXITED:
		return
	if index == state.SERVICE_INDEX:
		show_outpost()
		return
	selected_encounter = index
	_clear("poi")
	if state.is_warzone() and not state.warzone_objective(index).is_empty():
		_show_warzone_objective(index)
		return
	screen.present_poi(state, index, _uses_3d_map(), inspecting, _icon, _select_approach)


func _show_warzone_objective(index: int) -> void:
	var objective: Dictionary = state.warzone_objective(index)
	if objective.is_empty(): return
	header.hide()
	var presentation := preload("res://scripts/presentation/star_system/warzone_presentation.gd")
	var operation = state.warzone
	var offset := index - State.Warzone.HOSTILE_GROUPS
	var tint := presentation.objective_color(objective)
	var badge := _label(operation.objective_glyph(offset) if operation.is_lattice() else "◇", 25)
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	badge.add_theme_color_override("font_color", tint)
	_add_warzone_inspection_row(badge, state.encounters[index].title, 25)
	var status: String = presentation.objective_status(objective)
	if operation.is_lattice():
		status += " · Disrupted" if operation.disrupted.has(offset) else (
			" · Supplied" if operation.is_supplied(offset) else " · Isolated")
	view.add_child(_label("Territorial Control", 17))
	view.add_child(_label(status, 15))
	if operation.is_lattice() and not operation.complete and objective.owner != "allied":
		var capture_status := "Clear the garrison and hold position."
		if not operation._capture_connected(offset, "allied"):
			capture_status = "Capture requires a supplied allied link."
		elif operation.capture_cutoffs.has(offset) and operation.capture_cutoffs[offset].side == "allied":
			capture_status = "Capture interrupted. Leave and return to retry."
		view.add_child(_label(capture_status, 14))
	var can_hold: bool = not inspecting and operation.is_lattice() and _capture_hold_block(index).is_empty()
	if objective.progress > 0 or can_hold:
		var capture := WarzoneIcons.bar(WarzoneIcons.tint(objective.capturing if objective.progress > 0 else "allied"))
		capture.max_value = operation.tuning.capture_seconds
		capture.value = objective.progress
		capture.accessibility_name = "%s capture progress %d of %d" % [objective.capturing, objective.progress, capture.max_value]
		view.add_child(capture)
	if operation.complete: return
	if not inspecting:
		if not operation.is_lattice():
			_button("Hold position · %ds" % operation.tuning.wait_seconds, _wait_in_warzone)
		elif can_hold:
			_button("Hold Until Captured", _start_capture_hold.bind(index))
	if operation.is_lattice():
		var choices: Array[Dictionary] = operation.operations(offset, state.salvage)
		if choices.is_empty(): return
		var action: Dictionary = choices.front()
		view.add_child(HSeparator.new())
		view.add_child(_label("Facility Operation", 17))
		_add_warzone_inspection_row(WarzoneIcons.icon(action.id, tint), action.title, 19)
		view.add_child(_label(action.details, 14))
		var quote := "%ds" % action.seconds
		if action.cost > 0: quote += " · %d Salvage" % action.cost
		if not action.reason.is_empty(): quote += " · " + action.reason
		view.add_child(_label(quote, 15))
		if action.remaining > 0:
			var recharge := WarzoneIcons.bar(tint)
			recharge.max_value = action.cooldown
			recharge.value = action.cooldown - action.remaining
			recharge.accessibility_name = "Facility recharges in %ds" % action.remaining
			view.add_child(recharge)
		if not inspecting:
			var activate := _button("Activate Operation", _warzone_operation.bind(index, action.id))
			activate.disabled = not action.enabled
	elif not inspecting:
		view.add_child(_label("Clear enemy fleets, then hold position to secure this objective.", 17))


func _warzone_operation(index: int, id: String) -> void:
	if phase == Phase.DESTINATION and await _run_strategic_action(func(present): return state.warzone_operate(index, id, present)):
		if state.warzone.complete: show_system()
		else: show_poi(index)


# Holding the button spends actual elapsed time, without invoking the
# fixed-duration cinematic strategic action. Release rounds UP to 0.5 s.
func _start_hold_wait() -> void:
	if _wait_hold_active or state == null or not state.is_warzone() or state.warzone.complete \
			or phase != Phase.OVERVIEW or state.navigation.leg_active or not state.can_navigate() \
			or not _map_input_allowed() or get_tree().paused:
		return
	_wait_hold_active = true
	_wait_hold_elapsed = 0.0
	_wait_hold_clock_usec = Time.get_ticks_usec()
	if is_instance_valid(star_map):
		# The Wait button is already a reserved map hit region. Consuming the
		# gesture here would swallow the matching touch-up before it can
		# finalize and round the hold.
		star_map.strategic_time_active = true
	screen.overview_hud.set_wait_held(true)


func _advance_hold_wait(seconds: float) -> void:
	if not _wait_hold_active or seconds <= 0.0 or state == null or state.warzone.complete: return
	var at: Vector3 = State.Defense.point(state.navigation.position)
	state.advance_warzone_map(seconds, at, at)
	_wait_hold_elapsed += seconds
	screen.overview_hud.set_wait_held(true, _wait_hold_elapsed)


func _end_hold_wait(round_forward: bool = true, sample_now: bool = true) -> void:
	if not _wait_hold_active: return
	# Include the last partial frame before rounding, even for a fast tap.
	if sample_now and round_forward and not get_tree().paused and not _application_suspended:
		var now := Time.get_ticks_usec()
		_advance_hold_wait(maxf(0.0, (now - _wait_hold_clock_usec) / 1000000.0))
	if round_forward and state != null and not state.warzone.complete:
		var rounded: float = maxf(0.5, float(ceili(_wait_hold_elapsed * 2.0 - 0.0000001)) * 0.5)
		_advance_hold_wait(maxf(0.0, rounded - _wait_hold_elapsed))
	_wait_hold_active = false
	_wait_hold_elapsed = 0.0
	_wait_hold_clock_usec = 0
	if is_instance_valid(star_map):
		star_map.strategic_time_active = false
		star_map.consume_gesture()
	if is_instance_valid(screen):
		screen.overview_hud.set_wait_held(false)
		screen.overview_hud.wait_touch_index = -1
	if state != null and not _application_suspended: state.progress_committed.emit()


func _wait_in_warzone() -> void:
	if state == null or phase not in [Phase.OVERVIEW, Phase.DESTINATION] or not _map_input_allowed():
		return
	if await _run_strategic_action(state.wait_in_warzone):
		show_system()


func _capture_hold_block(index: int) -> String:
	if phase != Phase.DESTINATION or not state.is_warzone() or not state.warzone.is_lattice() \
		or not state.can_navigate() or state.navigation.leg_active or is_instance_valid(battle):
		return "Objective unavailable"
	return state.warzone.capture_hold_block(index - State.Warzone.HOSTILE_GROUPS,
		State.Defense.point(state.navigation.position))


func _start_capture_hold(index: int) -> void:
	if not _map_input_allowed() or inspecting or not _capture_hold_block(index).is_empty(): return
	var offset := index - State.Warzone.HOSTILE_GROUPS
	var objective: Dictionary = state.warzone.objectives[offset]
	_capture_hold = index
	_capture_clock_usec = Time.get_ticks_usec()
	state.warzone.note_player_position(State.Defense.point(state.navigation.position))
	star_map.consume_gesture()
	star_map.overview()
	star_map.strategic_time_active = true
	screen.map_layout(true, false)
	screen.overview_hud.set_mode(screen.EdgeHUD.Mode.OVERVIEW)
	screen._sync_map_rect()
	screen.ui.hide()
	screen.focus_backing.hide()
	screen.return_button.hide()
	capture_hud.present(state.warzone.objective_name(offset), objective.progress if objective.capturing == "allied" else 0,
		state.warzone.player_capture_requirement(offset, State.Defense.point(state.navigation.position)))


func _advance_capture_hold(seconds: float) -> void:
	while _capture_hold >= 0:
		var reason := _capture_hold_block(_capture_hold)
		var can_present := _map_input_allowed(true, true)
		if not reason.is_empty() or not can_present:
			var message := reason if reason == "Objective secured" else "Capture interrupted · " \
				+ (reason if not reason.is_empty() else "Action interrupted")
			_stop_capture_hold(message, can_present or not reason.is_empty())
			if not can_present and reason.is_empty():
				phase = Phase.OVERVIEW
				state.progress_committed.emit()
			return
		if seconds <= 0.00000001: return
		var operation = state.warzone
		var point := State.Defense.point(state.navigation.position)
		# Stop on the first authoritative movement boundary which changes
		# eligibility, even when a slow frame covers multiple fixed steps.
		var step_ms: int = operation.motion_step_ms()
		var boundary: float = (step_ms - posmod(operation.clock_ms, step_ms) - operation.travel_ms_remainder) / 1000.0
		var slice := minf(seconds, boundary)
		state.advance_warzone_map(slice, point, point)
		seconds -= slice
		if _capture_hold < 0: return
		var offset := _capture_hold - State.Warzone.HOSTILE_GROUPS
		var objective: Dictionary = operation.objectives[offset]
		capture_hud.update_progress(operation.objective_name(offset), objective.progress if objective.capturing == "allied" else 0,
			operation.player_capture_requirement(offset, point))


func _stop_capture_hold(message: String, restore_overview: bool = true) -> void:
	if _capture_hold < 0: return
	_capture_hold = -1
	capture_hud.dismiss(message)
	if is_instance_valid(star_map):
		star_map.strategic_time_active = false
		star_map.consume_gesture()
	if restore_overview:
		show_system()
		if not _application_suspended: state.progress_committed.emit()


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
	header.configure(state.service.poi,"Trading Outpost")
	if _uses_3d_map():
		view.add_child(_label(state.service.poi.description, 18))
	jump_button.hide()
	outpost_screen = OutpostScreen.new()
	outpost_screen.compact = _uses_3d_map()
	view.add_child(outpost_screen)
	outpost_screen.configure(state, screen.allows_activation)
	outpost_screen.card_purchase_requested.connect(_present_shop_cards.bind(outpost_screen))
	outpost_screen.purchase_requested.connect(_purchase_outpost_service.bind(outpost_screen))
	if inspecting:
		for button in outpost_screen.buttons: button.disabled = true
		if outpost_screen.selector != null: outpost_screen.selector.editable = false
	# Preserve existing control accessors while the component owns their lifecycle.
	if _uses_3d_map():
		outpost_screen.options.columns = 1
	ui.set_deferred("size", size)


func _purchase_finished() -> void:
	if state.is_defense() and state.run_ended:
		show_system()
	elif not state.pending_choice.is_empty():
		show_outcome()
	elif return_to_outpost:
		show_outpost()
		outpost_screen.show_purchase_complete()
	else:
		show_outcome()


func _select_approach(slot: int) -> void:
	if inspecting: return
	if presenting_outcome:
		return
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
		var approaches: Array = state.poi_approaches(selected_encounter)
		if (
			slot < 0
			or slot >= approaches.size()
			or not state.locked_reason(approaches[slot]).is_empty()
		):
			return
	var selected_title: String = (
		"Navigation survey"
		if slot == -2
		else state.poi_approaches(selected_encounter)[slot].title
	)
	screen.select_approach(slot, selected_title)


func _cancel_approach() -> void:
	if is_instance_valid(outpost_screen):
		outpost_screen.cancel_selection()
		return
	screen.cancel_approach()


func _confirm_approach() -> void:
	if inspecting: return
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


func _present_shop_cards(slot: int, revision: int, source: OutpostScreen) -> void:
	if (inspecting or transitioning or presenting_outcome or phase == Phase.EXITED
		or source != outpost_screen or revision != state.service_revision
		or card_management.shade.visible or not state.service_locked_reason(slot).is_empty()):
		return
	var offers: Array[Resource] = state.service_card_offers(slot)
	if offers.is_empty():
		return
	_shop_slot = slot
	_shop_revision = revision
	_card_owner = state
	_card_revision = _presentation_revision
	source.cancel_selection()
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	var price: int = state.service_cost(slot)
	card_management.present("purchase", offers, 0, null, state.deck_limit(),
		"%d Salvage · Balance after purchase: %d" % [price, state.salvage - price])


func _shop_choice_current(revision: int) -> bool:
	return (card_management.mode == "purchase" and revision == card_management.revision
		and _presentation_current(_card_revision, _card_owner) and view_kind == "poi"
		and is_instance_valid(outpost_screen) and _shop_slot >= 0)


func _purchase_outpost_service(
	slot: int, amount: int, revision: int, card_index: int, source: OutpostScreen
) -> void:
	if (
		inspecting
		or (presenting_outcome or transitioning or phase == Phase.EXITED)
		or view_kind != "poi"
		or not is_instance_valid(source)
		or source != outpost_screen
	):
		return
	if await _run_strategic_action(func(present): return state.purchase_service(slot, revision, amount, card_index, present)):
		return_to_outpost = true
		_purchase_finished()


func _survey(index: int, suspense: bool = false) -> void:
	if presenting_outcome or transitioning:
		return
	if await _run_strategic_action(func(present): return state.survey(index, present)):
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
			_purchase_outpost_service(slot, int(repair_selector.value), service_confirmation_revision, -1, outpost_screen)
		return
	if await _run_strategic_action(func(present): return state.resolve_approach(index, slot, -1.0, present)):
		var guaranteed: bool = state.is_defense() and state.defense_poi_version == 1
		await _present_resolved_outcome(suspense and not guaranteed, not guaranteed)


#endregion

#region Rewards and decks


func show_outcome() -> void:
	if state.is_defense() and state.run_ended:
		show_system()
		return
	if transitioning or phase == Phase.EXITED:
		return
	if state.pending_choice == "battle_reward":
		_clear("outcome")
		view.add_child(_label("Victory reward", 28))
		_button("Upgrade Ship · Upgrade %d cards" % state.upgrades_remaining, _select_battle_reward.bind(false), state.upgrade_candidates().is_empty())
		_button("Acquire a Card · Choose 1 of %d" % state.card_offers.size(), _select_battle_reward.bind(true))
		return
	if state.pending_choice == "upgrade" and (state.upgrades_remaining <= 0 or state.upgrade_candidates().is_empty()):
		state.finish_upgrades()
	if state.pending_choice in ["card", "card_batch", "replace"] and state.player_pool().size() > state.deck_limit():
		_clear("outcome")
		view.add_child(_label("Deck exceeds the current limit. Keep your existing cards."))
		_button("Decline Reward", _decline_over_limit_reward)
		return
	if state.pending_choice in ["card", "card_batch", "upgrade", "replace"]:
		_present_card_management()
		return
	_clear("outcome")
	screen.present_rewards(state, visual_settings, _uses_3d_map(), _attribute, show_system)


func _decline_over_limit_reward() -> void:
	if state.decline_over_limit_reward():
		_purchase_finished()


func _select_battle_reward(acquire: bool) -> void:
	if state.choose_battle_reward(acquire):
		show_outcome()


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
	var cards: Array = state.card_offers if state.pending_choice in ["card","card_batch"] else (
		state.replacement_pool() if state.pending_choice == "replace" else state.upgrade_candidates())
	var result_context: String = ""
	if state.last_poi_success >= 0:
		result_context = "Mission Successful" if state.last_poi_success == 1 else "Mission Compromised"
	card_management.present(state.pending_choice, cards, state.upgrades_remaining, state.pending_card, state.deck_limit(), result_context)
	if state.card_batch_active():
		card_management.decline_button.hide()
		if state.pending_choice == "replace":
			card_management.heading.text = "Replace Card — Deck full: %d/%d cards" % [state.player_pool().size(),state.deck_limit()]
			card_management.instruction.text = "Keep both Tier 1 rewards. Select an owned card to replace."
			card_management.context.text = "Mandatory replacement · both rewards are kept"


func _management_current(revision: int) -> bool:
	return (
		_presentation_current(_card_revision, _card_owner) and phase == Phase.REWARD
		and revision == card_management.revision
		and (state.pending_choice == card_management.mode
			or (card_management.mode == "trim" and state.pending_choice.is_empty()))
	)


func _management_confirmed(mode: String, card: Resource, revision: int) -> void:
	if mode == "purchase":
		if _shop_choice_current(revision):
			var slot := _shop_slot
			var shop_revision := _shop_revision
			var offers: Array[Resource] = state.service_card_offers(slot)
			card_management.dismiss(true)
			_purchase_outpost_service(slot, 0, shop_revision, offers.find(card), outpost_screen)
		return
	if not _management_current(revision):
		return
	match mode:
		"card": _choose_card(state.card_offers.find(card))
		"card_batch":
			if state.confirm_card_batch(): _purchase_finished()
		"upgrade": _upgrade(card.identity_key())
		"replace": _replace_card()
		"trim":
			if state.trim_deck(card.identity_key()):
				if state.player_pool().size() > state.deck_limit():
					_present_legacy_deck_trim()
				else:
					card_management.dismiss()


func _management_declined(revision: int) -> void:
	if _shop_choice_current(revision):
		card_management.dismiss()
		return
	if _management_current(revision):
		if card_management.mode == "trim":
			card_management.dismiss()
		else:
			_decline_card()


func _preview_card(card: Resource) -> void:
	card_management.select_card(card)


func _present_legacy_deck_trim() -> void:
	if _deck_trim_previous_phase < 0:
		_deck_trim_previous_phase = phase
	phase = Phase.REWARD
	_card_owner = state
	_card_revision = _presentation_revision
	screen.process_mode = Node.PROCESS_MODE_DISABLED
	card_management.present("trim", state.player_pool(), 0, null, state.deck_limit())


func _show_current_deck() -> void:
	if transitioning or presenting_outcome or card_management.shade.visible:
		return
	resource_bar.overlay.dismiss()
	if state.pending_choice.is_empty() and state.player_pool().size() > state.deck_limit():
		_present_legacy_deck_trim()
		return
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
	if transitioning or presenting_outcome or not state.can_engage(index):
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


func start_battle(index: int, battle_seed: int = -1, environment: Dictionary = {}, combat: Dictionary = {}) -> void:
	if is_instance_valid(battle) or presenting_outcome or phase in [Phase.FTL, Phase.EXITED]:
		return
	if not state.can_engage(index) or state.encounters[index].kind != "battle":
		return
	var checkpoint: Dictionary = persistence.checkpoint_battle(state, index, battle_seed, environment, combat)
	battle_seed = checkpoint.seed
	if not checkpoint.saved:
		_show_save_error()
		if view_kind.is_empty():
			_clear("save_error")
			view.add_child(_label("The battle could not be resumed until its checkpoint can be saved."))
			_button("Retry Battle", start_battle.bind(index, battle_seed, checkpoint.environment, combat))
		return
	_stop_capture_hold("Capture interrupted · Battle started", false)
	state.field_repairs_open = false
	screen.hide_for_battle()
	if not transitioning:
		phase = Phase.BATTLE
	if _uses_3d_map() and is_instance_valid(star_map):
		star_map.set_active(false)
	battle_session.create(BOARD, state, index, battle_seed,
		_battle_finished, _restart_from_battle, _exit_from_battle, checkpoint.environment)
	battle.resume_combat = combat
	if not state.developer_test.is_empty():
		battle.developer_one_hit_kill = _developer_one_hit_kill
		battle.developer_one_hit_kill_changed.connect(func(enabled: bool): _developer_one_hit_kill = enabled)
	add_child(battle)
	_configure_settings_exit(battle.settings_button.menu, true)


# The result transaction already committed Hull and Salvage.
func _battle_finished(source: Node = null) -> void:
	if source == null:
		source = battle
	if not is_instance_valid(source) or source != battle or phase == Phase.EXITED or not is_inside_tree() or is_queued_for_deletion():
		return
	state.active_battle = -1
	_remove_battle()
	phase = Phase.OVERVIEW
	show_system()


func _remove_battle() -> void:
	battle_session.remove(self)


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
	_stop_capture_hold("", false)
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


# The legacy roll policy receives active gameplay time; navigation receives actual movement.
var _navigation_clock: int = 0

func _process(_delta: float) -> void:
	if is_instance_valid(settings_button): settings_button.disabled = homeworld_sequence.active
	if is_instance_valid(deck_button): deck_button.disabled = homeworld_sequence.active
	_update_decoy_controls()
	var now: int = Time.get_ticks_msec()
	var elapsed: float = maxf(0, (now - _navigation_clock) / 1000.0) if _navigation_clock > 0 else 0.0
	_navigation_clock = now
	if state == null: return
	if _wait_hold_active:
		var wait_usec := Time.get_ticks_usec()
		var held_seconds: float = maxf(0.0, (wait_usec - _wait_hold_clock_usec) / 1000000.0)
		_wait_hold_clock_usec = wait_usec
		if not get_tree().paused and not _application_suspended:
			_advance_hold_wait(held_seconds)
			if state.warzone.complete or not state.can_navigate() or phase != Phase.OVERVIEW:
				_end_hold_wait(false, false)
	if _capture_hold >= 0:
		var usec := Time.get_ticks_usec()
		var active_seconds := (usec - _capture_clock_usec) / 1000000.0
		_capture_clock_usec = usec
		if not get_tree().paused and not _application_suspended: _advance_capture_hold(active_seconds)
	if not is_instance_valid(screen) or get_tree().paused:
		state.navigation.rebase_movement()
		return
	if phase in [Phase.OVERVIEW, Phase.TRAVELING] and _map_input_allowed():
		state.advance_chasedown_cooldown(elapsed)
	_sample_navigation_position()
	if _intercept_warzone_player(): return
	# The navigation sample already advanced the clock. Test the latest position
	# for contact so moving fleets can be intercepted before a stale waypoint.
	if state.is_warzone() and phase == Phase.TRAVELING and is_instance_valid(star_map) \
		and star_map.traveling and _map_input_allowed() and state.travel_destination >= 0 \
		and state.can_engage(state.travel_destination):
		var contact: int = state.travel_destination
		star_map.apply_navigation_position(State.Defense.point(state.navigation.position))
		visit(contact)
	_present_homeworld_damage()
	_present_warzone_aftermath()

func _sample_navigation_position(arriving: bool = false) -> void:
	if state == null: return
	var eligible: bool = (
		state.navigation.leg_active and phase == Phase.TRAVELING and not get_tree().paused
		and _uses_3d_map() and is_instance_valid(star_map) and is_instance_valid(star_map.ship)
		and not star_map.focused and (star_map.traveling or arriving) and _map_input_allowed()
	)
	if not eligible:
		# Clear the sampling baseline, not the save position. Cosmetic tactical transforms
		# and movement hidden behind a modal must not catch up on the next active frame.
		state.navigation.rebase_movement()
		return
	var at: Vector3 = star_map.ship.position
	state.navigation.report_movement([at.x,at.y,at.z])


func _checkpoint_navigation_position() -> void:
	if state == null or not state.navigation.leg_active or phase != Phase.TRAVELING: return
	if not _uses_3d_map() or not is_instance_valid(star_map) or not is_instance_valid(star_map.ship) or star_map.focused: return
	var at: Vector3 = star_map.ship.position
	state.update_navigation_position([at.x,at.y,at.z])

func _begin_map_travel(index: int) -> bool:
	_sample_navigation_position()
	if _uses_3d_map():
		var at: Vector3 = star_map.ship.position
		state.update_navigation_position([at.x,at.y,at.z])
		if state.has_missile(index):
			return state.begin_free_travel(State.Defense.wire(state.defense.intercept_point(index, at)))
	return state.begin_travel(index)

func _begin_free_travel(point: Vector3) -> bool:
	_sample_navigation_position()
	var at: Vector3 = star_map.ship.position
	state.update_navigation_position([at.x,at.y,at.z])
	return state.begin_free_travel([point.x,point.y,point.z])

func _free_arrived() -> void:
	if phase != Phase.TRAVELING: return
	_sample_navigation_position(true)
	if phase != Phase.TRAVELING: return
	_checkpoint_navigation_position()
	state.arrive_free_destination()
	map_destination = -1
	phase = Phase.OVERVIEW
	_clear("system")

# Hostile pursuers reuse a real fleet contact and normal combat checkpoint.
# This is evaluated after committed movement and capture steps, not idle time.
func _intercept_warzone_player() -> bool:
	if not state.is_warzone() or not state.warzone.is_lattice() or state.warzone.complete \
			or phase not in [Phase.OVERVIEW, Phase.TRAVELING, Phase.DESTINATION] \
			or transitioning or presenting_outcome or _application_suspended \
			or not is_instance_valid(star_map) or not is_instance_valid(screen):
		return false
	if _capture_hold < 0 and (phase == Phase.DESTINATION or not _map_input_allowed()):
		return false
	var point: Vector3 = State.Defense.point(state.navigation.position)
	var contact: int = state.warzone.player_hunter_contact(point)
	if contact < 0 or not state.can_engage(contact): return false
	if _capture_hold >= 0:
		_stop_capture_hold("Capture interrupted · Hostile pursuit", true)
	elif phase == Phase.TRAVELING:
		star_map.apply_navigation_position(point)
		state.cancel_travel()
		map_destination = -1
	state.warzone.consume_player_hunter_contact()
	state.progress_committed.emit()
	_enter_battle(contact)
	return true


# Simulation decides events; coordinator cancels presentation and routes existing UI.
func _warzone_updated(target_lost: bool) -> void:
	if not state.is_warzone() or not is_instance_valid(star_map):
		return
	star_map.set_lattice_overlay(screen.overview_hud.lattice_button.button_pressed)
	screen.set_warzone_status(state)
	if warzone_victory_banner.active: screen.jump_button.disabled = true
	if target_lost and phase == Phase.TRAVELING:
		star_map.apply_navigation_position(State.Defense.point(state.navigation.position))
		star_map._select_destination(-1)
		map_destination = -1
		_clear("system")


func _present_warzone_aftermath() -> void:
	if phase != Phase.OVERVIEW or not state.is_warzone() or not state.warzone.is_lattice() \
		or not state.warzone.complete or state.warzone_outcome.is_empty() or not _map_input_allowed() \
		or not is_instance_valid(star_map) or not is_instance_valid(star_map.warzone_presentation):
		return
	var operation: RefCounted = state.warzone
	var presentation: Node3D = star_map.warzone_presentation
	if presentation.aftermath_started: return
	presentation.begin_aftermath(operation, state.warzone_outcome.grade, State.SystemLayout.bounds(state.layout_expansion))
	if MenuPreferences.skip_cinematics() or _warzone_victory_seen == operation.get_instance_id():
		_finish_warzone_aftermath()
		return
	_warzone_victory_seen = operation.get_instance_id()
	warzone_victory_banner.begin(state.warzone_outcome)
	get_node("/root/Music").play_result(true, 0 if state.warzone_outcome.grade == "Pyrrhic Victory" else 1)
	screen.jump_button.disabled = true
	resource_bar.exploration(state)


func _finish_warzone_aftermath() -> void:
	if not is_instance_valid(star_map) or not is_instance_valid(star_map.warzone_presentation): return
	star_map.warzone_presentation.finish_aftermath()
	screen.set_warzone_status(state)
	resource_bar.exploration(state)


func _defense_span_committed(events: Dictionary) -> void:
	# The overview already displayed these slices, including their impacts.
	if not strategic_overview.active:
		_defense_updated(events)


func _defense_updated(events: Dictionary) -> void:
	homeworld_sequence.record(state,events)
	if not _uses_3d_map() or not is_instance_valid(star_map): return
	star_map.sync_defense(state.defense_map_view())
	star_map.flash_missile_shots(events.get("missile_shots", []))
	# Strategic overview shows live pressure and movement. Travel alone opens
	# interception screens; action results are still routed by their caller.
	if strategic_overview.active:
		_refresh_defense_hud()
		if events.get("extraction_salvage", 0) > 0: resource_bar.exploration(state)
	if phase != Phase.TRAVELING: return
	if events.get("extraction_salvage", 0) > 0:
		resource_bar.exploration(state)
	_refresh_defense_hud()
	if events.contact >= 0 or events.get("missile_contact", -1) >= 0 or state.run_ended:
		star_map.apply_navigation_position(State.Defense.point(state.navigation.position))
		phase = Phase.OVERVIEW
		if state.run_ended: show_system()
		elif events.get("missile_contact", -1) >= 0: _show_missile(events.missile_contact)
		else:
			map_destination = events.contact
			show_battle_preview(events.contact)
	elif events.get("target_lost", false):
		star_map.apply_navigation_position(State.Defense.point(state.navigation.position))
		map_destination = -1
		phase = Phase.OVERVIEW
		_clear("system")
	elif events.get("decoy_changed", false):
		var index: int = state.travel_destination
		var unit: Dictionary = state.defense.unit_for(index)
		if not unit.is_empty() and state.defense.available(unit):
			var origin := State.Defense.point(state.navigation.position)
			_retarget_decoy_pursuit.call_deferred(index, origin)

# Called only after navigation sampling/routing. Modals and other cinematics keep
# the queue pending; the existing phase gates the strategic clock and all input.
func _present_homeworld_damage() -> void:
	if state == null or not state.is_defense() or state.run_ended: return
	if not homeworld_sequence.available(state): return
	if phase not in [Phase.OVERVIEW,Phase.TRAVELING] or not _map_input_allowed(): return
	if not is_instance_valid(star_map) or not star_map.visible or star_map.focused: return
	if star_map.camera.motion and star_map.camera.motion.is_running(): return
	homeworld_previous_phase = phase
	phase = Phase.INTRO
	homeworld_sequence.begin(star_map,state)


func _retarget_decoy_pursuit(index: int, origin: Vector3) -> void:
	if phase != Phase.TRAVELING or state.travel_destination != index or not is_instance_valid(star_map): return
	star_map.retarget_pursuit(index, state.defense.intercept_point(index, origin))

func _reveal_mothership() -> void:
	if not state.is_defense() or not state.defense.reveal_pending or phase != Phase.OVERVIEW: return
	# Commit once before animation: restoration never replays the reveal or rewards.
	state.consume_defense_reveal()
	var revision: int = _begin_presentation(Phase.INTRO)
	var owner: Resource = state
	screen.overview_hud.metagame.text = "WARNING · Mothership detected\nNeutralize it to unlock FTL"
	if is_instance_valid(star_map):
		var model: Node3D = star_map.objects[state.defense.mothership_index()]
		var original: Vector3 = model.scale
		model.scale = original * 0.05
		star_map.create_tween().tween_property(model, "scale", original, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(1.2).timeout
	if _presentation_current(revision, owner):
		phase = Phase.OVERVIEW
		_set_system_name(star_map.visual_data.name)
		screen.set_faction(_faction_profile())
		_refresh_defense_hud()

func _turret_options(site: String) -> Dictionary:
	var tuning: Resource = state.defense.tuning
	return {"salvage": state.salvage, "radius": tuning.turret_radius,
		"cost": tuning.turret_salvage_cost, "capacity": tuning.turret_capacity,
		"allowed": decoy_camera.is_empty() and phase == Phase.OVERVIEW and _map_input_allowed(false) and state.can_deploy_turret(site)}

func _deploy_turret(site: String) -> bool:
	if not decoy_camera.is_empty() or phase != Phase.OVERVIEW or not _map_input_allowed(false) or not state.deploy_turret(site):
		return false
	star_map.sync_defense(state.defense_map_view())
	resource_bar.exploration(state)
	screen.overview_hud.refresh()
	_refresh_defense_hud()
	return true

func _refresh_defense_hud() -> void:
	screen.set_defense_status(state)

# Read-only inspection reuses the existing encounter panels and does not focus
# or move the camera. A hold never commits a visit or encounter.
func _inspect_marker(index: int) -> void:
	if not decoy_camera.is_empty(): return
	if not (state.is_defense() or state.is_warzone()) or inspecting or phase not in [Phase.OVERVIEW, Phase.TRAVELING]: return
	var fleet: Dictionary = {}
	if state.is_warzone() and star_map.markers.has(index) and star_map.markers[index].has_meta("warzone_ally"):
		fleet = state.warzone.fleet_at(star_map.markers[index].get_meta("warzone_ally"))
		if not state.warzone.active(fleet): return
	elif not state.can_visit(index):
		return
	if phase == Phase.TRAVELING:
		_sample_navigation_position()
		if phase != Phase.TRAVELING: return
		state.cancel_travel()
		star_map.apply_navigation_position(State.Defense.point(state.navigation.position))
	inspecting = true
	var backing: StyleBoxFlat = screen.focus_backing.get_theme_stylebox("panel")
	inspection_backing_color = backing.bg_color
	backing.bg_color.a = 0.97
	star_map.inspection_active = true
	map_destination = index
	if not fleet.is_empty():
		_clear("preview")
		_add_fleet_readout(fleet, state.warzone)
		var hostile: Dictionary = state.warzone.fleet_at(fleet.engaged)
		if not hostile.is_empty() and state.warzone.active(hostile):
			var contact: int = state.warzone.encounter_for_fleet(hostile)
			view.add_child(_label("In range to assist" if state.can_engage(contact) else "Intercept the hostile fleet to assist", 15))
		else:
			view.add_child(_label("No hostile contact", 15))
	elif state.has_missile(index): _show_missile(index)
	elif state.encounter_at(index).kind == "battle": show_battle_preview(index)
	else: show_poi(index)
	return_button.visible = state.is_warzone()
	for option in screen.sidebar.find_children("*", "BaseButton", true, false):
		option.disabled = true

func _show_missile(index: int) -> void:
	if not state.has_missile(index): return
	map_destination = index
	selected_encounter = index
	_clear("poi")
	var missile: Dictionary = state.defense.missiles.active[index]
	view.add_child(_label("Incoming Missile", 26))
	view.add_child(_label("Hull %d · Bound for the homeworld" % missile.hull, 16))
	if inspecting: return
	return_button.hide()
	var options = screen.add_grid(1)
	screen.add_tile(options, "Direct Interception", "Destroy the missile · %.1f strategic seconds" % state.defense.tuning.missile_intercept_seconds,
		Color("75dce9"), _resolve_missile.bind(index, "direct"))
	screen.add_tile(options, "Precision Targeting", "Upgraded reactor · %.1f strategic seconds" % state.defense.tuning.missile_precision_seconds,
		Color("d3b1fa"), _resolve_missile.bind(index, "precision"), int(state.production_upgrades.get("reactor", 0)) <= 0)
	screen.add_tile(options, "EMP Disruption", "Spend one stored EMP charge · %.2f strategic seconds" % state.defense.tuning.missile_emp_seconds,
		Color("87e5ad"), _resolve_missile.bind(index, "emp"), state.modifier_value("emp_pulse_charge") <= 0)

func _resolve_missile(index: int, approach: String) -> void:
	if await _run_strategic_action(func(present): return state.resolve_missile(index, approach, present)):
		map_destination = -1
		show_system()

var decoy_button: Button
var decoy_confirmation: CanvasLayer
var decoy_panel: PanelContainer
var decoy_status: Label
var decoy_place: Button
var decoy_camera := {}
var decoy_last_point := Vector3.INF

func _setup_decoy_controls() -> void:
	decoy_confirmation = preload("res://scripts/ui/approach_confirmation.gd").new()
	add_child(decoy_confirmation)
	decoy_confirmation.initiate.text = "Deploy"
	decoy_confirmation.initiate.pressed.connect(_begin_decoy_placement)
	decoy_confirmation.cancelled.connect(decoy_confirmation.dismiss)
	decoy_button = Button.new()
	decoy_button.name = "DeployTacticalDecoy"
	decoy_button.custom_minimum_size = Vector2(64, 48)
	decoy_button.tooltip_text = "Deploy Tactical Decoy Beacon"
	for style in ["normal", "hover", "pressed"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("51242a") if style == "normal" else Color("753936")
		box.border_color = Color("ff8c7b")
		box.set_border_width_all(1)
		box.set_corner_radius_all(7)
		decoy_button.add_theme_stylebox_override(style, box)
	add_child(decoy_button)
	decoy_button.hide()
	decoy_button.pressed.connect(func():
		if _decoy_available():
			decoy_confirmation.present("Deploy Tactical Decoy?\nRedirect nearby enemy ships toward a location of your choice."))

func _decoy_available() -> bool:
	return state != null and phase == Phase.OVERVIEW and view_kind == "system" and not inspecting \
		and is_instance_valid(star_map) and star_map.has_method("decoy_point") \
		and state.navigation.position.size() == 3 and state.can_place_decoy() and _map_input_allowed()

func _begin_decoy_placement() -> void:
	decoy_confirmation.dismiss()
	if not _decoy_available(): return
	var camera = star_map.camera
	decoy_camera = {"transform": camera.transform, "pan": camera.pan_offset,
		"zoom": camera.zoom_scale, "target": camera.zoom_target}
	camera.cancel()
	var player := State.Defense.point(state.navigation.position)
	var offset: Vector3 = camera.position - star_map.decoy_point()
	var target := player.move_toward(Vector3.ZERO, 5.0)
	camera.pan_offset = Vector2(target.x, target.z) - Vector2(star_map.settings.overview_target.x, star_map.settings.overview_target.z)
	camera.position = target + offset
	star_map._end_pinch()
	star_map._select_destination(-1)
	star_map.decoy_preview = star_map.DecoyVisual.new()
	star_map.decoy_preview.configure(state.defense.tuning.decoy_attraction_radius, true)
	star_map.visual_root.add_child(star_map.decoy_preview)
	decoy_panel = PanelContainer.new()
	decoy_panel.z_index = 25
	star_map.add_child(decoy_panel)
	star_map.decoy_controls = decoy_panel
	var column := VBoxContainer.new()
	decoy_panel.add_child(column)
	decoy_status = _label("", 16)
	column.add_child(decoy_status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var cancel := Button.new()
	cancel.text = "Cancel"
	decoy_place = Button.new()
	decoy_place.text = "Place Decoy"
	for button in [cancel, decoy_place]:
		button.custom_minimum_size = Vector2(110, 48)
		actions.add_child(button)
	cancel.pressed.connect(func(): _cancel_decoy())
	decoy_place.pressed.connect(_place_decoy)
	decoy_last_point = Vector3.INF
	_update_decoy_controls()

func _update_decoy_controls() -> void:
	if not is_instance_valid(decoy_button): return
	if not decoy_camera.is_empty() and not _decoy_available():
		_cancel_decoy()
	var visible_now := decoy_camera.is_empty() and _decoy_available()
	if decoy_button.visible != visible_now:
		if visible_now:
			decoy_button.reparent(screen.overview_hud.utilities, false)
			screen.overview_hud.utilities.move_child(decoy_button, 0)
		else:
			decoy_button.reparent(self, false)
		decoy_button.visible = visible_now
		screen.overview_hud.queue_layout()
	if visible_now:
		decoy_button.text = "◎ %d" % state.decoys
		decoy_button.modulate.a = 0.88 + 0.12 * sin(Time.get_ticks_msec() * 0.004)
	if decoy_camera.is_empty() or not is_instance_valid(star_map.decoy_preview): return
	decoy_panel.position = Vector2((star_map.size.x - decoy_panel.size.x) * 0.5, star_map.size.y - decoy_panel.size.y - 18)
	var at: Vector3 = star_map.decoy_point()
	if at.is_equal_approx(decoy_last_point): return
	decoy_last_point = at
	var reason: String = state.decoy_placement(at)
	var radius: float = state.defense.tuning.decoy_attraction_radius
	var positions: Array[Vector3] = []
	if reason.is_empty():
		for index in state.defense.decoy_targets(at, radius):
			positions.append(state.defense.unit_for(index).position)
	decoy_place.disabled = not reason.is_empty()
	decoy_status.text = reason
	if reason.is_empty():
		match positions.size():
			0: decoy_status.text = "No enemies in range"
			1: decoy_status.text = "1 enemy in range"
			_: decoy_status.text = "%d enemies in range" % positions.size()
	star_map.decoy_preview.position = at
	star_map.decoy_preview.draw(radius, State.Defense.point(state.navigation.position),
		state.defense.tuning.decoy_deploy_range, positions, reason.is_empty())

func _place_decoy() -> void:
	if decoy_camera.is_empty() or not _map_input_allowed() or not state.deploy_decoy(star_map.decoy_point()): return
	_cancel_decoy(false)
	star_map.sync_defense(state.defense_map_view())

func _cancel_decoy(restore_camera: bool = true) -> void:
	if is_instance_valid(decoy_confirmation) and decoy_confirmation.shade.visible: decoy_confirmation.dismiss()
	if decoy_camera.is_empty(): return
	if is_instance_valid(star_map):
		var camera = star_map.camera
		if restore_camera:
			camera.cancel()
			camera.transform = decoy_camera.transform
			camera.pan_offset = decoy_camera.pan
			camera.zoom_scale = decoy_camera.zoom
			camera.zoom_target = decoy_camera.target
		if is_instance_valid(star_map.decoy_preview):
			star_map.decoy_preview.hide()
			star_map.decoy_preview.queue_free()
		star_map.decoy_preview = null
		star_map.decoy_controls = null
		star_map._end_pinch()
	if is_instance_valid(decoy_panel):
		decoy_panel.hide()
		decoy_panel.queue_free()
	decoy_camera.clear()

# A Control may stop receiving touch-up when strategic-time mode changes the
# map's input state while pressed. Capture matching releases before GUI dispatch.
func _input(event: InputEvent) -> void:
	if not _wait_hold_active: return
	if event is InputEventScreenTouch and not event.pressed:
		var touch_index: int = screen.overview_hud.wait_touch_index if is_instance_valid(screen) else -1
		if touch_index < 0 or event.index == touch_index:
			_end_hold_wait()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_hold_wait()


func _unhandled_input(event: InputEvent) -> void:
	if _capture_hold >= 0 and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_stop_capture_hold("Hold cancelled")
	elif inspecting and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_dismiss_inspection()


func _unhandled_key_input(event: InputEvent) -> void:
	if decoy_camera.is_empty() or not _map_input_allowed(): return
	if event.is_action_pressed("ui_cancel"):
		_cancel_decoy()
		get_viewport().set_input_as_handled()
		return
	var direction := Vector2(
		int(event.is_action_pressed("ui_right")) - int(event.is_action_pressed("ui_left")),
		int(event.is_action_pressed("ui_down")) - int(event.is_action_pressed("ui_up")))
	if direction == Vector2.ZERO: return
	var center: Vector2 = star_map.size * 0.5
	star_map.camera.pan_screen(center, center - direction * 40.0)
	get_viewport().set_input_as_handled()

func _dismiss_inspection() -> void:
	if not inspecting: return
	inspecting = false
	var backing: StyleBoxFlat = screen.focus_backing.get_theme_stylebox("panel")
	backing.bg_color = inspection_backing_color
	if is_instance_valid(star_map):
		star_map.consume_gesture()
		star_map.inspection_active = false
	map_destination = -1
	phase = Phase.OVERVIEW
	show_system()
	if is_instance_valid(star_map) and view_kind == "system":
		screen._cancel_focus_motion()
		star_map.camera.overview(star_map.settings, true)


func _faction_profile() -> Resource:
	if not (state.is_defense() or state.is_warzone()) or state.faction_id.is_empty(): return null
	return preload("res://scripts/expedition/faction_catalog.gd").find(state.rules, state.faction_id)

func _show_system_details() -> void:
	if state == null or phase not in [Phase.OVERVIEW, Phase.TRAVELING] or not _map_input_allowed(): return
	if state.is_defense():
		screen.present_system_details(state)
	elif state.is_warzone():
		var operation = state.warzone
		var lines := PackedStringArray(["[b]Warzone reports[/b]", ""])
		for index in operation.objectives.size():
			lines.append("%s · %s" % [operation.objective_name(index), operation.objective_brief(index)])
		lines.append("")
		lines.append_array(PackedStringArray(operation.events))
		screen.system_details_overlay.show_text("\n".join(lines))
