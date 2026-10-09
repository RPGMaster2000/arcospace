extends Control

# HUVUDANSVAR: Koppla korthand, korteffekter och spelplanens status.
# GÖR INTE: Välja slumpkort, hantera turer, AI eller animationer.

const CardEffects = preload("res://scripts/card_effects.gd")
# Koppla scenens sex redigerbara kortknappar i Inspector.
@export var card_slots: Array[NodePath] = [NodePath("ShieldPlatingCard"),
	NodePath("SynthesizerUpgradeCard"), NodePath("LaserBurstCard"),
	NodePath("EnergyCellCard"), NodePath("QuartersUpgradeCard"), NodePath("TorpedoSalvoCard")]
var extra_action_requested: bool = false
var resolving_card: bool = false
@onready var hand = $CardHand

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
	for slot in range(card_slots.size()):
		var button: Button = get_node(card_slots[slot])
		button.pressed.connect(_on_card_pressed.bind(slot))
		button.discard_requested.connect(_discard_card.bind(slot))
	$DiscardToggle.toggled.connect(_on_discard_toggled)
	refresh_display()


func _read_state(side: String) -> Dictionary:
	var state: Dictionary = {}
	for key in ["hull", "shields", "materials", "energy", "crew", "synthesizer", "reactor", "quarters"]:
		state[key] = get(side + "_" + key)
	return state


func _write_state(side: String, state: Dictionary) -> void:
	for key in state:
		set(side + "_" + key, state[key])


func _on_card_pressed(slot: int) -> void:
	if $DiscardToggle.button_pressed:
		_discard_card(slot)
		return
	if resolving_card or slot < 0 or slot >= hand.cards.size():
		return
	if enemy_hull <= 0 or player_hull <= 0:
		return
	var card: Resource = hand.cards[slot]
	if card == null:
		return
	var actor: Dictionary = _read_state("player")
	var enemy: Dictionary = _read_state("enemy")
	resolving_card = true
	if not CardEffects.play(card, actor, enemy):
		resolving_card = false
		return
	_write_state("player", actor)
	_write_state("enemy", enemy)
	# Sparas till en framtida turhanterare; ingen turinkomst ges här.
	extra_action_requested = card.play_again
	# Effekten är klar innan samma plats får sitt nya kort.
	hand.replace_card(slot)
	resolving_card = false
	refresh_display()


func _on_discard_toggled(_enabled: bool) -> void:
	refresh_display()


func _discard_card(slot: int) -> void:
	if resolving_card or slot < 0 or slot >= hand.cards.size():
		return
	if enemy_hull <= 0 or player_hull <= 0:
		return
	var card: Resource = hand.cards[slot]
	if card == null:
		return
	resolving_card = true
	# Återvinn en tredjedel avrundat nedåt, utan kostnad eller korteffekt.
	var resource_key: String = "player_" + card.family
	var refund: int = int(floor(card.cost / 3.0))
	set(resource_key, get(resource_key) + refund)
	extra_action_requested = false
	hand.replace_card(slot)
	resolving_card = false
	# Pekskärmsläget gäller en kassering; högerklick fungerar alltid direkt.
	$DiscardToggle.set_pressed_no_signal(false)
	refresh_display()


func refresh_display() -> void:
	player_hull_label.text = "Hull: %d" % player_hull
	player_shields_label.text = "Shields: %d" % player_shields
	enemy_hull_label.text = "Hull: %d" % enemy_hull
	enemy_shields_label.text = "Shields: %d" % enemy_shields
	player_materials_label.text = str(player_materials)
	player_synthesizer_label.text = str(player_synthesizer)

	player_energy_label.text = str(player_energy)
	player_reactor_label.text = str(player_reactor)
	player_crew_label.text = str(player_crew)
	player_quarters_label.text = str(player_quarters)
	enemy_materials_label.text = str(enemy_materials)
	enemy_synthesizer_label.text = str(enemy_synthesizer)
	enemy_energy_label.text = str(enemy_energy)
	enemy_reactor_label.text = str(enemy_reactor)
	enemy_crew_label.text = str(enemy_crew)
	enemy_quarters_label.text = str(enemy_quarters)
	for slot in range(card_slots.size()):
		var button = get_node(card_slots[slot])
		var card: Resource = hand.cards[slot]
		button.card_data = card
		var playable: bool = card != null and enemy_hull > 0 and player_hull > 0
		if playable and not $DiscardToggle.button_pressed:
			playable = get("player_" + card.family) >= card.cost
		button.set_playable(playable)
