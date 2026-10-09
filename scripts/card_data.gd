extends Resource
class_name CardData

# HUVUDANSVAR: Kortets redigerbara data i Inspector.
# GÖR INTE: Ändra spelstatus eller hantera turer.
@export var card_name: String = ""
@export_enum("materials", "energy", "crew") var family: String = "materials"
@export var cost: int = 0
@export_multiline var description: String = ""
@export var effects: Dictionary = {}
@export var play_again: bool = false
