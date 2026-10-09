extends Control

# HUVUDANSVAR: Hantera sex testkort och visa aktuell status.
# GÖR INTE: Hantera korthand, turer, AI eller animationer.

# Kortdata: kostnaden betalas innan effekten utförs.
const CARDS: Dictionary = {
	"ShieldPlatingCard": {"family": "materials", "cost": 3, "effect": "shields", "amount": 4},
	"SynthesizerUpgradeCard": {"family": "materials", "cost": 8, "effect": "synthesizer", "amount": 1},
	"LaserBurstCard": {"family": "energy", "cost": 6, "effect": "damage", "amount": 6},
	"EnergyCellCard": {"family": "energy", "cost": 3, "effect": "energy", "amount": 4},
	"QuartersUpgradeCard": {"family": "crew", "cost": 8, "effect": "quarters", "amount": 1},
	"TorpedoSalvoCard": {"family": "crew", "cost": 10, "effect": "damage", "amount": 12},
}

#PLAYER
var player_hull: int = 30
var player_shields: int = 10

var player_materials: int = 16
var player_energy: int = 16
var player_crew: int = 16

var player_synthesizer: int = 2
var player_reactor: int = 2
var player_quarters: int = 2


# ENEMY
var enemy_hull: int = 30
var enemy_shields: int = 10

var enemy_materials: int = 16
var enemy_energy: int = 16
var enemy_crew: int = 16

var enemy_synthesizer: int = 2
var enemy_reactor: int = 2
var enemy_quarters: int = 2

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
	for card_name in CARDS:
		var card_button: Button = get_node(NodePath(card_name)) as Button
		card_button.pressed.connect(_on_card_pressed.bind(card_name))
	refresh_display()


func _on_card_pressed(card_name: String) -> void:
	var card: Dictionary = CARDS[card_name]
	var family: String = card["family"]
	var cost: int = card["cost"]
	if enemy_hull <= 0 or player_hull <= 0 or player_resource(family) < cost:
		return

	# Betala exakt en gång, före effekten.
	match family:
		"materials": player_materials -= cost
		"energy": player_energy -= cost
		"crew": player_crew -= cost

	var amount: int = card["amount"]
	match card["effect"]:
		"shields": player_shields += amount
		"synthesizer": player_synthesizer += amount
		"damage": damage_enemy(amount)
		"energy": player_energy += amount
		"quarters": player_quarters += amount
	refresh_display()


func player_resource(family: String) -> int:
	match family:
		"materials": return player_materials
		"energy": return player_energy
		"crew": return player_crew
	return 0

func damage_enemy(amount: int) -> void:
	var damage: int = maxi(amount, 0)
	var absorbed: int = mini(enemy_shields, damage)

	enemy_shields -= absorbed

	var hull_damage: int = damage - absorbed
	enemy_hull = maxi(enemy_hull - hull_damage, 0)


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
	for card_name in CARDS:
		var card: Dictionary = CARDS[card_name]
		var card_button: Button = get_node(NodePath(card_name)) as Button
		card_button.disabled = enemy_hull <= 0 or player_hull <= 0 or player_resource(card["family"]) < card["cost"]
		card_button.modulate = Color(0.55, 0.55, 0.55) if card_button.disabled else Color.WHITE
