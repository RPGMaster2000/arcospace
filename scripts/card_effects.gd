extends RefCounted

# RESPONSIBILITY: Pay for and apply a card to two state dictionaries.
# DOES NOT: Draw cards, grant turn income, choose AI moves or update the UI.
const RESOURCES = ["materials", "energy", "crew"]
const PRODUCTION = ["synthesizer", "reactor", "quarters"]

# Independent combat RNG; simulation mode never samples this generator.
static var combat_rng: RandomNumberGenerator = _new_rng()
static func _new_rng() -> RandomNumberGenerator:
	var generator = RandomNumberGenerator.new()
	generator.randomize()
	return generator

static func play(card: Resource, actor: Dictionary, enemy: Dictionary, generator: RandomNumberGenerator = null, simulate: bool = false, damage_report: Dictionary = {}) -> bool:
	damage_report.clear()
	damage_report.merge({"actor":0,"target":0})
	if actor[card.family] < card.cost:
		return false
	actor[card.family] -= card.cost
	var effects: Dictionary = card.effects
	for key in ["hull", "shields"] + RESOURCES + PRODUCTION:
		actor[key] += int(effects.get(key, 0))
	# TUNE in each .tres: production_other.type maps production to its matching resource.
	var upgrade: Dictionary = effects.get("production_other", {})
	var production: String = upgrade.get("type", "")
	var index: int = PRODUCTION.find(production)
	if index >= 0 and RESOURCES[index] != card.family:
		actor[production] += int(upgrade.get("production", 0))
		actor[RESOURCES[index]] += int(upgrade.get("resource", 0))
	# Random bonuses are ignored for conservative AI win checks: no assumed lucky gain.
	if not simulate:
		var random_source = combat_rng if generator == null else generator
		for key in ["random_gain", "random_gain_other", "random_gain_range_other"]:
			if not effects.has(key):
				continue
			var choices: Array = RESOURCES.duplicate()
			if key != "random_gain":
				choices.erase(card.family)
			var resource: String = choices[random_source.randi_range(0, choices.size() - 1)]
			var amount: int = 0
			if key == "random_gain_range_other":
				var bounds: Dictionary = effects[key]
				amount = random_source.randi_range(int(bounds.get("min", 0)), int(bounds.get("max", 0)))
			else:
				amount = int(effects[key])
			actor[resource] += amount
	if effects.get("swap_shields", false):
		var previous: int = actor.shields
		actor.shields = enemy.shields
		enemy.shields = previous
	# Strict threshold checked at resolution; exactly the threshold never qualifies.
	if effects.has("shield_collapse_below") and enemy.shields < int(effects.shield_collapse_below):
		enemy.shields = 0
	# Shield breaking happens before regular damage (Breach Charge).
	enemy.shields = maxi(0, enemy.shields - int(effects.get("break_shields", 0)))
	var damage: int = int(effects.get("damage", 0))
	var direct: int = int(floor(damage * float(effects.get("pierce", 0.0))))
	var blocked: int = mini(enemy.shields, damage - direct)
	enemy.shields -= blocked
	damage_report.target = mini(enemy.hull, maxi(0, damage - blocked))
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
			enemy[key] = maxi(1, enemy[key] - int(effects.sabotage))
	# Self damage is direct hull loss for either acting ship; shields cannot absorb it.
	damage_report.actor = mini(actor.hull, maxi(0, int(effects.get("self_damage", 0))))
	actor.hull = maxi(0, actor.hull - int(effects.get("self_damage", 0)))
	return true
