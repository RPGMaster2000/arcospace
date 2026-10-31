extends Control

const Sound = preload("res://scripts/audio/sfx.gd")
# RESPONSIBILITY: Select a profile and use the existing new-run/Continue pathways.
# Presentation owns camera and cinematic timing; persistence owns disk data.
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
const CardPortrait = preload("res://scripts/ui/card_portrait.gd")
const CardInspector = preload("res://scripts/ui/card_inspector.gd")
@export_group("Gameplay transition")
@export_range(0.05, 3) var white_fade_duration: float = 0.35
@export_range(0.05, 3) var map_reveal_duration: float = 1.0
@export_range(0.05, 1) var continue_fade_duration: float = 0.18
var transition_tween: Tween
var launch_data: Dictionary = {}
var save_store = Save.new()
var saved_run: Dictionary = {}
var initial_settings: Dictionary = {}
var selected_ship: int = 0
var overwrite_confirmation: ConfirmationDialog
var save_notice: AcceptDialog
var signature_inspector: CanvasLayer
var signature_portrait
var deck_viewer: CanvasLayer
var info_overlay: CanvasLayer
var settings_button: Button
@onready var showcase = $World/Viewport/MainMenu3D
@onready var deck_button: Button = $Selection/Actions/ViewDeck
@onready var begin_button: Button = $Selection/Actions/Begin
@onready var previous_ship: Button = $Selection/Previous
@onready var next_ship: Button = $Selection/Next
@onready var start_button: Button = $Selection/Actions/Start


func _enter_tree() -> void:
	$World/Viewport/MainMenu3D.skip_cinematics = Preferences.skip_cinematics()


func _ready() -> void:
	get_node("/root/Music").play_title()
	settings_button = preload("res://scripts/ui/settings_button.gd").new()
	settings_button.is_main_menu = true
	add_child(settings_button)
	settings_button.menu.cinematics_changed.connect(func(enabled: bool):
		showcase.skip_cinematics = enabled
		if enabled and showcase.phase in [showcase.Phase.INTRO_BACKGROUND, showcase.Phase.INTRO_LOGO]: showcase.advance())
	info_overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(info_overlay)
	$Legend.pressed.connect(info_overlay.show_legend)
	signature_inspector = CardInspector.new()
	add_child(signature_inspector)
	deck_viewer = preload("res://scripts/ui/deck_viewer.gd").new()
	add_child(deck_viewer)
	deck_button.pressed.connect(func(): deck_viewer.show_ship(Ships.PLAYERS[selected_ship]))
	var stats: RichTextLabel = $Selection/Information/Margin/Scroll/Column/Identity/Stats
	stats.add_theme_font_override("normal_font", Presentation.UI_FONT)
	var bold := FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7
	bold.fallbacks = [Presentation.EMOJI_FONT]
	stats.add_theme_font_override("bold_font", bold)
	showcase.populate(Ships.PLAYERS)
	showcase.phase_changed.connect(_update_chrome)
	showcase.selection_ready.connect(_selection_ready)
	showcase.departure_finished.connect(func(): _fade_to_game(launch_data, white_fade_duration))
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
	_update_chrome()
	resized.connect(_layout)
	_layout()


func _update_chrome() -> void:
	if showcase.phase == showcase.Phase.CAMERA_TRANSITION:
		get_node("/root/Music").fade_title(0.08 if showcase.skip_cinematics else showcase.camera_transition_duration)
	var interactive: bool = showcase.phase in [showcase.Phase.PRESS_TO_PLAY, showcase.Phase.SHIP_SELECTION]
	settings_button.visible = interactive
	$Legend.visible = interactive


func _selection_ready() -> void:
	get_node("/root/Music").play_ship_selection()
	$Selection.show()
	showcase.select_ship(selected_ship, true)
	start_button.grab_focus()


