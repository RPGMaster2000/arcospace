extends Control
# DOES NOT: Start combat directly; confirmation creates an Expedition controller.
# RESPONSIBILITY: Read setup controls and configure a new board before its _ready runs.
const Save = preload("res://scripts/persistence/expedition_save.gd")
var save_store = Save.new()
var saved_run: Dictionary = {}
var new_expedition_button: Button
var overwrite_confirmation: ConfirmationDialog
var save_notice: AcceptDialog
const BOARD = preload("res://scenes/board_3d.tscn")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
@export var preview_model: PackedScene = preload("res://scenes/ship_3d.tscn")
## Elevated orthographic view for the main-menu ship previews.
@export var preview_camera_position: Vector3 = Vector3(7, 7, 7)
var initial_settings: Dictionary = {}
var selected_ship: int = 0
var deck_viewer: CanvasLayer
var deck_button: Button
var settings_button: Button
const SHIPS_PER_PAGE: int = 3
var ship_page: int = 0
var previous_page: Button
var next_page: Button
var legend_button: Button


func _ready() -> void:
	get_node("/root/Music").play_starmap()
	settings_button = preload("res://scripts/ui/settings_button.gd").new()
	settings_button.is_main_menu = true
	add_child(settings_button)
	var overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(overlay)
	var legend = Button.new()
	legend_button = legend
	legend.text = "Legend"
	legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legend.position = Vector2(size.x - 134, 24)
	legend.custom_minimum_size = Vector2(110, 48)
	add_child(legend)
	legend.pressed.connect(overlay.show_legend)
	Presentation.action(legend)
	deck_viewer = preload("res://scripts/ui/deck_viewer.gd").new()
	add_child(deck_viewer)
	deck_button = Button.new()
	deck_button.name = "ViewDeck"
	deck_button.custom_minimum_size = Vector2(220, 56)
	deck_button.add_theme_font_size_override("font_size", 22)
	Presentation.action(deck_button)
	add_child(deck_button)
	deck_button.pressed.connect(func(): deck_viewer.show_ship(Ships.PLAYERS[selected_ship]))
	selected_ship = clampi(int(initial_settings.get("player_ship", 0)), 0, Ships.PLAYERS.size() - 1)
	_build_ship_pages()
	saved_run = save_store.load_run()
	new_expedition_button = Button.new()
	new_expedition_button.text = "New Expedition"
	new_expedition_button.add_theme_font_size_override("font_size", 22)
	Presentation.action(new_expedition_button)
	add_child(new_expedition_button)
	new_expedition_button.pressed.connect(_request_new)
	overwrite_confirmation = ConfirmationDialog.new()
	overwrite_confirmation.dialog_text = "Starting a new expedition will permanently abandon your current run."
	overwrite_confirmation.ok_button_text = "New Expedition"
	add_child(overwrite_confirmation)
	overwrite_confirmation.confirmed.connect(_start)
	save_notice = AcceptDialog.new()
	add_child(save_notice)
	if not save_store.error.is_empty() or not save_store.warning.is_empty():
		save_notice.dialog_text = save_store.error if not save_store.error.is_empty() else save_store.warning
		save_notice.popup_centered.call_deferred(Vector2i(520, 180))
	$Start.text = "Continue Expedition" if not saved_run.is_empty() else "New Expedition"
	$Start.pressed.connect(_primary_action)
	for index in range(Ships.PLAYERS.size()):
		var data = Ships.PLAYERS[index]
		var panel = get_node("Ships/Ship%d" % index)
		panel.get_node("Name").text = data.ship_name.to_upper()
		panel.get_node("Name").tooltip_text = data.role + " · " + data.summary
		var stats: Label = panel.get_node("Stats")
		stats.add_theme_font_override("font", Presentation.UI_FONT)
		stats.text = (
			"%s %d   %s %d\n%s %d   %s %d   %s %d\n%s %d   %s %d   %s %d"
			% [
				_icon("hull"),
				data.hull_capacity,
				_icon("shields"),
				data.shields,
				_icon("materials"),
				data.materials,
				_icon("energy"),
				data.energy,
				_icon("crew"),
				data.crew,
				_icon("synthesizer"),
				data.synthesizer,
				_icon("reactor"),
				data.reactor,
				_icon("quarters"),
				data.quarters
			]
		)
		stats.tooltip_text = (
			"Hull / Shields\nMaterials / Energy / Crew\nSynthesizer / Reactor / Quarters\nEMP Pulse turns and resistance\n"
			+ data.summary
		)
		panel.get_node("Summary").add_theme_font_override("font", Presentation.UI_FONT)
		panel.get_node("Summary").text = (
			"%s %dt   %+.0f%% resistance"
			% [_icon("jump"), data.ftl_turns, data.ftl_resistance * 100]
		)
		panel.get_node("Summary").tooltip_text = (
			data.role + " · " + data.summary + "\nEMP Pulse duration and failure resistance"
		)
		panel.tooltip_text = data.summary
		panel.get_node("Select").pressed.connect(_select.bind(index))
		_preview(panel.get_node("Preview/Viewport"), data)
	_select(selected_ship)
	resized.connect(_layout_cards)
	_layout_cards()


