@tool
extends RefCounted
## Compact face copy from authoritative effects, in their actual resolution order.
## No branch factoring: conditions are evaluated AFTER base effects in combat.
## Full inspection continues to use CardData.describe_effects and upgrade data.
const Data = preload("res://scripts/cards/card_data.gd")
const RESOURCES = ["materials", "energy", "crew"]
const PRODUCTION = {"synthesizer": "Materials", "reactor": "Energy", "quarters": "Crew"}


static func number(value: Variant) -> String:
	return str(int(value)) if float(value) == int(value) else String.num(float(value), 2)


static func condition(rule: Dictionary) -> String:
	var subject := str(rule.get("attribute", "hull")).capitalize()
	if rule.get("target", "self") == "enemy":
		subject = "enemy " + subject
	var threshold := number(rule.get("threshold", 0))
	if rule.has("fraction_of"):
		threshold = number(float(rule.threshold) * 100) + "% max"
	elif rule.has("compare_attribute"):
		var other: String = rule.compare_attribute
		var same: bool = other == rule.get("attribute", "hull")
		threshold = (
			("yours" if same else "your " + other.capitalize())
			if rule.get("compare_target", "self") == "self"
			else ("enemy's" if same else "enemy " + other.capitalize())
		)
	return (
		"%s%s%s"
		% [
			subject,
			{"below": "<", "at_most": "≤", "equal": "=", "at_least": "≥", "above": ">"}.get(
				rule.get("comparison", "at_most"), "?"
			),
			threshold
		]
	)


static func rows(effects: Dictionary, family: String) -> Array[String]:
	var result: Array[String] = []
	var handled: Array = []
	for key in ["hull", "shields"] + RESOURCES + PRODUCTION.keys():
		if not effects.has(key):
			continue
		handled.append(key)
		var value: int = effects[key]
		if PRODUCTION.has(key):
			result.append("%s prod. %+d." % [PRODUCTION[key], value])
		elif key == "hull":
			result.append(("Repair %d Hull." if value >= 0 else "Lose %d Hull.") % absi(value))
		else:
			result.append(
				"%s %d %s." % ["Gain" if value >= 0 else "Lose", absi(value), str(key).capitalize()]
			)
	if effects.has("production_other"):
		handled.append("production_other")
		var item: Dictionary = effects.production_other
		if RESOURCES[PRODUCTION.keys().find(item.type)] != family:
			result.append("%s prod. %+d." % [PRODUCTION[item.type], item.production])
			result.append("Gain %d %s." % [item.resource, PRODUCTION[item.type]])
	if effects.has("enemy_production"):
		handled.append("enemy_production")
		for key in effects.enemy_production:
			result.append(
				(
					"Enemy %s %+d (min 0)."
					% [str(key).capitalize(), int(effects.enemy_production[key])]
				)
			)
	if effects.has("swap_resource"):
		handled.append("swap_resource")
		result.append("Swap %s reserves with enemy." % str(effects.swap_resource).capitalize())
	for key in ["random_gain", "random_gain_other", "random_gain_range_other"]:
		if not effects.has(key):
			continue
		handled.append(key)
		var amount := (
			number(effects[key])
			if key != "random_gain_range_other"
			else "%s–%s" % [number(effects[key].min), number(effects[key].max)]
		)
		if key == "random_gain":
			result.append("Gain %s random resource." % amount)
		else:
			var choices := RESOURCES.filter(func(item): return item != family)
			result.append(
				(
					"Gain %s random\n%s or %s."
					% [amount, str(choices[0]).capitalize(), str(choices[1]).capitalize()]
				)
			)
	if effects.has("swap_shields"):
		handled.append("swap_shields")
		if effects.swap_shields:
			result.append("Swap Shields with enemy.")
	if effects.has("shield_collapse"):
		handled.append("shield_collapse")
		var item: Dictionary = effects.shield_collapse
		result.append(
			(
				"Clear enemy Shields.\nIf started ≥%d:\n%s%% risk: take %d damage\n(Shields first)."
				% [item.threshold, number(float(item.chance) * 100), item.self_damage]
			)
		)
	if effects.has("shield_collapse_below"):
		handled.append("shield_collapse_below")
		result.append("Clear enemy Shields\nif below %d." % effects.shield_collapse_below)
	if effects.has("break_shields"):
		handled.append("break_shields")
		result.append("Break %d Shields." % effects.break_shields)
	if effects.has("damage"):
		handled.append("damage")
		result.append(
			(
				(
					"Deal %d Hull damage."
					if float(effects.get("pierce", 0)) >= 1.0
					else "Deal %d damage."
				)
				% effects.damage
			)
		)
	if effects.has("pierce"):
		handled.append("pierce")
		if float(effects.pierce) < 1.0:
			result.append("%s%% bypasses Shields." % number(float(effects.pierce) * 100))
	for key in ["drain", "steal"]:
		if not effects.has(key):
			continue
		handled.append(key)
		var values: Dictionary = effects[key]
		if (
			key == "drain"
			and values.size() == 3
			and values.get("materials") == values.get("energy")
			and values.get("energy") == values.get("crew")
		):
			result.append("Drain %d of each enemy resource." % values.materials)
		else:
			for kind in values:
				result.append(
					(
						("Steal up to %d %s." if key == "steal" else "Drain %d %s.")
						% [values[kind], str(kind).capitalize()]
					)
				)
	for key in ["sabotage", "random_sabotage"]:
		if not effects.has(key):
			continue
		handled.append(key)
		result.append(
			(
				"Enemy %s production −%d (min 0)."
				% ["all" if key == "sabotage" else "random", int(effects[key])]
			)
		)
	for key in ["self_damage", "self_damage_regular"]:
		if not effects.has(key):
			continue
		handled.append(key)
		result.append(
			(
				(
					"Take %d Hull damage."
					if key == "self_damage"
					else "Take %d damage\n(Shields first)."
				)
				% effects[key]
			)
		)
	# Keep the conditional branch after the base effects. Do not pull common
	# damage/repair outside branches: doing so can change threshold timing.
	if effects.has("conditional"):
		handled.append("conditional")
		var rule: Dictionary = effects.conditional
		if not result.is_empty():
			# Keep explicit timing, without making a long condition header wrap twice.
			result[-1] += " Then:"
		result.append("If " + condition(rule) + ":")
		result.append_array(rows(rule.get("then", {}), family))
		if not rule.get("else", {}).is_empty():
			var otherwise := rows(rule["else"], family)
			if not otherwise.is_empty():
				# Positive gains and damage retain their full amount/resource/type.
				# The branch label already establishes this as an action.
				if otherwise[0].begins_with("Gain "):
					otherwise[0] = "+" + otherwise[0].trim_prefix("Gain ")
				elif otherwise[0].begins_with("Deal "):
					otherwise[0] = otherwise[0].trim_prefix("Deal ")
				otherwise[0] = "Else: " + otherwise[0]
			result.append_array(otherwise)
	# Future effects must stay visible and fail the audit if too long, rather
	# than silently disappearing from the card face.
	for key in effects:
		if not handled.has(key):
			result.append(Data.describe_effects({key: effects[key]}))
	return result


static func card_text(card: Resource) -> String:
	var text := rows(card.effects, card.family)
	if card.play_again:
		text.append("Play again.")
	return "\n".join(text)
