extends Control

# RESPONSIBILITY: Coordinate both hands, turns, effects and board display.
# DOES NOT: Choose AI moves, implement card effects or animate cards.

signal action_finished(side: String, discarded: bool)

const MatchRules = preload("res://scripts/match_rules.gd")
const CardEffects = preload("res://scripts/card_effects.gd")
# Assign the six editable scene card buttons in the Inspector.
@export var card_slots: Array[NodePath] = [NodePath("ShieldPlatingCard"),
	NodePath("SynthesizerUpgradeCard"), NodePath("LaserBurstCard"),
	NodePath("EnergyCellCard"), NodePath("QuartersUpgradeCard"), NodePath("TorpedoSalvoCard")]
@export_range(1, 1000, 1) var hull_goal: int = 50
@export_range(1, 1000, 1) var resource_goal: int = 100
var current_actor: String = "player"
var turn_number: int = 1
var winner: String = ""
var extra_action_requested: bool = false
var resolving_card: bool = false
@onready var hand = $CardHand
@onready var enemy_hand = $EnemyHand
@onready var enemy_ai = $EnemyAI
@onready var battle_effects = $BattleEffects
@onready var enemy_timer: Timer = $EnemyThinkTimer

#PLAYER
@export var player_hull: int = 30
@export var player_shields: int = 10

@export var player_materials: int = 16
@export var player_energy: int = 16
@export var player_crew: int = 16

@export var player_synthesizer: int = 2
@export var player_reactor: int = 2
@export var player_quarters: int = 2


# ENEMY
@export var enemy_hull: int = 30
@export var enemy_shields: int = 10

@export var enemy_materials: int = 16
@export var enemy_energy: int = 16
@export var enemy_crew: int = 16

@export var enemy_synthesizer: int = 2
@export var enemy_reactor: int = 2
@export var enemy_quarters: int = 2

@onready var player_hull_label: Label = $PlayerHullLabel
@onready var player_shields_label: Label = $PlayerShieldsLabel
@onready var enemy_hull_label: Label = $EnemyHullLabel
@onready var enemy_shields_label: Label = $EnemyShieldsLabel


@onready var player_materials_label = $PlayerResource1/materials
@onready var player_synthesizer_label = $PlayerResource1/synthesizer


@onready var player_energy_label: Label = $PlayerResource2/energy
@onready var player_reactor_label: Label = $PlayerResource2/reactor
@onready var player_crew_label: Label = $PlayerResource3/crew
@onready var player_quarters_label: Label = $PlayerResource3/quarters
@onready var enemy_materials_label: Label = $EnemyResource1/materials
@onready var enemy_synthesizer_label: Label = $EnemyResource1/synthesizer
@onready var enemy_energy_label: Label = $EnemyResource2/energy
@onready var enemy_reactor_label: Label = $EnemyResource2/reactor
@onready var enemy_crew_label: Label = $EnemyResource3/crew
@onready var enemy_quarters_label: Label = $EnemyResource3/quarters

func _ready() -> void:
	hand.deal(card_slots.size())
	enemy_hand.deal(card_slots.size())
	for slot in range(card_slots.size()):
		var button: Button = get_node(card_slots[slot])
		button.pressed.connect(_on_card_pressed.bind(slot))
		button.discard_requested.connect(_discard_card.bind(slot))
	enemy_timer.timeout.connect(_on_enemy_timeout)
	_begin_turn("player")


func _read_state(side: String) -> Dictionary:
	var state: Dictionary = {}
	for key in ["hull", "shields", "materials", "energy", "crew", "synthesizer", "reactor", "quarters"]:
		state[key] = get(side + "_" + key)
	return state


func _write_state(side: String, state: Dictionary) -> void:
	for key in state:
		set(side + "_" + key, state[key])


func _on_card_pressed(slot: int) -> void:
	_act("player", slot, false)


func _discard_card(slot: int) -> void:
	_act("player", slot, true)


func _begin_turn(side: String) -> void:
	current_actor = side
	extra_action_requested = false
	if _check_winner():
		refresh_display()
		return
	var before: Dictionary = _both_states()
	var state: Dictionary = _read_state(side)
	MatchRules.income(state)
	_write_state(side, state)
	battle_effects.play_changes(before, _both_states())
	resolving_card = battle_effects.busy
	_check_winner()
	refresh_display()
	if battle_effects.busy:
		await battle_effects.finished
	if battle_effects.cancelling or is_queued_for_deletion():
		return
	resolving_card = false
	refresh_display()
	if winner.is_empty() and side == "enemy":
		enemy_timer.start()


