extends RefCounted
# Data required to enter one expedition battle; no live scene references.
const ShipState = preload("res://scripts/combat/ship_combat_state.gd")
var battle_seed: int = -1
var encounter_index: int = -1
var system_number: int = 0
var player_ship: int = 0
var enemy_ship: int = 0
var player_profile: Resource
var enemy_profile: Resource
var player_state: ShipState
var enemy_state: ShipState
var modifier: int = 0
var player_cards: Array[Resource] = []
var enemy_cards: Array[Resource] = []
var identity_weights: Dictionary = {}
var salvage: int = 0
var battles_won: int = 0
var emp_charge: int = 0
var emp_offline: int = 0
var chasedown_charge_cap: bool = false

var emp_requirement_bonus: int = 0

var emp_victory_message: String = ""
