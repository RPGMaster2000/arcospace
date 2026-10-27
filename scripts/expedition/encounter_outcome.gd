extends Resource
class_name EncounterOutcome

# RESPONSIBILITY: Define resolved PoI rewards, pending battle changes and choice rewards.

@export_multiline var blurb: String = ""
@export var salvage: int = 0
## Positive repairs permanent Hull only; negative damage can end the expedition.
@export var hull: int = 0
## Keys: materials, energy, crew, shields, emp_pulse_charge, emp_pulse_offline.
## Signed values: bonuses and penalties add separately; resource penalties cap at half base.
## EMP Pulse offline uses the longest individual duration.
@export var next_battle: Dictionary = {}
@export var card_reward: bool = false
@export_range(1, 3, 1) var minimum_card_tier: int = 1
@export var upgrade_card: bool = false
@export var resource_choice: int = 0
@export var production_choice: int = 0
