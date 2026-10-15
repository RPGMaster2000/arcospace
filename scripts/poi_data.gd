extends Resource
class_name PoiData

@export var title: String = ""
@export_multiline var description: String = ""
@export var approaches: Array[EncounterApproach] = []
@export var hazardous: bool = false
@export_range(0.01, 100, 0.01) var encounter_weight: float = 1.0
