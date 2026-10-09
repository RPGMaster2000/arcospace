extends RefCounted

# RESPONSIBILITY: Check win conditions and grant production income.
# DOES NOT: Select cards, change hands or update the scene.
const RESOURCES = ["materials", "energy", "crew"]
const PRODUCTION = ["synthesizer", "reactor", "quarters"]

static func wins(actor: Dictionary, enemy: Dictionary, hull_goal: int, resource_goal: int) -> bool:
	if enemy.hull <= 0 or actor.hull >= hull_goal:
		return true
	for key in RESOURCES:
		if actor[key] < resource_goal:
			return false
	return true


static func income(actor: Dictionary) -> void:
	for index in range(RESOURCES.size()):
		actor[RESOURCES[index]] += actor[PRODUCTION[index]]
