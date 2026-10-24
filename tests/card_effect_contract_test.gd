extends SceneTree
const Contract = preload("res://scripts/cards/card_effect_contract.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Data = preload("res://scripts/cards/card_data.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Targets = preload("res://scripts/cards/card_targets.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const Text = preload("res://scripts/ui/card_effect_text.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
var checks: int = 0
var failures: int = 0
var malformed: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func invalid(value: Dictionary, path: String) -> void:
	malformed += 1
	var diagnostics: Array[String] = Contract.effects(value, "fixture")
	check(diagnostics.any(func(line): return line.begins_with("fixture." + path + ": expected ") and line.contains("received")), "Precise diagnostic for " + path + ": " + str(diagnostics))
func same_keys(a: Dictionary, b: Dictionary) -> bool:
	var left: Array = a.keys()
	var right: Array = b.keys()
	left.sort()
	right.sort()
	return left == right
func valid_card() -> Resource:
	var result = Data.new()
	result.card_name = "Contract fixture"
	result.max_upgrades = 0
	return result
func invalid_card(field: String, value: Variant, diagnostic: String) -> void:
	malformed += 1
	var card = valid_card()
	card.set(field, value)
	check(Contract.card(card).any(func(line): return line.contains(diagnostic)), "Card diagnostic " + diagnostic)
func _initialize() -> void:
	var diagnostics: Array[String] = Contract.library(Cards.CARDS)
	for line in diagnostics: push_error(line)
	check(diagnostics.is_empty(), "Every registered base/upgrade validates")
	check(same_keys(Contract.FORMS, Contract.COVERAGE), "Every effect has an explicit consumer ledger entry")
	for key in Contract.COVERAGE:
		check(Contract.COVERAGE[key].split("/").size() == 6, "Six reviewed consumer decisions: " + key)
	invalid({"unknown":1}, "unknown")
	invalid({"damage":"4"}, "damage")
	invalid({"hull":true}, "hull")
	invalid({"damage":INF}, "damage")
	invalid({"pierce":1.1}, "pierce")
	invalid({"swap_resource":"fuel"}, "swap_resource")
	invalid({"swap_shields":1}, "swap_shields")
	invalid({"drain":{"fuel":3}}, "drain.fuel")
	invalid({"steal":{"energy":"3"}}, "steal.energy")
	invalid({"enemy_production":{"engine":-1}}, "enemy_production.engine")
	invalid({"production_other":{"type":"engine","production":1,"resource":2}}, "production_other.type")
	invalid({"production_other":{"type":"reactor"}}, "production_other.resource")
	invalid({"random_gain_range_other":{"min":8,"max":4}}, "random_gain_range_other.max")
	invalid({"random_gain_range_other":{"min":1}}, "random_gain_range_other.max")
	invalid({"shield_collapse":{"threshold":10,"chance":-0.1,"self_damage":4}}, "shield_collapse.chance")
	invalid({"shield_collapse":{}}, "shield_collapse.threshold")
	invalid({"conditional":4}, "conditional")
	invalid({"conditional":{"target":"both"}}, "conditional.target")
	invalid({"conditional":{"attribute":"fuel"}}, "conditional.attribute")
	invalid({"conditional":{"comparison":"less"}}, "conditional.comparison")
	invalid({"conditional":{"then":5}}, "conditional.then")
	invalid({"conditional":{"else":{"damage":"bad"}}}, "conditional.else.damage")
	invalid({"conditional":{"then":{"conditional":{"then":{"damage":"bad"}}}}}, "conditional.then.conditional.then.damage")
	invalid({"conditional":{"fraction_of":"hull_capacity"}}, "conditional.threshold")
	invalid({"conditional":{"fraction_of":"hull_capacity","threshold":NAN}}, "conditional.threshold")
	invalid({"conditional":{"compare_target":"enemy"}}, "conditional.compare_attribute")
	invalid({"conditional":{"typo":0}}, "conditional.typo")
	invalid_card("family", "fuel", ".family")
	invalid_card("allocation_category", "utility", ".allocation_category")
	invalid_card("tier", 4, ".tier")
	invalid_card("cost", -1, ".cost")
	invalid_card("card_name", "", ".identity")
	invalid_card("max_upgrades", 3, ".max_upgrades")
	invalid_card("upgrade_level", 1, ".upgrade_level")
	var disabled = valid_card()
	disabled.upgrade_effects.assign([{"hull":1}, {"hull":2}])
	check(Contract.card(disabled).is_empty(), "Authored upgrades may be disabled by max_upgrades")
	var excess = valid_card()
	excess.upgrade_effects.assign([{}, {}, {}])
	malformed += 1
	check(Contract.card(excess).any(func(line): return line.contains("at most two")), "Third upgrade rejected")
	var broken = valid_card()
	broken.max_upgrades = 1
	broken.upgrade_effects.assign([{"conditional":{"then":{"damage":"bad"}}}])
	malformed += 1
	check(Contract.card(broken).any(func(line): return line.contains("Contract fixture — Upgrade I.conditional.then.damage: expected finite numeric value, received String")), "Upgrade diagnostic includes card, level and nested field")
	malformed += 1
	check(Contract.library([Cards.CARDS[0], Cards.CARDS[0]]).any(func(line): return line.contains("duplicate registered identity")), "Duplicate registration rejected")
	var cycle: Dictionary = {}
	cycle.conditional = {"then":cycle}
	malformed += 1
	check(Contract.effects(cycle).any(func(line): return line.contains("acyclic")), "Cycles rejected without an arbitrary depth limit")
	cycle.clear()
	var deep: Dictionary = {"hull":1}
	for index in range(64): deep = {"conditional":{"then":deep}}
	check(Contract.effects(deep).is_empty(), "Deep valid branches accepted")
	for value in [{"conditional":{}}, {"sabotage":true}, {"sabotage":false}, {"hull":-2.5}, {"pierce":0.5}, {"conditional":{"threshold":2.0,"fraction_of":"hull_capacity","compare_attribute":"hull"}}, {"random_gain_range_other":{"min":-2,"max":-1}}]:
		check(Contract.effects(value).is_empty(), "Existing defaults, signed numerics and precedence accepted")
	for base in Cards.CARDS:
		var before: Array = [base.effects.duplicate(true), base.upgrade_effects.duplicate(true), base.upgrade_level, base.identity_key()]
		for level in range(base.max_upgrades + 1):
			var copy: Resource = base.with_upgrade(level)
			check(copy.identity_key() == base.identity_key() and copy.upgrade_level == level, "Stable upgrade identity/level")
			check(copy.cost == base.cost and copy.family == base.family and copy.tier == base.tier and copy.allocation_category == base.allocation_category and copy.play_again == base.play_again, "Upgrade preserves card-level contract")
			check(copy.effects == (base.effects if level == 0 else base.upgrade_effects[level - 1]), "Upgrade replaces complete effect dictionary")
		check(before == [base.effects, base.upgrade_effects, base.upgrade_level, base.identity_key()], "Validation/upgrade inspection leaves definitions unchanged")
	consumer_cases()
	print("Card effect contract: %d cards, %d upgrade definitions, %d malformed fixtures; %d checks, %d failures" % [Cards.CARDS.size(), Cards.CARDS.reduce(func(total, card): return total + card.upgrade_effects.size(), 0), malformed, checks, failures])
	quit(1 if failures else 0)

func consumer_cases() -> void:
	# Each supported key has an executable fixture and a meaningful target expectation.
	# Companion keys belong in the SAME dictionary (e.g. pierce modifies damage).
	var samples: Dictionary = {
		"hull":[{"hull":2},"player_hull"], "shields":[{"shields":2},"player_shields"],
		"materials":[{"materials":2},"player_materials"], "energy":[{"energy":2},"player_energy"], "crew":[{"crew":2},"player_crew"],
		"synthesizer":[{"synthesizer":1},"player_synthesizer"], "reactor":[{"reactor":1},"player_reactor"], "quarters":[{"quarters":1},"player_quarters"],
		"damage":[{"damage":20},"enemy_hull"], "pierce":[{"damage":20,"pierce":1.0},"enemy_hull"],
		"break_shields":[{"break_shields":3},"enemy_shields"], "shield_collapse_below":[{"shield_collapse_below":20},"enemy_shields"],
		"self_damage":[{"self_damage":2},"player_hull"], "self_damage_regular":[{"self_damage_regular":2},"player_shields"],
		"random_gain":[{"random_gain":2},"player_energy"], "random_gain_other":[{"random_gain_other":2},"player_energy"],
		"random_gain_range_other":[{"random_gain_range_other":{"min":1,"max":3}},"player_energy"],
		"random_sabotage":[{"random_sabotage":1},"enemy_reactor"], "sabotage":[{"sabotage":true},"enemy_reactor"],
		"swap_shields":[{"swap_shields":true},"player_shields"], "swap_resource":[{"swap_resource":"energy"},"player_energy"],
		"drain":[{"drain":{"energy":2}},"enemy_energy"], "steal":[{"steal":{"energy":2}},"player_energy"],
		"enemy_production":[{"enemy_production":{"reactor":-1}},"enemy_reactor"],
		"production_other":[{"production_other":{"type":"reactor","production":1,"resource":2}},"player_reactor"],
		"shield_collapse":[{"shield_collapse":{"threshold":1,"chance":0.5,"self_damage":3}},"enemy_shields"],
		"conditional":[{"conditional":{"comparison":"above","then":{"conditional":{"comparison":"above","then":{"hull":1}}}}},"player_hull"],
	}
	check(same_keys(samples, Contract.FORMS), "Every key requires executable consumer coverage")
	for key in samples:
		var card = valid_card()
		card.effects = samples[key][0]
		var actor: Dictionary = Ship.new().snapshot()
		var enemy: Dictionary = Ship.new().snapshot()
		enemy.shields = 12
		enemy.energy = 2
		var before: Array = [actor.duplicate(true),enemy.duplicate(true),card.effects.duplicate(true)]
		var rng_before: int = Effects.combat_rng.state
		check(Contract.card(card).is_empty(), "Valid consumer fixture: " + key)
		check(not Data.describe_effects(card.effects).is_empty(), "Description: " + key)
		check(not Text.comparison(card,valid_card()).is_empty(), "Upgrade inspection: " + key)
		var preview: Dictionary = Targets.analyze(card,{"player":actor,"enemy":enemy})
		check(preview.has(samples[key][1]), "Tactical target: " + key)
		if key.begins_with("random_"): check("uncertain" in preview[samples[key][1]], "Uncertain random preview: " + key)
		var ai = AI.new()
		ai.rng.seed = 42
		check(not ai.choose([card],actor,enemy).is_empty(), "AI simulation: " + key)
		ai.free()
		check(before == [actor,enemy,card.effects] and rng_before == Effects.combat_rng.state, "Read-only consumers: " + key)
		for mode in [0, 2, 3, 4]:
			var modifier = Modifier.new()
			modifier.configure(mode,42)
			modifier.active = true
			modifier.ion_factor = 0.5
			modifier.play(card,actor.duplicate(true),enemy.duplicate(true))
			modifier.free()
		check(before == [actor,enemy,card.effects], "Modifier preserves definitions: " + key)
