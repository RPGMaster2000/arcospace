extends Control
# RESPONSIBILITY: Select a profile and use the existing new-run/Continue pathways.
# Presentation owns camera and cinematic timing; persistence owns disk data.
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
var save_store = Save.new()
var saved_run: Dictionary = {}
var initial_settings: Dictionary = {}
var selected_ship: int = 0
var overwrite_confirmation: ConfirmationDialog
var save_notice: AcceptDialog
var deck_viewer: CanvasLayer
var settings_button: Button
@onready var showcase = $World/Viewport/MainMenu3D
@onready var deck_button: Button = $Selection/Actions/ViewDeck
@onready var begin_button: Button = $Selection/Actions/Begin
@onready var previous_ship: Button = $Selection/Previous
@onready var next_ship: Button = $Selection/Next
@onready var start_button: Button = $Selection/Actions/Start


func _ready() -> void:
	get_node("/root/Music").play_starmap()
	settings_button = preload("res://scripts/ui/settings_button.gd").new()
	settings_button.is_main_menu = true
	add_child(settings_button)
	var legend = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(legend)
	$Legend.pressed.connect(legend.show_legend)
	deck_viewer = preload("res://scripts/ui/deck_viewer.gd").new()
	add_child(deck_viewer)
	deck_button.pressed.connect(func(): deck_viewer.show_ship(Ships.PLAYERS[selected_ship]))
	showcase.populate(Ships.PLAYERS)
	showcase.selection_ready.connect(_selection_ready)
	selected_ship = clampi(int(initial_settings.get("player_ship", 0)), 0, Ships.PLAYERS.size() - 1)
	_select(selected_ship)
	previous_ship.pressed.connect(_navigate.bind(-1))
	next_ship.pressed.connect(_navigate.bind(1))
	saved_run = save_store.load_run()
	overwrite_confirmation = ConfirmationDialog.new()
	overwrite_confirmation.dialog_text = "Starting a new expedition will permanently abandon your current run."
	overwrite_confirmation.ok_button_text = "Begin Expedition"
	add_child(overwrite_confirmation)
	overwrite_confirmation.confirmed.connect(_start)
	save_notice = AcceptDialog.new()
	add_child(save_notice)
	if not save_store.error.is_empty() or not save_store.warning.is_empty():
		save_notice.dialog_text = save_store.error if not save_store.error.is_empty() else save_store.warning
		save_notice.popup_centered.call_deferred(Vector2i(520, 180))
	start_button.text = "CONTINUE EXPEDITION" if not saved_run.is_empty() else "BEGIN EXPEDITION"
	begin_button.visible = not saved_run.is_empty()
	begin_button.pressed.connect(_request_new)
	start_button.pressed.connect(_primary_action)
	for button in [deck_button, begin_button, start_button, $Legend]: Presentation.action(button, button == start_button)
	start_button.add_theme_color_override("font_focus_color", Color("102838"))
	$Selection.hide()
	resized.connect(_layout)
	_layout()


func _selection_ready() -> void:
	$Selection.show()
	showcase.select_ship(selected_ship, true)
	start_button.grab_focus()


func _layout() -> void:
	var compact: bool = size.y < 600
	$Selection/Information.anchor_top = 0.50 if compact else 0.55
	$Selection/Actions.anchor_left = 0.04 if size.x < 1000 else 0.12
	$Selection/Actions.anchor_right = 0.96 if size.x < 1000 else 0.88
	$Selection/Heading.add_theme_font_size_override("font_size", 22 if compact else 30)
	$Selection/Information/Margin/Scroll/Column/Name.add_theme_font_size_override("font_size", 25 if compact else 34)
	for label in [$Selection/Information/Margin/Scroll/Column/Role, $Selection/Information/Margin/Scroll/Column/Description, $Selection/Information/Margin/Scroll/Column/Stats]:
		label.add_theme_font_size_override("font_size", 16 if compact else 21)
	for button in [deck_button, begin_button, start_button]: button.add_theme_font_size_override("font_size", (14 if size.x < 800 else 16) if compact else 21)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -62
	settings_button.offset_right = -14
	settings_button.offset_top = 12
	settings_button.offset_bottom = 60


