extends RefCounted

# RESPONSIBILITY: Check win conditions and grant production income.
# DOES NOT: Select cards, change hands or update the scene.
const RESOURCES = preload("res://scripts/combat/ship_combat_state.gd").RESOURCES
const SYSTEMS_FAILURE_THRESHOLD = 2
const PRODUCTION = preload("res://scripts/combat/ship_combat_state.gd").PRODUCTION


static func wins(_actor: Dictionary, enemy: Dictionary) -> bool:
	return (
		enemy.hull <= 0
		or (
			int(enemy.get("systems_failure_remaining", -1)) == 0
			and systems_failure_triggered(enemy)
		)
	)


static func offline_systems(ship: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in PRODUCTION:
		if int(ship[key]) <= 0:
			result.append(key)
	return result


static func systems_failure_triggered(ship: Dictionary) -> bool:
	return offline_systems(ship).size() >= SYSTEMS_FAILURE_THRESHOLD


static func income(actor: Dictionary) -> void:
	for index in range(RESOURCES.size()):
		actor[RESOURCES[index]] += actor[PRODUCTION[index]]
