extends Resource
class_name FactionProfile
## Immutable configuration, referencing existing ships; ExpeditionState owns the ID.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var accent: Color = Color.WHITE
@export_range(0, 100, 0.1) var selection_weight: float = 1.0
@export var standard_roster: Array[Resource] = []
@export var elite_roster: Array[Resource] = []
@export var mothership: Resource
@export_range(1, 99, 1) var mothership_minimum_system: int = 1
## Optional path-keyed overrides; otherwise use each ship's existing encounter weight.
@export var enemy_weights: Dictionary = {}