func _select(index: int) -> void:
	selected_ship = clampi(index, 0, Ships.PLAYERS.size() - 1)
	var data: Resource = Ships.PLAYERS[selected_ship]
	var column: VBoxContainer = $Selection/Information/Margin/Scroll/Column
	column.get_node("Name").text = data.ship_name.to_upper()
	column.get_node("Role").text = data.subtitle + " · " + data.role
	column.get_node("Description").text = data.summary
	column.get_node("Stats").text = "Hull %d   Shields %d   ·   Materials %d / Energy %d / Crew %d\nSynthesizer %d / Reactor %d / Quarters %d   ·   EMP %dt / %+.0f%% resistance" % [data.hull_capacity, data.shields, data.materials, data.energy, data.crew, data.synthesizer, data.reactor, data.quarters, data.ftl_turns, data.ftl_resistance * 100]
	deck_button.tooltip_text = data.ship_name + " · Starting card pool"
	previous_ship.disabled = selected_ship == 0
	next_ship.disabled = selected_ship == Ships.PLAYERS.size() - 1
	showcase.select_ship(selected_ship)
	if deck_viewer.shade.visible: deck_viewer.show_ship(data)


func _navigate(direction: int) -> void:
	if showcase.phase == showcase.Phase.SHIP_SELECTION: _select(selected_ship + direction)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or deck_viewer.shade.visible or overwrite_confirmation.visible or save_notice.visible: return
	if event is InputEventKey and event.echo: return
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION: return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch) and event.pressed
	if showcase.phase in [showcase.Phase.INTRO_BACKGROUND, showcase.Phase.INTRO_LOGO, showcase.Phase.PRESS_TO_PLAY]:
		if pressed:
			showcase.advance()
			get_viewport().set_input_as_handled()
	elif showcase.phase == showcase.Phase.SHIP_SELECTION:
		if event.is_action_pressed("ui_left"): _navigate(-1)
		elif event.is_action_pressed("ui_right"): _navigate(1)
		else: return
		get_viewport().set_input_as_handled()


func read_settings() -> Dictionary:
	return {"player_ship": selected_ship, "modifier": 0}


func _primary_action() -> void:
	if saved_run.is_empty(): _request_new()
	else: _continue_expedition()


func _set_actions_enabled(enabled: bool) -> void:
	for button in [start_button, begin_button, deck_button, previous_ship, next_ship, settings_button, $Legend]: button.disabled = not enabled
	if enabled:
		previous_ship.disabled = selected_ship == 0
		next_ship.disabled = selected_ship == Ships.PLAYERS.size() - 1


func _request_new() -> void:
	if not saved_run.is_empty() or FileAccess.file_exists(save_store.path):
		overwrite_confirmation.popup_centered(Vector2i(520, 180))
	else:
		_start()


func _start() -> void:
	var candidate = preload("res://scripts/expedition_state.gd").new()
	candidate.start(selected_ship, preload("res://encounters/expedition_rules.tres"))
	if not save_store.save_run(candidate):
		save_notice.dialog_text = save_store.error
		save_notice.popup_centered(Vector2i(520, 180))
		return
	_launch({"state": candidate, "battle": {}})


func _continue_expedition() -> void:
	var loaded: Dictionary = save_store.load_run()
	if loaded.is_empty():
		save_notice.dialog_text = save_store.error if not save_store.error.is_empty() else "No active expedition remains."
		save_notice.popup_centered(Vector2i(520, 180))
		return
	_launch(loaded)


func _launch(data: Dictionary) -> void:
	_set_actions_enabled(false)
	var expedition = load("res://scenes/expedition.tscn").instantiate()
	expedition.selected_ship = data.state.player_ship
	expedition.resume_data = data
	expedition.save_store = save_store
	get_parent().add_child(expedition)
	get_tree().current_scene = expedition
	queue_free()


