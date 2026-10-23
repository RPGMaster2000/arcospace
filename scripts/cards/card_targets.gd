extends RefCounted
# RESPONSIBILITY: Describe possible HUD categories, never resolve a live action or sample RNG.
const Effects = preload("res://scripts/cards/card_effects.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
const ATTRIBUTES = ["hull", "shields", "materials", "energy", "crew", "synthesizer", "reactor", "quarters"]

static func analyze(card: Resource, context: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var actor: Dictionary = context.player.duplicate(true)
	var enemy: Dictionary = context.enemy.duplicate(true)
	actor[card.family] -= card.cost
	var flare: bool = context.get("shields_disabled", false)
	if flare:
		actor.shields = 0
		enemy.shields = 0
	var uncertain: bool = context.get("nebula_miss_rate", 0) > 0 and Modifier.is_combat(card.effects)
	visit(card.effects, card.family, actor, enemy, result, uncertain, flare)
	if card.cost > 0:
		var key: String = "player_" + card.family
		if not result.has(key): result[key] = []
		result[key].append("cost")
	return result

static func mark(result: Dictionary, side: String, key: String, amount: float, uncertain: bool) -> void:
	if amount == 0: return
	var id: String = side + "_" + key
	var meaning: String = "uncertain" if uncertain else ("positive" if amount > 0 else "negative")
	if not result.has(id): result[id] = []
	if meaning not in result[id]: result[id].append(meaning)

static func damage(result: Dictionary, side: String, state: Dictionary, amount: int, pierce: float, uncertain: bool, flare: bool) -> void:
	var direct: int = floori(amount * pierce)
	var blocked: int = mini(state.shields, amount - direct) if not flare else 0
	mark(result, side, "shields", -blocked, uncertain)
	mark(result, side, "hull", -(amount - blocked), uncertain)

static func visit(effects: Dictionary, family: String, actor: Dictionary, enemy: Dictionary, result: Dictionary, uncertain: bool, flare: bool) -> void:
	for key in ATTRIBUTES:
		if key != "shields" or not flare:
			mark(result, "player", key, float(effects.get(key, 0)), uncertain)
	var production: Dictionary = effects.get("production_other", {})
	var index: int = Effects.PRODUCTION.find(production.get("type", ""))
	if index >= 0 and Effects.RESOURCES[index] != family:
		mark(result, "player", Effects.PRODUCTION[index], production.get("production", 0), uncertain)
		mark(result, "player", Effects.RESOURCES[index], production.get("resource", 0), uncertain)
	for key in Effects.RESOURCES:
		mark(result, "enemy", key, -float(effects.get("drain", {}).get(key, 0)), uncertain)
		var amount: float = effects.get("steal", {}).get(key, 0)
		mark(result, "enemy", key, -amount, uncertain)
		mark(result, "player", key, amount, uncertain)
		if key == effects.get("swap_resource", "") and key != family:
			var difference: float = enemy[key] - actor[key]
			mark(result, "player", key, difference, uncertain)
			mark(result, "enemy", key, -difference, uncertain)
		for random_key in ["random_gain", "random_gain_other", "random_gain_range_other"]:
			if effects.has(random_key) and (random_key == "random_gain" or key != family):
				mark(result, "player", key, 1, true)
	for key in Effects.PRODUCTION:
		mark(result, "enemy", key, effects.get("enemy_production", {}).get(key, 0), uncertain)
		mark(result, "enemy", key, -float(effects.get("sabotage", 0)), uncertain)
		if effects.get("random_sabotage", 0) > 0: mark(result, "enemy", key, -1, true)
	var shield_before: int = enemy.shields
	var cleared: bool = effects.has("shield_collapse") or (effects.has("shield_collapse_below") and enemy.shields < effects.shield_collapse_below)
	var broken: int = shield_before if cleared else mini(shield_before, int(effects.get("break_shields", 0)))
	if not flare: mark(result, "enemy", "shields", -broken, uncertain)
	var target: Dictionary = enemy.duplicate()
	target.shields = maxi(0, shield_before - broken)
	if effects.get("swap_shields", false) and not flare:
		var difference: int = enemy.shields - actor.shields
		mark(result, "player", "shields", difference, uncertain)
		mark(result, "enemy", "shields", -difference, uncertain)
		target.shields = actor.shields
	damage(result, "enemy", target, effects.get("damage", 0), effects.get("pierce", 0.0), uncertain, flare)
	mark(result, "player", "hull", -float(effects.get("self_damage", 0)), false)
	damage(result, "player", actor, effects.get("self_damage_regular", 0), 0.0, uncertain, flare)
	var collapse: Dictionary = effects.get("shield_collapse", {})
	if not collapse.is_empty() and enemy.shields >= collapse.get("threshold", 10):
		damage(result, "player", actor, collapse.get("self_damage", 10), 0.0, true, flare)
	var condition: Dictionary = effects.get("conditional", {})
	if condition.is_empty(): return
	var base: Dictionary = effects.duplicate(true)
	base.erase("conditional")
	var a: Dictionary = actor.duplicate(true)
	var b: Dictionary = enemy.duplicate(true)
	# Reuse the existing resolver on detached copies solely for the ordered condition predicate.
	Effects._apply_effects(base, family, a, b, null, true, {"actor": 0, "target": 0}, -1)
	var random_condition: bool = uncertain
	for key in ["random_gain", "random_gain_other", "random_gain_range_other", "random_sabotage", "shield_collapse"]:
		random_condition = random_condition or effects.has(key)
	if random_condition:
		visit(condition.get("then", {}), family, a, b, result, true, flare)
		visit(condition.get("else", {}), family, a, b, result, true, flare)
	else:
		visit(condition.get("then" if Effects.condition_matches(condition, a, b) else "else", {}), family, a, b, result, false, flare)
