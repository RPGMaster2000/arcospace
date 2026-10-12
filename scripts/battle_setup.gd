extends Control
# RESPONSIBILITY: Read setup controls and configure a new board before its _ready runs.
const BOARD = preload("res://scenes/board_3d.tscn")
const Modifier = preload("res://scripts/combat_modifier.gd")
const KEYS = ["materials", "energy", "crew", "synthesizer", "reactor", "quarters"]
# Descriptions read gameplay constants so tuning the modifier updates the setup text too.
static func description(index: int) -> String:
	var interval = "Every %d–%d full turns" % [Modifier.MIN_INTERVAL, Modifier.MAX_INTERVAL]
	match index:
		1:
			return "%s: the battlefield attacks each ship once, with a separate %d%% hit chance. Each hit deals %d damage, absorbed by shields first." % [interval, roundi(Modifier.ASTEROID_CHANCE * 100), Modifier.ASTEROID_DAMAGE]
		2:
			return "%s: for %d round(s), one announced ×2 or ×½ multiplier applies to all blue cards, including resource gain, theft and production increases/decreases. Costs unchanged; halves round down. Shield swaps unchanged." % [interval, Modifier.ACTIVE_ROUNDS]
		3:
			return "%s: both ships’ shields go offline for %d round(s). Shield restoration has no effect. Stored shields return afterward." % [interval, Modifier.ACTIVE_ROUNDS]
		4:
			return "Targeting efficiency starts at %d%% and drifts up to %d points per full turn within %d–100%%. This is combat card hit chance. Misses still spend the cost." % [100 - Modifier.NEBULA_START, Modifier.NEBULA_STEP, 100 - Modifier.NEBULA_MAX]
	return "No combat modifiers. Standard battle rules."
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
	$Panel/Description.text = description(index)

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
