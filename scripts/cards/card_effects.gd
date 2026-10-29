extends RefCounted

# RESPONSIBILITY: Pay for and apply a card to two state dictionaries.
# DOES NOT: Draw cards, grant turn income, choose AI moves or update the UI.
const RESOURCES = preload("res://scripts/combat/ship_combat_state.gd").RESOURCES
const PRODUCTION = preload("res://scripts/combat/ship_combat_state.gd").PRODUCTION

# Optional forecast_draws replays explicit choices at the SAME draw sites; live calls leave it null.
# Independent combat RNG; simulation mode never samples this generator.
static var combat_rng: RandomNumberGenerator = _new_rng()

#region Effect resolution


# Mutate the supplied state dictionaries; Board writes them back, while EnemyAI passes copies.
# EXTEND: Add the key to card_effect_contract.gd and its executable consumer coverage first.
# See docs/card_effect_contract.md; this resolver remains authoritative for ordering and RNG.
static func play(
	card: Resource,
	actor: Dictionary,
	enemy: Dictionary,
	generator: RandomNumberGenerator = null,
	simulate: bool = false,
	damage_report: Dictionary = {},
	simulation_production_target: int = -1,
	forecast_draws: RefCounted = null
) -> bool:
	damage_report.clear()
	damage_report.merge({"actor": 0, "target": 0})
	if actor[card.family] < card.cost:
		return false
	actor[card.family] -= card.cost
	_apply_effects(
		card.effects,
		card.family,
		actor,
		enemy,
		generator,
		simulate,
		damage_report,
		simulation_production_target,
		forecast_draws
	)
	return true