func _layout() -> void:
	var compact: bool = size.y < 600
	$Selection/Information.anchor_top = (0.30 if size.y < 430 else 0.43) if compact else 0.55
	var info_width: float = minf(size.x * 0.92, size.y * 16.0 / 9.0 * 0.92)
	$Selection/Information.anchor_left = 0.5
	$Selection/Information.anchor_right = 0.5
	$Selection/Information.offset_left = -info_width / 2.0
	$Selection/Information.offset_right = info_width / 2.0
	$Selection/Actions.anchor_left = 0.04 if size.x < 1000 else 0.12
	$Selection/Actions.anchor_right = 0.96 if size.x < 1000 else 0.88
	$Selection/Heading.add_theme_font_size_override("font_size", 22 if compact else 30)
	var columns: HBoxContainer = $Selection/Information/Margin/Scroll/Column
	columns.add_theme_constant_override("separation", 8 if compact else 16)
	var identity: Control = columns.get_node("Identity")
	var summary: Control = columns.get_node("Description")
	var signature: Control = columns.get_node("Signature")
	identity.size_flags_stretch_ratio = 1.35
	summary.size_flags_stretch_ratio = 1.30
	signature.size_flags_stretch_ratio = 0.85
	identity.get_node("Name").add_theme_font_size_override("font_size", (19 if size.x < 800 else 23) if compact else 34)
	for label in [$Selection/Information/Margin/Scroll/Column/Identity/Role, $Selection/Information/Margin/Scroll/Column/Description]:
		label.add_theme_font_size_override("font_size", (12 if size.x < 800 else 15) if compact else 21)
	$Selection/Information/Margin/Scroll/Column/Signature/SignatureHeading.add_theme_font_size_override("font_size", 12 if compact else 16)
	var available_height: float = size.y * (1.0 - $Selection/Information.anchor_top) - 90.0 - 16.0 - (22.0 if compact else 26.0)
	if is_instance_valid(signature_portrait):
		signature_portrait.set_card_scale(clampf(available_height / 294.0, 0.20, 0.70))
	var stats: RichTextLabel = $Selection/Information/Margin/Scroll/Column/Identity/Stats
	for font in ["normal_font_size", "bold_font_size"]: stats.add_theme_font_size_override(font, (12 if size.x < 800 else 14) if compact else 18)
	for button in [deck_button, begin_button, start_button]: button.add_theme_font_size_override("font_size", (14 if size.x < 800 else 16) if compact else 21)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -62
	settings_button.offset_right = -14
	settings_button.offset_top = 12
	settings_button.offset_bottom = 60
	# The caption's themed minimum width exceeds its old fixed 94-pixel slot.
	var reference: Button = $Legend
	reference.text = "REFERENCE" if compact else "GAME REFERENCE"
	reference.add_theme_font_size_override("font_size", 16 if compact else 18)
	reference.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	reference.offset_right = settings_button.offset_left - 12
	reference.offset_left = reference.offset_right - reference.get_combined_minimum_size().x
	reference.offset_top = 12
	reference.offset_bottom = 60
	var heading: Label = $Selection/Heading
	heading.anchor_left = 0.0 if compact else 0.2
	heading.anchor_right = 1.0 if compact else 0.8
	heading.offset_left = 20.0 if compact else 0.0
	heading.offset_right = reference.offset_left - 16.0 if compact else 0.0
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER


func _select(index: int) -> void:
	selected_ship = clampi(index, 0, Ships.PLAYERS.size() - 1)
	var data: Resource = Ships.PLAYERS[selected_ship]
	var column: HBoxContainer = $Selection/Information/Margin/Scroll/Column
	column.get_node("Identity/Name").text = data.ship_name.to_upper()
	column.get_node("Identity/Role").text = data.subtitle + " · " + data.role
	var signature: Resource = data.signature_card
	column.get_node("Description").text = data.summary
	if is_instance_valid(signature_portrait):
		signature_portrait.queue_free()
		signature_portrait = null
	if signature != null:
		signature_portrait = CardPortrait.new()
		signature_portrait.name = "ExclusiveCard"
		signature_portrait.card_data = signature
		signature_portrait.inspection_enabled = false
		column.get_node("Signature/PortraitHost").add_child(signature_portrait)
		signature_portrait.pressed.connect(func(): signature_inspector.present(signature, null, true))
		_layout()
	column.get_node("Identity/Stats").text = "[b]❤️ Hull %d   🛡️ Shields %d[/b]\n[color=#ef9da8]🛠️ Materials [b]%d[/b] · Synthesizer [b]%d[/b][/color]\n[color=#8fc5ff]⚡ Energy [b]%d[/b] · Reactor [b]%d[/b][/color]\n[color=#98ddb0]👥 Crew [b]%d[/b] · Quarters [b]%d[/b][/color]\n[b]EMP[/b] %dt · %+.0f%% resistance" % [data.hull_capacity, data.shields, data.materials, data.synthesizer, data.energy, data.reactor, data.crew, data.quarters, data.ftl_turns, data.ftl_resistance * 100]
	deck_button.tooltip_text = data.ship_name + " · Starting card pool"
	previous_ship.disabled = selected_ship == 0
	next_ship.disabled = selected_ship == Ships.PLAYERS.size() - 1
	showcase.select_ship(selected_ship)
	if deck_viewer.shade.visible: deck_viewer.show_ship(data)