func _preview(viewport: SubViewport, data: Resource) -> void:
	var camera: Camera3D = viewport.get_node("Camera")
	camera.position = preview_camera_position
	camera.look_at(Vector3.ZERO)
	var model = (data.model_scene if data.model_scene != null else preview_model).instantiate()
	viewport.add_child(model)
	model.set_hull_color(data.hull_color)
	model.set_hull_strength(data.hull_capacity)
	model.set_shield_strength(data.shields)


func _select(index: int) -> void:
	selected_ship = clampi(index, 0, Ships.PLAYERS.size() - 1)
	_show_ship_page(int(selected_ship / SHIPS_PER_PAGE))
	deck_button.text = "View Deck"
	deck_button.tooltip_text = Ships.PLAYERS[selected_ship].ship_name + " · Starting card pool"
	if deck_viewer.shade.visible:
		deck_viewer.show_ship(Ships.PLAYERS[selected_ship])
	for slot in range(Ships.PLAYERS.size()):
		var button: Button = get_node("Ships/Ship%d/Select" % slot)
		button.text = "SELECTED" if slot == selected_ship else "Select ship"
		button.modulate = Color(0.5, 0.9, 1) if slot == selected_ship else Color.WHITE
		get_node("Ships/Ship%d" % slot).add_theme_stylebox_override(
			"panel", Presentation.style(Presentation.COLORS.special, slot == selected_ship)
		)


func read_settings() -> Dictionary:
	return {"player_ship": selected_ship, "modifier": 0}


# Create the expedition only after ship confirmation; pass the library index before its _ready callback.
func _primary_action() -> void:
	if saved_run.is_empty(): _request_new()
	else: _continue_expedition()


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
	$Start.disabled = true
	var expedition = load("res://scenes/expedition.tscn").instantiate()
	expedition.selected_ship = data.state.player_ship
	expedition.resume_data = data
	expedition.save_store = save_store
	get_parent().add_child(expedition)
	get_tree().current_scene = expedition
	queue_free()


# Preserve the existing preview nodes and selection logic; only fit their controls.
func _layout_cards() -> void:
	$Instructions.hide()
	$Logo.offset_top = 8
	$Logo.offset_bottom = 57
	var compact: bool = size.y < 600
	$Logo.add_theme_font_size_override("font_size", 32 if compact else 40)
	$Ships.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Ships.offset_left = 16
	$Ships.offset_right = -16
	$Ships.offset_top = 60 if compact else 72
	$Ships.offset_bottom = -80 if compact else -92
	new_expedition_button.visible = not saved_run.is_empty()
	$Start.custom_minimum_size.y = 56
	$Start.offset_left = -16
	$Start.offset_right = 274
	$Start.offset_top = -68 if compact else -76
	$Start.offset_bottom = -12 if compact else -20
	new_expedition_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	new_expedition_button.position = Vector2(16, 8)
	new_expedition_button.size = Vector2(190, 48)
	new_expedition_button.add_theme_font_size_override("font_size", 18)
	deck_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	deck_button.offset_left = -274
	deck_button.offset_right = -32
	deck_button.offset_top = $Start.offset_top
	deck_button.offset_bottom = $Start.offset_bottom
	legend_button.position = Vector2(size.x - 190, 8)
	settings_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings_button.offset_left = -64
	settings_button.offset_right = -16
	settings_button.offset_top = 8
	settings_button.offset_bottom = 56
	for button in [previous_page, next_page]:
		button.set_anchors_and_offsets_preset(
			Control.PRESET_BOTTOM_LEFT if button == previous_page else Control.PRESET_BOTTOM_RIGHT
		)
		button.offset_left = 16 if button == previous_page else -112
		button.offset_right = 112 if button == previous_page else -16
		button.offset_top = $Start.offset_top
		button.offset_bottom = $Start.offset_bottom
	preload("res://scripts/ui/encounter_presentation.gd").action($Start, true)
	for index in range(Ships.PLAYERS.size()):
		var panel = get_node("Ships/Ship%d" % index)
		panel.custom_minimum_size = Vector2.ZERO
		if not panel.resized.is_connected(_fit_card.bind(panel)):
			panel.resized.connect(_fit_card.bind(panel))
		_fit_card(panel)


