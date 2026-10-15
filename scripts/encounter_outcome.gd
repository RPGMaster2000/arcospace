extends Resource
class_name EncounterOutcome

@export_multiline var blurb: String = ""
@export var salvage: int = 0
## Positive repairs permanent Hull only; negative damage can end the expedition.
@export var hull: int = 0
## Keys: materials, energy, crew, shields, synthesizer, reactor, quarters, ftl_charge, ftl_offline.
## Signed values: bonuses and penalties are tracked separately, strongest of each wins.
@export var next_battle: Dictionary = {}
@export var card_reward: bool = false
@export_range(1, 3, 1) var minimum_card_tier: int = 1
@export var upgrade_card: bool = false
@export var resource_choice: int = 0
@export var production_choice: int = 0
