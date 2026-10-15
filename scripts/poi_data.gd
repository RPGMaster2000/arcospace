extends Resource
class_name PoiData

@export var title: String = ""
@export_multiline var description: String = ""
@export var approaches: Array[EncounterApproach] = []
@export var hazardous: bool = false
@export_range(0.01, 100, 0.01) var encounter_weight: float = 1.0
@export_group("Presentation")
@export var banner_texture: Texture2D
## Presentation classification only; hazardous PoIs always retain their hazard color.
@export var anomalous_presentation: bool = false
