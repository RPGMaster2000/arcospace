extends Control

# HUVUDANSVAR: Visa och provspela kortbiblioteket samt aktuell status.
# GÖR INTE: Hantera korthand, turer, AI eller animationer.

const CardLibrary = preload("res://scripts/card_library.gd")
const CardEffects = preload("res://scripts/card_effects.gd")
const CARD_SLOTS = ["ShieldPlatingCard", "SynthesizerUpgradeCard", "LaserBurstCard",
	"EnergyCellCard", "QuartersUpgradeCard", "TorpedoSalvoCard"]
# Behåll de tidigare sex testkorten som första vy.
const STARTING_CARDS = [0, 3, 11, 7, 17, 19]
var library_page: int = -1
var extra_action_requested: bool = false

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
	for slot in range(CARD_SLOTS.size()):
		var button: Button = get_node(CARD_SLOTS[slot])
		button.pressed.connect(_on_card_pressed.bind(slot))
	$PreviousCards.pressed.connect(_change_page.bind(-1))
	$NextCards.pressed.connect(_change_page.bind(1))
	refresh_display()


func _change_page(direction: int) -> void:
	# -1 är startvyn; 0..4 visar hela biblioteket, sex kort per sida.
	library_page = wrapi(library_page + direction, -1, 5)
	refresh_display()


func _card_index(slot: int) -> int:
	return STARTING_CARDS[slot] if library_page == -1 else library_page * 6 + slot


func _read_state(side: String) -> Dictionary:
	var state: Dictionary = {}
	for key in ["hull", "shields", "materials", "energy", "crew", "synthesizer", "reactor", "quarters"]:
		state[key] = get(side + "_" + key)
	return state


func _write_state(side: String, state: Dictionary) -> void:
	for key in state:
		set(side + "_" + key, state[key])


func _on_card_pressed(slot: int) -> void:
	var index: int = _card_index(slot)
	if index >= CardLibrary.CARDS.size() or enemy_hull <= 0 or player_hull <= 0:
		return
	var card: Resource = CardLibrary.CARDS[index]
	var actor: Dictionary = _read_state("player")
	var enemy: Dictionary = _read_state("enemy")
	if not CardEffects.play(card, actor, enemy):
		return
	_write_state("player", actor)
	_write_state("enemy", enemy)
	# Turhanteraren kan senare använda denna flagga utan extra turinkomst.
	extra_action_requested = card.play_again
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
	$LibraryPage.text = "Test cards" if library_page == -1 else "Library %d / 5" % (library_page + 1)
	for slot in range(CARD_SLOTS.size()):
		var button: Button = get_node(CARD_SLOTS[slot])
		var index: int = _card_index(slot)
		button.visible = index < CardLibrary.CARDS.size()
		if not button.visible:
			continue
		var card: Resource = CardLibrary.CARDS[index]
		button.get_node("TitleLabel").text = card.card_name
		button.get_node("CostLabel").text = "%d %s" % [card.cost, card.family.capitalize()]
		button.get_node("DescriptionLabel").text = card.description
		var colors = {"materials": Color(1, 0.55, 0.5), "energy": Color(0.5, 0.8, 1), "crew": Color(0.5, 1, 0.65)}
		button.get_node("CostLabel").add_theme_color_override("font_color", colors[card.family])
		button.tooltip_text = card.card_name + "\n" + card.description
		button.disabled = enemy_hull <= 0 or player_hull <= 0 or get("player_" + card.family) < card.cost
		button.modulate = Color(0.55, 0.55, 0.55) if button.disabled else Color.WHITE
