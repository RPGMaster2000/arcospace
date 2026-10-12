extends Control
# RESPONSIBILITY: Read setup controls and configure a new board before its _ready runs.
const BOARD = preload("res://scenes/board_3d.tscn")
const Modifier = preload("res://scripts/combat_modifier.gd")
const KEYS = ["materials", "energy", "crew", "synthesizer", "reactor", "quarters"]
const DESCRIPTIONS = [
	"No combat modifiers. Standard battle rules.",
	"Every 6–10 full turns: the battlefield attacks each ship once, with a separate 20% hit chance. Each hit deals 5 damage, absorbed by shields first.",
	"Every 6–10 full turns: one round where each blue card has equal chances of ×2 or ×½ effect. Costs stay the same; halves round down. Shield swaps stay swaps.",
	"Every 6–10 full turns: both ships’ shields go offline for one round. Shield restoration has no effect. Stored shields return afterward.",
	"Miss rate drifts by up to 5 percentage points per full turn, within 0–70%. Combat cards can miss: cost is paid and card effects are cancelled."
]
var initial_settings: Dictionary = {}

func _ready() -> void:
	for title in Modifier.NAMES:
		$Panel/Modifier.add_item(title)
	$Panel/Modifier.item_selected.connect(_describe)
	$Panel/Start.pressed.connect(_start)
	for side in ["player", "enemy"]:
		for key in KEYS:
			var control: SpinBox = get_node("Panel/" + side + "_" + key)
			if initial_settings.has(side + "_" + key):
				control.value = initial_settings[side + "_" + key]
	if initial_settings.has("ftl_turns"):
		$Panel/FTL.value = initial_settings.ftl_turns
	$Panel/Modifier.select(int(initial_settings.get("modifier", 0)))
	_describe($Panel/Modifier.selected)

func _describe(index: int) -> void:
	$Panel/Description.text = DESCRIPTIONS[index]

func read_settings() -> Dictionary:
	var result: Dictionary = {"ftl_turns": int($Panel/FTL.value), "modifier": $Panel/Modifier.selected}
	for side in ["player", "enemy"]:
		for key in KEYS:
			result[side + "_" + key] = int(get_node("Panel/" + side + "_" + key).value)
	return result

func _start() -> void:
	$Panel/Start.disabled = true
	var board = BOARD.instantiate()
	board.setup_settings = read_settings()
	get_parent().add_child(board)
	get_tree().current_scene = board
	queue_free()
