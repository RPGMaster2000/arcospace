extends Control
# RESPONSIBILITY: Read setup controls and configure a new board before its _ready runs.
const BOARD = preload("res://scenes/board_3d.tscn")
const Ships = preload("res://scripts/ship_library.gd")
@export var preview_model: PackedScene = preload("res://scenes/ship_3d.tscn")
var initial_settings: Dictionary = {}
var selected_ship: int = 0

func _ready() -> void:
	selected_ship = clampi(int(initial_settings.get("player_ship", 0)), 0, 2)
	$Start.pressed.connect(_start)
	for index in range(3):
		var data = Ships.PLAYERS[index]
		var panel = get_node("Ships/Ship%d" % index)
		panel.get_node("Name").text = data.ship_name.to_upper() + " · " + data.role
		var resistance: String = "%+d%%" % roundi(data.ftl_resistance * 100) if data.ftl_resistance != 0 else "Normal"
		panel.get_node("Stats").text = "Hull %d · Shields %d\nMaterials %d · Energy %d · Crew %d\nFabricator %d · Reactor %d · Hangar %d\nFTL %d turns · Resistance %s" % [data.hull_capacity, data.shields, data.materials, data.energy, data.crew, data.synthesizer, data.reactor, data.quarters, data.ftl_turns, resistance]
		panel.get_node("Summary").text = data.summary
		panel.get_node("Select").pressed.connect(_select.bind(index))
		_preview(panel.get_node("Preview/Viewport"), data)
	_select(selected_ship)

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
	var board = BOARD.instantiate()
	board.setup_settings = read_settings()
	get_parent().add_child(board)
	get_tree().current_scene = board
	queue_free()
