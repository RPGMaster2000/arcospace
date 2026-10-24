extends RefCounted

# RESPONSIBILITY: Classify effects and compute soft family/effect draw preferences.
# EXTEND: Review soft categories separately from the contract consumer checklist; preserve weights.


# Shared soft preference categories for draws; every identity retains positive weight.
static func categories(card: Resource) -> Array[String]:
	return effect_categories(card.effects)


static func effect_categories(effects: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in ["damage", "hull", "shields", "steal"]:
		if effects.has(key):
			result.append(key)
	if (
		effects.has("swap_shields")
		or effects.has("break_shields")
		or effects.has("shield_collapse")
		or effects.has("drain")
		or effects.has("sabotage")
		or effects.has("random_sabotage")
		or effects.has("enemy_production")
		or effects.has("swap_resource")
	):
		result.append("disruption")
	if (
		effects.has("production_other")
		or effects.has("synthesizer")
		or effects.has("reactor")
		or effects.has("quarters")
		or effects.has("enemy_production")
	):
		result.append("production")
	if (
		effects.has("random_gain")
		or effects.has("random_gain_other")
		or effects.has("random_gain_range_other")
	):
		result.append("economy")
	for key in ["materials", "energy", "crew"]:
		if effects.has(key):
			result.append("economy")
			break
	var condition: Dictionary = effects.get("conditional", {})
	for branch in [condition.get("then", {}), condition.get("else", {})]:
		if branch.is_empty():
			continue
		for category in effect_categories(branch):
			if category not in result:
				result.append(category)
	return result


static func draw_weight(card: Resource, families: Dictionary, effects: Dictionary) -> float:
	var preference: float = 1.0
	var matched: bool = false
	for category in categories(card):
		if effects.has(category):
			preference = maxf(preference if matched else 0.01, float(effects[category]))
			matched = true
	return maxf(0.01, float(families.get(card.family, 1.0))) * preference
