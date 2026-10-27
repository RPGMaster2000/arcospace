extends Resource
class_name ShipData
# RESPONSIBILITY: Inspector-editable ship starting values and optional model.
## TUNE: All statistics here apply when starting a fresh encounter.
@export var ship_name: String = "Endeavour"
## EDIT: Two-word ship type and defining property for the battle header.
@export var subtitle: String = "Balanced Cruiser"
@export var role: String = "Balanced"
@export_multiline var summary: String = ""
@export_range(1, 1000, 1) var hull_capacity: int = 35
@export var shields: int = 10
@export var materials: int = 10
@export var energy: int = 10
@export var crew: int = 10
@export var synthesizer: int = 2
@export var reactor: int = 2
@export var quarters: int = 2
@export_range(1, 1000, 1) var ftl_turns: int = 14
## TUNE: Fractional resistance: 0.25 reduces probability by 25%; -0.10 increases it by 10%.
@export_range(-1.0, 1.0, 0.01) var ftl_resistance: float = 0.0
## TUNE: Hull-only tint; shields, engines and effect materials stay separate.
@export var hull_color: Color = Color(0.52, 0.67, 0.73)
## EDIT: Optional replacement model; empty retains the existing battlefield ship.
## Custom models must support the ship_3d.gd animation API and Body/Shield nodes.
@export var model_scene: PackedScene

@export_group("Enemy expedition rewards")
@export_enum("Standard", "Elite", "Boss") var enemy_rank: int = 0
@export_range(0, 1000, 1) var destruction_salvage_reward: int = 10
@export_range(0.01, 100, 0.01) var encounter_weight: float = 1.0

@export_group("Card pools and enemy preferences")
## TUNE: Starting identities for either side. Empty uses the original library for enemies/custom ships.
@export var starting_cards: Array[Resource] = []
## TUNE: Positive soft multipliers; omitted families/effects retain weight 1.
@export var card_family_weights: Dictionary = {}
@export var card_effect_weights: Dictionary = {}
## TUNE: Scores for damage, Hull, Shields, production, resources and disruption.
@export var tactical_weights: Dictionary = {}
## TUNE: Random score variation; elites use less variation for more consistent decisions.
@export_range(0.0, 1.0, 0.01) var tactical_variation: float = 0.25
