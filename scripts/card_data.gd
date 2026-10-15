@tool
extends Resource
class_name CardData

# RESPONSIBILITY: Store Inspector-editable card data.
# DOES NOT: Change game state or manage turns.
## TUNE: Tier controls draw eligibility and border presentation; current rare cards are not yet added.
@export_enum("Tier 1:1", "Tier 2:2", "Tier 3:3") var tier: int = 1
## TUNE: Expedition upgrades reduce cost, never below one. Zero disables upgrades.
@export_range(0, 10, 1) var upgrade_cost_reduction: int = 1
@export_range(0, 10, 1) var max_upgrades: int = 3
var upgrade_level: int = 0

func identity_key() -> String:
	return str(get_meta("card_identity", resource_path if not resource_path.is_empty() else card_name))

## TUNE: Card title shown in the UI; edit each cards/*.tres resource in the Inspector.
@export var card_name: String = "":
	set(value):
		card_name = value
		emit_changed()
## TUNE: Resource type spent to play this card.
@export_enum("materials", "energy", "crew") var family: String = "materials":
	set(value):
		family = value
		emit_changed()
## TUNE: Resource amount needed to play the card.
@export var cost: int = 0:
	set(value):
		cost = value
		emit_changed()
## TUNE: Displayed explanation only; update effects separately to change gameplay.
@export_multiline var description: String = "":
	set(value):
		description = value
		emit_changed()
## TUNE: Gameplay amounts, e.g. damage: 6 or shields: 4. Use keys supported by card_effects.gd.
@export var effects: Dictionary = {}:
	set(value):
		effects = value
		emit_changed()
## TUNE: Set true to grant another action, without extra income or FTL charge.
@export var play_again: bool = false:
	set(value):
		play_again = value
		emit_changed()
