extends RefCounted
# Development-only schema checks. Never resolve, normalize, mutate, own cards or sample RNG.
# Consumer decisions and exact execution order: docs/card_effect_contract.md.
const Data = preload("res://scripts/cards/card_data.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
const RESOURCES = Ship.RESOURCES
const PRODUCTION = Ship.PRODUCTION
const ATTRIBUTES = Ship.ATTRIBUTES
const CONDITION_ATTRIBUTES = ATTRIBUTES + ["hull_capacity"]
const COMPARISONS = ["below", "at_most", "equal", "at_least", "above"]
const TARGETS = ["self", "enemy"]
const CATEGORIES = ["offense", "defense", "systems"]
# Value forms, not runtime dispatch. Every key needs a reviewed consumer decision and parity case.
const FORMS = {
	"hull":"number", "shields":"number", "materials":"number", "energy":"number",
	"crew":"number", "synthesizer":"number", "reactor":"number", "quarters":"number",
	"damage":"number", "pierce":"fraction", "break_shields":"number",
	"shield_collapse_below":"number", "self_damage":"number", "self_damage_regular":"number",
	"random_gain":"number", "random_gain_other":"number", "random_sabotage":"number",
	"sabotage":"number_or_bool", "swap_shields":"bool", "swap_resource":"resource",
	"drain":"resources", "steal":"resources", "enemy_production":"production",
	"production_other":"production_other", "random_gain_range_other":"range",
	"shield_collapse":"collapse", "conditional":"conditional",
}
# Review ledger: execution, descriptions, targets, modifiers, AI, upgrade inspection.
# Not a second registry: no cards or handlers are registered here. Details are in the coverage table.
const COVERAGE = {
	"hull":"direct/generic/signed/ion/simulation/generic",
	"shields":"direct/generic/signed/ion+flare/simulation/generic",
	"materials":"direct/generic/signed/ion/simulation/generic",
	"energy":"direct/generic/signed/ion/simulation/generic",
	"crew":"direct/generic/signed/ion/simulation/generic",
	"synthesizer":"direct/generic/signed/ion/simulation/generic",
	"reactor":"direct/generic/signed/ion/simulation/generic",
	"quarters":"direct/generic/signed/ion/simulation/generic",
	"damage":"shield-first/special/absorption/ion+nebula/simulation/special",
	"pierce":"damage-fraction/special/absorption/unchanged/simulation/special",
	"break_shields":"before-damage/special/absorption/ion+nebula/simulation/generic",
	"shield_collapse_below":"strict-below/special/conditional-clear/nebula/simulation/generic",
	"self_damage":"hull/special/signed/ion+miss-retained/simulation/generic",
	"self_damage_regular":"shield-first/special/absorption/ion/simulation/generic",
	"random_gain":"random/special/uncertain/ion/omitted+expectation/generic",
	"random_gain_other":"random-excluding-family/special/uncertain/ion/omitted+expectation/generic",
	"random_gain_range_other":"resource-then-amount/special/uncertain/ion/omitted+expectation/special",
	"random_sabotage":"random-production/special/uncertain/ion+nebula/enumerated/generic",
	"sabotage":"all-production/special/signed/ion+nebula/simulation/generic",
	"swap_shields":"exchange/special/difference/flare+nebula/simulation/generic",
	"swap_resource":"non-family-exchange/special/difference/nebula/simulation/generic",
	"drain":"before-theft/special/signed/ion+nebula/simulation/special",
	"steal":"bounded-by-reserve/special/signed/ion+nebula/simulation/special",
	"enemy_production":"clamped/special/signed/ion+nebula/simulation/special",
	"production_other":"non-family-pair/special/paired/ion/simulation/special",
	"shield_collapse":"clear-and-risk/special/uncertain-backlash/ion+nebula/worst-case/special",
	"conditional":"after-base/recursive/ordered-or-uncertain/recursive/simulation/recursive",
}

static func issue(errors: Array[String], path: String, expected: String, actual: Variant) -> void:
	errors.append("%s: expected %s, received %s (%s)" % [path, expected, type_string(typeof(actual)), var_to_str(actual)])

static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func number(value: Variant, path: String, errors: Array[String], fraction: bool = false) -> void:
	if not numeric(value) or (fraction and (float(value) < 0.0 or float(value) > 1.0)):
		issue(errors, path, "finite numeric value in [0, 1]" if fraction else "finite numeric value", value)

static func member(value: Variant, choices: Array, path: String, errors: Array[String]) -> void:
	if not value is String or value not in choices:
		issue(errors, path, "one of %s" % str(choices), value)

static func fields(value: Dictionary, allowed: Array, required: Array, path: String, errors: Array[String]) -> void:
	for key in value:
		if key not in allowed:
			issue(errors, path + "." + str(key), "supported field %s" % str(allowed), value[key])
	for key in required:
		if not value.has(key): issue(errors, path + "." + key, "required field", null)

static func effects(value: Variant, path: String = "effects", ancestors: Array = []) -> Array[String]:
	var errors: Array[String] = []
	if not value is Dictionary:
		issue(errors, path, "effect Dictionary", value)
		return errors
	for ancestor in ancestors:
		if is_same(ancestor, value):
			errors.append(path + ": expected acyclic conditional branches, received ancestor Dictionary")
			return errors
	var chain: Array = ancestors.duplicate()
	chain.append(value)
	for key in value:
		var at: String = path + "." + str(key)
		var item: Variant = value[key]
		if not FORMS.has(key):
			issue(errors, at, "supported effect key", item)
			continue
		var form: String = FORMS[key]
		match form:
			"number", "fraction": number(item, at, errors, form == "fraction")
			"number_or_bool":
				if not item is bool: number(item, at, errors)
			"bool":
				if not item is bool: issue(errors, at, "bool", item)
			"resource": member(item, RESOURCES, at, errors)
			_:
				if not item is Dictionary:
					issue(errors, at, "Dictionary", item)
					continue
				match form:
					"resources", "production":
						fields(item, RESOURCES if form == "resources" else PRODUCTION, [], at, errors)
						for stat in item: number(item[stat], at + "." + str(stat), errors)
					"production_other":
						fields(item, ["type", "production", "resource"], ["type", "production", "resource"], at, errors)
						if item.has("type"): member(item.type, PRODUCTION, at + ".type", errors)
						for stat in ["production", "resource"]:
							if item.has(stat): number(item[stat], at + "." + stat, errors)
					"range":
						fields(item, ["min", "max"], ["min", "max"], at, errors)
						for stat in ["min", "max"]:
							if item.has(stat): number(item[stat], at + "." + stat, errors)
						if numeric(item.get("min")) and numeric(item.get("max")) and int(item.min) > int(item.max):
							issue(errors, at + ".max", "maximum >= integer-converted minimum", item.max)
					"collapse":
						fields(item, ["threshold", "chance", "self_damage"], ["threshold", "chance", "self_damage"], at, errors)
						for stat in ["threshold", "chance", "self_damage"]:
							if item.has(stat): number(item[stat], at + "." + stat, errors, stat == "chance")
					"conditional":
						fields(item, ["target", "attribute", "comparison", "threshold", "compare_target", "compare_attribute", "fraction_of", "then", "else"], [], at, errors)
						for stat in ["target", "compare_target"]:
							if item.has(stat): member(item[stat], TARGETS, at + "." + stat, errors)
						for stat in ["attribute", "compare_attribute", "fraction_of"]:
							if item.has(stat): member(item[stat], CONDITION_ATTRIBUTES, at + "." + stat, errors)
						if item.has("comparison"): member(item.comparison, COMPARISONS, at + ".comparison", errors)
						if item.has("threshold"): number(item.threshold, at + ".threshold", errors)
						if item.has("fraction_of") and not item.has("threshold"):
							issue(errors, at + ".threshold", "required fraction multiplier", null)
						if item.has("compare_target") and not item.has("compare_attribute"):
							issue(errors, at + ".compare_attribute", "required comparison attribute", null)
						for branch in ["then", "else"]:
							if item.has(branch): errors.append_array(effects(item[branch], at + "." + branch, chain))
	return errors

static func card(definition: Resource) -> Array[String]:
	var errors: Array[String] = []
	if definition == null:
		issue(errors, "card", "CardData Resource", definition)
		return errors
	if not definition is Data:
		issue(errors, definition.resource_path, "CardData Resource", definition)
		return errors
	var path: String = "%s — %s" % [definition.resource_path if not definition.resource_path.is_empty() else "<temporary>", definition.card_name]
	if definition.identity_key().strip_edges().is_empty(): issue(errors, path + ".identity", "nonempty stable identity", definition.identity_key())
	if definition.card_name.strip_edges().is_empty(): issue(errors, path + ".card_name", "nonempty title", definition.card_name)
	if definition.tier not in [1, 2, 3]: issue(errors, path + ".tier", "tier 1, 2 or 3", definition.tier)
	member(definition.family, RESOURCES, path + ".family", errors)
	member(definition.allocation_category, CATEGORIES, path + ".allocation_category", errors)
	if definition.cost < 0: issue(errors, path + ".cost", "nonnegative int", definition.cost)
	if definition.max_upgrades < 0 or definition.max_upgrades > 2 or definition.max_upgrades > definition.upgrade_effects.size():
		issue(errors, path + ".max_upgrades", "0..2 with available definitions", definition.max_upgrades)
	if definition.upgrade_effects.size() > 2: issue(errors, path + ".upgrade_effects", "at most two replacement Dictionaries", definition.upgrade_effects)
	if definition.upgrade_level < 0 or definition.upgrade_level > definition.max_upgrades:
		issue(errors, path + ".upgrade_level", "0..max_upgrades", definition.upgrade_level)
	errors.append_array(effects(definition.effects, path + " — Base"))
	for index in range(definition.upgrade_effects.size()):
		errors.append_array(effects(definition.upgrade_effects[index], path + " — Upgrade " + (["I", "II"][index] if index < 2 else str(index + 1))))
	# Only inspect copies after structural checks: malformed dictionaries must never reach descriptions.
	if errors.is_empty():
		for level in range(definition.max_upgrades + 1):
			var upgraded: Resource = definition.with_upgrade(level)
			if upgraded.identity_key() != definition.identity_key() or upgraded.upgrade_level != level:
				issue(errors, path + ".with_upgrade(%d)" % level, "preserved identity and exact level", upgraded.identity_key())
	return errors

static func library(definitions: Array) -> Array[String]:
	var errors: Array[String] = []
	var identities: Dictionary = {}
	for definition in definitions:
		if not definition is Resource:
			issue(errors, "library", "CardData Resource", definition)
			continue
		errors.append_array(card(definition))
		if not definition is Data: continue
		var identity: String = definition.identity_key()
		if identities.has(identity):
			errors.append("%s — %s — identity: duplicate registered identity %s (first: %s)" % [definition.resource_path, definition.card_name, identity, identities[identity]])
		identities[identity] = definition.resource_path
	return errors
