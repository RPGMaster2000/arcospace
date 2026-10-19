extends Control
# DOES NOT: Start combat directly; confirmation creates an Expedition controller.
# RESPONSIBILITY: Read setup controls and configure a new board before its _ready runs.
const BOARD = preload("res://scenes/board_3d.tscn")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
@export var preview_model: PackedScene = preload("res://scenes/ship_3d.tscn")
var initial_settings: Dictionary = {}
var selected_ship: int = 0
var deck_viewer: CanvasLayer
var deck_button: Button
var music_button: Button
const SHIPS_PER_PAGE: int = 3
var ship_page: int = 0
var previous_page: Button
var next_page: Button
var legend_button: Button


func _ready() -> void:
	get_node("/root/Music").play_starmap()
	music_button = preload("res://scripts/ui/music_button.gd").new()
	add_child(music_button)
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
	$Start.pressed.connect(_start)
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
func _start() -> void:
	$Start.disabled = true
	var board = load("res://scenes/expedition.tscn").instantiate()
	board.selected_ship = selected_ship
	get_parent().add_child(board)
	get_tree().current_scene = board
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
	$Start.custom_minimum_size.y = 56
	$Start.offset_left = -16
	$Start.offset_right = 274
	$Start.offset_top = -68 if compact else -76
	$Start.offset_bottom = -12 if compact else -20
	deck_button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	deck_button.offset_left = -274
	deck_button.offset_right = -32
	deck_button.offset_top = $Start.offset_top
	deck_button.offset_bottom = $Start.offset_bottom
	legend_button.position = Vector2(size.x - 190, 8)
	music_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	music_button.offset_left = -64
	music_button.offset_right = -16
	music_button.offset_top = 8
	music_button.offset_bottom = 56
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