# Ordered resolution: ordinary keys first, then the selected conditional branch. No nested payment.
static func _apply_effects(
	effects: Dictionary,
	family: String,
	actor: Dictionary,
	enemy: Dictionary,
	generator: RandomNumberGenerator,
	simulate: bool,
	damage_report: Dictionary,
	simulation_production_target: int,
	forecast_draws: RefCounted = null
) -> void:
	for key in ["hull", "shields"] + RESOURCES + PRODUCTION:
		actor[key] += int(effects.get(key, 0))
	# TUNE in each .tres: production_other.type maps production to its matching resource.
	var upgrade: Dictionary = effects.get("production_other", {})
	var production: String = upgrade.get("type", "")
	var index: int = PRODUCTION.find(production)
	if index >= 0 and RESOURCES[index] != family:
		actor[production] += int(upgrade.get("production", 0))
		actor[RESOURCES[index]] += int(upgrade.get("resource", 0))
	for key in PRODUCTION:
		actor[key] = maxi(0, actor[key])
		var adjustment: Dictionary = effects.get("enemy_production", {})
		enemy[key] = maxi(0, enemy[key] + int(adjustment.get(key, 0)))
	for key in RESOURCES + ["shields"]:
		actor[key] = maxi(0, actor[key])
	# Exchanges use both reserves from the same snapshot, after payment; never the cost family.
	var swapped: String = str(effects.get("swap_resource", ""))
	if swapped in RESOURCES and swapped != family:
		var reserves: Array = [actor[swapped], enemy[swapped]]
		actor[swapped] = reserves[1]
		enemy[swapped] = reserves[0]
	# Random bonuses are ignored for conservative AI win checks: no assumed lucky gain.
	if not simulate:
		var random_source = forecast_draws if forecast_draws != null else (combat_rng if generator == null else generator)
		for key in ["random_gain", "random_gain_other", "random_gain_range_other"]:
			if not effects.has(key):
				continue
			var choices: Array = RESOURCES.duplicate()
			if key != "random_gain":
				choices.erase(family)
			var resource: String = choices[random_source.randi_range(0, choices.size() - 1)]
			var amount: int = 0
			if key == "random_gain_range_other":
				var bounds: Dictionary = effects[key]
				amount = random_source.randi_range(
					int(bounds.get("min", 0)), int(bounds.get("max", 0))
				)
			else:
				amount = int(effects[key])
			actor[resource] += amount
	if effects.get("swap_shields", false):
		var previous: int = actor.shields
		actor.shields = enemy.shields
		enemy.shields = previous
	var backlash: int = 0
	var collapse: Dictionary = effects.get("shield_collapse", {})
	if not collapse.is_empty():
		if enemy.shields >= int(collapse.get("threshold", 10)):
			# AI assumes the harmful outcome, without sampling combat RNG.
			var source = forecast_draws if forecast_draws != null else (combat_rng if generator == null else generator)
			if simulate or source.randf() < float(collapse.get("chance", 0.5)):
				backlash = int(collapse.get("self_damage", 10))
		enemy.shields = 0
	# Strict threshold checked at resolution; exactly the threshold never qualifies.
	if effects.has("shield_collapse_below") and enemy.shields < int(effects.shield_collapse_below):
		enemy.shields = 0
	# Shield breaking happens before regular damage (Breach Charge).
	enemy.shields = maxi(0, enemy.shields - int(effects.get("break_shields", 0)))
	# Pierce bypasses Shields; the remaining damage is absorbed before Hull loss is reported.
	# Board uses this report to disrupt escape charging only for permanent Hull damage.
	var damage: int = int(effects.get("damage", 0))
	var direct: int = int(floor(damage * float(effects.get("pierce", 0.0))))
	var blocked: int = mini(enemy.shields, damage - direct)
	enemy.shields -= blocked
	# Presentation only: count ordinary opposing damage at the actual resolution site.
	# Includes shield absorption, selected conditional branches and modified/upgraded effects.
	damage_report["direct_damage"] = int(damage_report.get("direct_damage", 0)) + maxi(0, blocked) + mini(enemy.hull, maxi(0, damage - blocked))
	if not damage_report.has("target_before"):
		damage_report.target_before = enemy.hull
	damage_report.target += mini(enemy.hull, maxi(0, damage - blocked))
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
			enemy[key] = maxi(0, enemy[key] - int(effects.sabotage))
	if effects.get("random_sabotage", 0) > 0:
		# Simulation defaults to no lucky hit. AI may enumerate all three hypothetical targets.
		var target: int = simulation_production_target
		if not simulate:
			var source = forecast_draws if forecast_draws != null else (combat_rng if generator == null else generator)
			target = source.randi_range(0, PRODUCTION.size() - 1)
		if target >= 0 and target < PRODUCTION.size():
			var key: String = PRODUCTION[target]
			enemy[key] = maxi(0, enemy[key] - int(effects.random_sabotage))
	# Self damage is direct hull loss for either acting ship; shields cannot absorb it.
	if not damage_report.has("actor_before"):
		damage_report.actor_before = actor.hull
	var regular_self: int = maxi(0, int(effects.get("self_damage_regular", 0))) + backlash
	var self_blocked: int = mini(actor.shields, regular_self)
	actor.shields -= self_blocked
	var hull_loss: int = regular_self - self_blocked + maxi(0, int(effects.get("self_damage", 0)))
	damage_report.actor += mini(actor.hull, hull_loss)
	actor.hull = maxi(0, actor.hull - hull_loss)
	var condition: Dictionary = effects.get("conditional", {})
	if not condition.is_empty():
		var branch: Dictionary = condition.get(
			"then" if condition_matches(condition, actor, enemy) else "else", {}
		)
		_apply_effects(
			branch,
			family,
			actor,
			enemy,
			generator,
			simulate,
			damage_report,
			simulation_production_target,
			forecast_draws
		)


#endregion

#region Predicates and random source


# TUNE in CardData.effects/upgrade_effects: target, attribute, comparison and threshold.
# Optional compare_target/compare_attribute compare two live stats; fraction_of uses capacity.
static func condition_matches(condition: Dictionary, actor: Dictionary, enemy: Dictionary) -> bool:
	var subject: Dictionary = actor if condition.get("target", "self") == "self" else enemy
	var value: float = float(subject.get(str(condition.get("attribute", "hull")), 0))
	var threshold: float = float(condition.get("threshold", 0))
	if condition.has("compare_attribute"):
		var other: Dictionary = (
			actor if condition.get("compare_target", "self") == "self" else enemy
		)
		threshold = float(other.get(str(condition.compare_attribute), 0))
	elif condition.has("fraction_of"):
		threshold *= float(subject.get(str(condition.fraction_of), subject.get("hull", 0)))
	match str(condition.get("comparison", "at_most")):
		"below":
			return value < threshold
		"at_most":
			return value <= threshold
		"equal":
			return value == threshold
		"at_least":
			return value >= threshold
		"above":
			return value > threshold
	return false


static func _new_rng() -> RandomNumberGenerator:
	var generator = RandomNumberGenerator.new()
	generator.randomize()
	return generator

#endregion