func _fit_card(panel: Control) -> void:
	for key in ["Name", "Preview", "Stats", "Summary", "Select"]:
		var item: Control = panel.get_node(key)
		item.anchor_left = 0
		item.anchor_right = 1
		item.offset_left = 14
		item.offset_right = -14
	panel.get_node("Name").offset_top = 8
	panel.get_node("Name").offset_bottom = 56
	panel.get_node("Preview").offset_top = 58
	var compact: bool = size.y < 600
	var reserved: float = 176 if compact else 208
	panel.get_node("Preview").offset_bottom = panel.size.y - reserved
	var viewport: SubViewport = panel.get_node("Preview/Viewport")
	var camera: Camera3D = viewport.get_node("Camera")
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	# Fit the existing model on tall/narrow preview surfaces as well as ultrawide.
	var preview: Control = panel.get_node("Preview")
	var aspect: float = preview.size.x / maxf(1, preview.size.y)
	camera.size = maxf(3.8, 4.8 / maxf(0.7, aspect))
	var stats: Label = panel.get_node("Stats")
	stats.offset_top = panel.size.y - reserved + 8
	stats.offset_bottom = panel.size.y - (88 if compact else 94)
	stats.add_theme_font_size_override("font_size", 16 if compact else 20)
	var summary: Label = panel.get_node("Summary")
	summary.offset_top = stats.offset_bottom
	summary.offset_bottom = panel.size.y - 60
	summary.add_theme_font_size_override("font_size", 16 if compact else 18)
	var select: Button = panel.get_node("Select")
	select.custom_minimum_size.y = 48
	select.offset_top = panel.size.y - 56
	select.offset_bottom = panel.size.y - 8
	preload("res://scripts/ui/encounter_presentation.gd").action(select)


func _icon(key: String) -> String:
	return Presentation.icon(key, Presentation.UI_FONT)


# Keep three full-sized previews per page instead of squeezing six mobile cards.
func _build_ship_pages() -> void:
	for index in range($Ships.get_child_count(), Ships.PLAYERS.size()):
		# Avoid copying a stretched viewport size while the container owns its sizing.
		$Ships/Ship0/Preview.stretch = false
		var panel = $Ships/Ship0.duplicate()
		$Ships/Ship0/Preview.stretch = true
		panel.get_node("Preview").stretch = true
		panel.name = "Ship%d" % index
		$Ships.add_child(panel)
	for panel in $Ships.get_children():
		panel.get_node("Preview/Viewport").render_target_update_mode = (
			SubViewport.UPDATE_WHEN_VISIBLE
		)
	previous_page = Button.new()
	next_page = Button.new()
	for button in [previous_page, next_page]:
		button.custom_minimum_size = Vector2(96, 48)
		button.add_theme_font_size_override("font_size", 18)
		Presentation.action(button)
		add_child(button)
	previous_page.pressed.connect(func(): _show_ship_page(ship_page - 1))
	next_page.pressed.connect(func(): _show_ship_page(ship_page + 1))


func _show_ship_page(page: int) -> void:
	var pages: int = ceili(float(Ships.PLAYERS.size()) / SHIPS_PER_PAGE)
	ship_page = clampi(page, 0, pages - 1)
	for index in range(Ships.PLAYERS.size()):
		get_node("Ships/Ship%d" % index).visible = int(index / SHIPS_PER_PAGE) == ship_page
	previous_page.text = "‹ %d/%d" % [ship_page + 1, pages]
	next_page.text = "%d/%d ›" % [ship_page + 1, pages]
	previous_page.tooltip_text = (
		"Previous ships — selected: " + Ships.PLAYERS[selected_ship].ship_name
	)
	next_page.tooltip_text = "Next ships — selected: " + Ships.PLAYERS[selected_ship].ship_name
	previous_page.disabled = ship_page == 0
	next_page.disabled = ship_page == pages - 1
