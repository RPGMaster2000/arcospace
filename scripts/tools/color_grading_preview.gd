extends Control
## Development-only F6 workflow: save a .tres, press Reload saved preset.
const BOARD = preload("res://scenes/board_3d.tscn")
const GRADING = preload("res://scripts/visual/battlefield_grading.gd")
var board: Control
var selection: int = 0
var toggle: CheckButton

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(220, 4)
	layer.add_child(toolbar)
	var choices := OptionButton.new()
	for name in preload("res://scripts/combat_modifier.gd").NAMES:
		choices.add_item(name)
	choices.item_selected.connect(_show)
	toolbar.add_child(choices)
	var reload_button := Button.new()
	reload_button.text = "Reload saved preset"
	reload_button.pressed.connect(_reload)
	toolbar.add_child(reload_button)
	toggle = CheckButton.new()
	toggle.text = "Grading"
	toggle.toggled.connect(_toggle)
	toolbar.add_child(toggle)
	_show(0)

func _show(index: int) -> void:
	selection = index
	if is_instance_valid(board):
		remove_child(board)
		board.queue_free()
	board = BOARD.instantiate()
	board.setup_settings = {"modifier": selection}
	board.get_node("BattleEffects").enabled = false
	board.get_node("ModifierDisplay").cinematic_enabled = false
	add_child(board)
	board.enemy_timer.stop()
	board.process_mode = Node.PROCESS_MODE_DISABLED
	_reload()

func _reload() -> void:
	var saved: Resource = ResourceLoader.load(
		GRADING.PRESETS[selection].resource_path, "", ResourceLoader.CACHE_MODE_REPLACE
	)
	board.get_node("BattleView").preset = saved.duplicate(true)
	toggle.set_pressed_no_signal(saved.enabled)

func _toggle(value: bool) -> void:
	board.get_node("BattleView").preset.enabled = value
