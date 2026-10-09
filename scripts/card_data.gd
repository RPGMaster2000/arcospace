@tool
extends Resource
class_name CardData

# HUVUDANSVAR: Kortets redigerbara data i Inspector.
# GÖR INTE: Ändra spelstatus eller hantera turer.
@export var card_name: String = "":
	set(value):
		card_name = value
		emit_changed()
@export_enum("materials", "energy", "crew") var family: String = "materials":
	set(value):
		family = value
		emit_changed()
@export var cost: int = 0:
	set(value):
		cost = value
		emit_changed()
@export_multiline var description: String = "":
	set(value):
		description = value
		emit_changed()
@export var effects: Dictionary = {}:
	set(value):
		effects = value
		emit_changed()
@export var play_again: bool = false:
	set(value):
		play_again = value
		emit_changed()
