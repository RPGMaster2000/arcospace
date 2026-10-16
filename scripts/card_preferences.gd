extends RefCounted
# Shared soft preference categories for draws; every identity retains positive weight.
static func categories(card: Resource) -> Array[String]:
	var result: Array[String] = []
	var effects: Dictionary = card.effects
	for key in ["damage", "hull", "shields", "steal"]:
		if effects.has(key): result.append(key)
	if effects.has("swap_shields") or effects.has("break_shields") or effects.has("shield_collapse") or effects.has("drain") or effects.has("sabotage"):
		result.append("disruption")
	if effects.has("production_other") or effects.has("synthesizer") or effects.has("reactor") or effects.has("quarters"):
		result.append("production")
	if effects.has("random_gain") or effects.has("random_gain_other") or effects.has("random_gain_range_other"):
		result.append("economy")
	for key in ["materials", "energy", "crew"]:
		if effects.has(key):
			result.append("economy")
			break
	return result

static func draw_weight(card: Resource, families: Dictionary, effects: Dictionary) -> float:
	var preference: float = 1.0
	var matched: bool = false
	for category in categories(card):
		if effects.has(category):
			preference = maxf(preference if matched else 0.01, float(effects[category]))
			matched = true
	return maxf(0.01, float(families.get(card.family, 1.0))) * preference