func _navigate(direction: int) -> void:
	if showcase.phase == showcase.Phase.SHIP_SELECTION:
		var previous: int = selected_ship
		_select(selected_ship + direction)
		if selected_ship != previous:
			Sound.play(&"ui_select", self)


func _input(event: InputEvent) -> void:
	if showcase.phase != showcase.Phase.SHIP_SELECTION: return
	if get_tree().paused or deck_viewer.shade.visible or signature_inspector.shade.visible or info_overlay.shade.visible or overwrite_confirmation.visible or save_notice.visible: return
	if event is InputEventKey and event.echo: return
	if event is InputEventJoypadMotion and not Input.is_action_just_pressed("ui_left") and not Input.is_action_just_pressed("ui_right"): return
	if event.is_action_pressed("ui_left"): _navigate(-1)
	elif event.is_action_pressed("ui_right"): _navigate(1)
	else: return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or deck_viewer.shade.visible or info_overlay.shade.visible or overwrite_confirmation.visible or save_notice.visible: return
	if event is InputEventKey and event.echo: return
	if event is InputEventJoypadMotion and not Input.is_action_just_pressed("ui_left") and not Input.is_action_just_pressed("ui_right"): return
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION: return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton or event is InputEventScreenTouch) and event.pressed
	if showcase.phase in [showcase.Phase.INTRO_BACKGROUND, showcase.Phase.INTRO_LOGO, showcase.Phase.PRESS_TO_PLAY]:
		if pressed:
			showcase.advance()
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
	if showcase.phase != showcase.Phase.SHIP_SELECTION: return
	if not saved_run.is_empty() or FileAccess.file_exists(save_store.path):
		overwrite_confirmation.popup_centered(Vector2i(520, 180))
	else:
		_start()


func _start() -> void:
	if showcase.phase != showcase.Phase.SHIP_SELECTION: return
	var candidate = preload("res://scripts/expedition_state.gd").new()
	candidate.start(selected_ship, preload("res://encounters/expedition_rules.tres"))
	if not save_store.save_run(candidate):
		save_notice.dialog_text = save_store.error
		save_notice.popup_centered(Vector2i(520, 180))
		return
	launch_data = {"state": candidate, "battle": {}, "new_system":true}
	_set_actions_enabled(false)
	showcase.select_ship(selected_ship, true)
	showcase.depart()


func _continue_expedition() -> void:
	if showcase.phase != showcase.Phase.SHIP_SELECTION: return
	var loaded: Dictionary = save_store.load_run()
	if loaded.is_empty():
		save_notice.dialog_text = save_store.error if not save_store.error.is_empty() else "No active expedition remains."
		save_notice.popup_centered(Vector2i(520, 180))
		return
	_fade_to_game(loaded, continue_fade_duration)


func _fade_to_game(data: Dictionary, seconds: float) -> void:
	_set_actions_enabled(false)
	showcase.phase = showcase.Phase.LOADING
	$Transition.show()
	$Transition.modulate.a = 0.0
	transition_tween = create_tween()
	transition_tween.tween_property($Transition, "modulate:a", 1.0, minf(seconds, 0.12) if showcase.skip_cinematics else seconds)
	transition_tween.tween_callback(_launch.bind(data))


func _launch(data: Dictionary) -> void:
	var expedition = load("res://scenes/expedition.tscn").instantiate()
	expedition.play_system_intro = data.get("new_system",false)
	expedition.selected_ship = data.state.player_ship
	expedition.resume_data = data
	expedition.save_store = save_store
	var tree: SceneTree = get_tree()
	var was_paused: bool = tree.paused
	tree.paused = true
	get_parent().add_child(expedition)
	tree.current_scene = expedition
	# This temporary cover belongs to the destination, so no callback retains this menu.
	var cover := CanvasLayer.new()
	cover.layer = 300
	cover.process_mode = Node.PROCESS_MODE_ALWAYS
	expedition.add_child(cover)
	var white := ColorRect.new()
	white.color = Color.WHITE
	white.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.add_child(white)
	var restore_pause: Callable = func(): tree.paused = was_paused
	expedition.tree_exiting.connect(restore_pause)
	var reveal: Tween = expedition.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	reveal.tween_property(white, "color:a", 0.0, minf(map_reveal_duration, 0.12) if showcase.skip_cinematics else map_reveal_duration)
	reveal.tween_callback(func():
		restore_pause.call()
		expedition.tree_exiting.disconnect(restore_pause)
		cover.queue_free())
	queue_free()


func _exit_tree() -> void:
	if transition_tween != null: transition_tween.kill()
