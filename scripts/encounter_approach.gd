extends Resource
class_name EncounterApproach

@export var title: String = ""
@export_enum("None:", "Fabricator:synthesizer", "Reactor:reactor", "Hangar:quarters") var requirement: String = ""
@export_range(0, 20, 1) var minimum_production: int = 3
@export_range(0, 1000, 1) var salvage_cost: int = 0
@export_range(0.0, 1.0, 0.01) var success_chance: float = 1.0
@export var success: EncounterOutcome
@export var failure: EncounterOutcome
