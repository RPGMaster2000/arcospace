extends RefCounted

# RESPONSIBILITY: Pay for and apply a card to two state dictionaries.
# DOES NOT: Draw cards, grant turn income, choose AI moves or update the UI.
const RESOURCES = ["materials", "energy", "crew"]
const PRODUCTION = ["synthesizer", "reactor", "quarters"]

static func play(card: Resource, actor: Dictionary, enemy: Dictionary) -> bool:
	if actor[card.family] < card.cost:
		return false
	actor[card.family] -= card.cost
	var effects: Dictionary = card.effects
	for key in ["hull", "shields"] + RESOURCES + PRODUCTION:
		actor[key] += int(effects.get(key, 0))
	if effects.get("swap_shields", false):
		var previous: int = actor.shields
		actor.shields = enemy.shields
		enemy.shields = previous
	# Shield breaking happens before regular damage (Breach Charge).
	enemy.shields = maxi(0, enemy.shields - int(effects.get("break_shields", 0)))
	var damage: int = int(effects.get("damage", 0))
	var direct: int = int(floor(damage * float(effects.get("pierce", 0.0))))
	var blocked: int = mini(enemy.shields, damage - direct)
	enemy.shields -= blocked
	enemy.hull = maxi(0, enemy.hull - damage + blocked)
	for key in RESOURCES:
		var drain: Dictionary = effects.get("drain", {})
		var steal: Dictionary = effects.get("steal", {})
		enemy[key] = maxi(0, enemy[key] - int(drain.get(key, 0)))
		var taken: int = mini(enemy[key], int(steal.get(key, 0)))
		enemy[key] -= taken
		actor[key] += taken
	if effects.get("sabotage", false):
		for key in PRODUCTION:
			enemy[key] = maxi(1, enemy[key] - 1)
	return true