func _act(side: String, slot: int, discard: bool) -> bool:
	if resolving_card or current_actor != side or not winner.is_empty():
		return false
	if _check_winner():
		refresh_display()
		return false
	var active_hand = hand if side == "player" else enemy_hand
	if slot < 0 or slot >= active_hand.cards.size():
		return false
	var card: Resource = active_hand.cards[slot]
	if card == null:
		return false
	if not discard and get(side + "_" + card.family) < card.cost:
		return false
	resolving_card = true
	enemy_timer.stop()
	refresh_display()
	var source: Control = get_node(card_slots[slot]) if side == "player" else null
	var motion = $CardMotion
	await motion.animate_action(card, source, side, discard,
		_resolve_card.bind(side, slot, discard, card))
	if motion.cancelling or not is_inside_tree() or is_queued_for_deletion():
		return false
	if battle_effects.busy:
		await battle_effects.finished
	if battle_effects.cancelling or is_queued_for_deletion():
		return false
	resolving_card = false
	if _check_winner():
		refresh_display()
	elif extra_action_requested:
		# Another action in the same turn: no additional production income.
		refresh_display()
		if side == "enemy":
			enemy_timer.start()
	else:
		turn_number += 1
		await _begin_turn("enemy" if side == "player" else "player")
	action_finished.emit(side, discard)
	return true


func _resolve_card(side: String, slot: int, discard: bool, card: Resource) -> void:
	var before: Dictionary = _both_states()
	var active_hand = hand if side == "player" else enemy_hand
	var other: String = "enemy" if side == "player" else "player"
	var actor: Dictionary = _read_state(side)
	var target: Dictionary = _read_state(other)
	if discard:
		actor[card.family] += int(floor(card.cost / 3.0))
	else:
		CardEffects.play(card, actor, target)
	_write_state(side, actor)
	_write_state(other, target)
	active_hand.replace_card(slot)
	extra_action_requested = not discard and card.play_again
	var who: String = "You" if side == "player" else "Enemy"
	var action: String = "discarded" if discard else "played"
	$LastActionLabel.text = "%s %s %s" % [who, action, card.card_name]
	if discard:
		$LastActionLabel.text += " (+%d %s)" % [int(floor(card.cost / 3.0)), card.family.capitalize()]
	elif extra_action_requested:
		$LastActionLabel.text += " — play again"
	battle_effects.play_changes(before, _both_states(), side,
		card.family, 0 if discard else card.cost,
		not discard and (card.effects.get("damage", 0) > 0 or card.effects.get("break_shields", 0) > 0))
	_check_winner()
	refresh_display()


func _both_states() -> Dictionary:
	return {"player": _read_state("player"), "enemy": _read_state("enemy")}


func _on_enemy_timeout() -> void:
	if resolving_card or current_actor != "enemy" or not winner.is_empty():
		return
	var move: Dictionary = enemy_ai.choose(enemy_hand.cards, _read_state("enemy"),
		_read_state("player"), hull_goal, resource_goal)
	if move.is_empty():
		# A deliberately undersized custom pool may leave the AI with no cards.
		$LastActionLabel.text = "Enemy has no cards — passes"
		turn_number += 1
		_begin_turn("player")
		return
	_act("enemy", move.slot, move.discard)


func _check_winner() -> bool:
	if not winner.is_empty():
		return true
	var player: Dictionary = _read_state("player")
	var enemy: Dictionary = _read_state("enemy")
	if MatchRules.wins(player, enemy, hull_goal, resource_goal):
		winner = "player"
	elif MatchRules.wins(enemy, player, hull_goal, resource_goal):
		winner = "enemy"
	if not winner.is_empty():
		enemy_timer.stop()
	return not winner.is_empty()


func refresh_display() -> void:
	$PlayerShip/ShieldPlaceholder.visible = player_shields > 0
	$EnemyShip/ShieldPlaceholder.visible = enemy_shields > 0
	var player_can_act: bool = winner.is_empty() and current_actor == "player" and not resolving_card
	if winner.is_empty():
		$TurnLabel.text = "Turn %d · %s" % [turn_number, "You" if current_actor == "player" else "Enemy"]
	else:
		$TurnLabel.text = "YOU WIN" if winner == "player" else "ENEMY WINS"
	player_hull_label.text = "Hull %d" % player_hull
	player_shields_label.text = "Shields %d" % player_shields
	enemy_hull_label.text = "Hull %d" % enemy_hull
	enemy_shields_label.text = "Shields %d" % enemy_shields
	battle_effects.set_number(player_materials_label, player_materials)
	player_synthesizer_label.text = str(player_synthesizer)

	battle_effects.set_number(player_energy_label, player_energy)
	player_reactor_label.text = str(player_reactor)
	battle_effects.set_number(player_crew_label, player_crew)
	player_quarters_label.text = str(player_quarters)
	battle_effects.set_number(enemy_materials_label, enemy_materials)
	enemy_synthesizer_label.text = str(enemy_synthesizer)
	battle_effects.set_number(enemy_energy_label, enemy_energy)
	enemy_reactor_label.text = str(enemy_reactor)
	battle_effects.set_number(enemy_crew_label, enemy_crew)
	enemy_quarters_label.text = str(enemy_quarters)
	for slot in range(card_slots.size()):
		var button = get_node(card_slots[slot])
		var card: Resource = hand.cards[slot]
		button.card_data = card
		var playable: bool = card != null and player_can_act
		if playable:
			playable = get("player_" + card.family) >= card.cost
		button.set_playable(playable)
		button.set_discardable(card != null and player_can_act)
