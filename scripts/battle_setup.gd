extends Control
# RESPONSIBILITY: Read setup controls and configure a new board before its _ready runs.
const BOARD = preload("res://scenes/board_3d.tscn")
const Ships = preload("res://scripts/ship_library.gd")
@export var preview_model: PackedScene = preload("res://scenes/ship_3d.tscn")
var initial_settings: Dictionary = {}
var selected_ship: int = 0

func _ready() -> void:
	var overlay = preload("res://scripts/ui/info_overlay.gd").new()
	add_child(overlay)
	var legend = Button.new()
	legend.text = "Legend"
	legend.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	legend.position = Vector2(size.x - 130, 12)
	legend.custom_minimum_size = Vector2(110, 48)
	add_child(legend)
	legend.pressed.connect(overlay.show_legend)
	selected_ship = clampi(int(initial_settings.get("player_ship", 0)), 0, 2)
	$Start.pressed.connect(_start)
	for index in range(3):
		var data = Ships.PLAYERS[index]
		var panel = get_node("Ships/Ship%d" % index)
		panel.get_node("Name").text = data.ship_name.to_upper() + " · " + data.role
		var resistance: String = "%+d%%" % roundi(data.ftl_resistance * 100) if data.ftl_resistance != 0 else "Normal"
		panel.get_node("Stats").text = "Hull %d · Shields %d\nMaterials %d · Energy %d · Crew %d\nSynthesizer %d · Reactor %d · Quarters %d\nEmergency Jump %d turns · Resistance %s" % [data.hull_capacity, data.shields, data.materials, data.energy, data.crew, data.synthesizer, data.reactor, data.quarters, data.ftl_turns, resistance]
		panel.get_node("Summary").text = data.summary
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
	selected_ship = index
	for slot in range(3):
		var button: Button = get_node("Ships/Ship%d/Select" % slot)
		button.text = "SELECTED" if slot == selected_ship else "Select ship"
		button.modulate = Color(0.5, 0.9, 1) if slot == selected_ship else Color.WHITE

func read_settings() -> Dictionary:
	return {"player_ship": selected_ship, "modifier": 0}

func _start() -> void:
	$Start.disabled = true
	var board = load("res://scenes/expedition.tscn").instantiate()
	board.selected_ship = selected_ship
	get_parent().add_child(board)
	get_tree().current_scene = board
	queue_free()

# Preserve the existing preview nodes and selection logic; only fit their controls.
func _layout_cards() -> void:
	$Instructions.text = "Choose your ship. Shields protect Hull; Emergency Jump offers a combat escape."
	$Instructions.offset_top = 70
	$Instructions.offset_bottom = 104
	$Ships.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$Ships.offset_left = 16
	$Ships.offset_right = -16
	$Ships.offset_top = 116
	$Ships.offset_bottom = -90
	$Start.custom_minimum_size.y = 64
	$Start.offset_top = -76
	$Start.offset_bottom = -12
	preload("res://scripts/ui/encounter_presentation.gd").action($Start, true)
	for index in range(3):
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
	panel.get_node("Name").offset_bottom = 62
	panel.get_node("Preview").offset_top = 68
	panel.get_node("Preview").offset_bottom = 140
	var stats: Label = panel.get_node("Stats")
	stats.offset_top = 152
	stats.offset_bottom = panel.size.y - 182
	stats.add_theme_font_size_override("font_size", 21)
	var summary: Label = panel.get_node("Summary")
	summary.offset_top = panel.size.y - 176
	summary.offset_bottom = panel.size.y - 84
	summary.add_theme_font_size_override("font_size", 20)
	var select: Button = panel.get_node("Select")
	select.offset_top = panel.size.y - 76
	select.offset_bottom = panel.size.y - 12
	preload("res://scripts/ui/encounter_presentation.gd").action(select)
