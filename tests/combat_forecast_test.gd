extends SceneTree
const Forecast = preload("res://scripts/combat/combat_forecast.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Data = preload("res://scripts/cards/card_data.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
const AI = preload("res://scripts/enemy_ai.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func ship() -> Dictionary:
	var value: Dictionary = Ship.new().snapshot()
	for key in Ship.RESOURCES: value[key] = 40
	return value
func contains(forecast: Dictionary, actor: Dictionary, target: Dictionary, report: Dictionary) -> bool:
	return forecast.outcomes.any(func(item): return item.actor == actor and item.target == target and item.damage == report)
func sample(effects: Dictionary) -> Resource:
	var card = Data.new()
	card.effects = effects
	return card
func _initialize() -> void:
	var ai = AI.new()
	ai.rng.seed = 123
	var ai_rng: int = ai.rng.state
	var combat_rng: int = Effects.combat_rng.state
	var actor: Dictionary = ship()
	actor.hull = 17
	actor.shields = 5
	actor.systems_failure_remaining = 1
	var enemy: Dictionary = ship()
	enemy.shields = 12
	enemy.hull = 22
	var modifier = Modifier.new()
	var combinations: int = 0
	for base in Cards.CARDS:
		for level in range(3):
			var card: Resource = base if level == 0 else base.with_upgrade(level)
			for mode in range(7):
				modifier.configure([0,1,2,2,3,4,5][mode],123)
				modifier.active = true
				modifier.ion_factor = 0.5 if mode == 2 else 2.0
				var context: Dictionary = modifier.forecast_context()
				var before: Array = [actor.duplicate(true),enemy.duplicate(true),card.effects.duplicate(true),card.description,context.duplicate(),modifier.rng.state,modifier.last_hull_damage.duplicate(true)]
				var prediction: Dictionary = Forecast.predict(card,actor,enemy,context)
				check(prediction.affordable and prediction.complete,"All authored cards fit enumeration budget")
				check(prediction == Forecast.predict(card,actor,enemy,context),"Deterministic repeated forecast")
				check(before == [actor,enemy,card.effects,card.description,context,modifier.rng.state,modifier.last_hull_damage],"Forecast leaves inputs and modifier untouched")
				for roll in [0.0,1.0]:
					var a: Dictionary = actor.duplicate(true)
					var b: Dictionary = enemy.duplicate(true)
					modifier.rng.seed = 123
					modifier.play(card,a,b,roll)
					check(contains(prediction,a,b,modifier.last_hull_damage),"Authoritative result represented: %s level %d mode %d" % [card.card_name,level,mode])
				if not prediction.uncertain: check(prediction.outcomes.size() == 1,"Deterministic forecast has one exact outcome")
				if mode == 4:
					for outcome in prediction.outcomes: check(outcome.actor.shields == actor.shields and outcome.target.shields == enemy.shields,"Flare retains stored Shields")
				prediction.outcomes[0].actor.hull = -999
				check(actor.hull == 17,"Returned outcomes cannot mutate source")
				combinations += 1
	check(Effects.combat_rng.state == combat_rng and ai.rng.state == ai_rng,"No live combat or AI RNG consumed")
	modifier.free()
	ai.free()
	uncertainty_cases()
	print("Combat forecast: %d card/upgrade/modifier combinations; %d checks, %d failures" % [combinations,checks,failures])
	quit(1 if failures else 0)
func uncertainty_cases() -> void:
	var a: Dictionary = ship()
	var b: Dictionary = ship()
	var f: Dictionary = Forecast.predict(sample({"shield_collapse_below":11}),a,b)
	check(f.complete and f.outcomes[0].target.shields == 0,"Strict-below clear, supported but not currently authored")
	f = Forecast.predict(sample({"random_sabotage":1}),a,b)
	check(f.complete and f.outcomes.size() == 3 and f.uncertain,"Three sabotage targets")
	f = Forecast.predict(sample({"random_gain":2}),a,b)
	check(f.complete and f.outcomes.size() == 3,"Three resource targets")
	f = Forecast.predict(sample({"random_gain_range_other":{"min":1,"max":3}}),a,b)
	check(f.complete and f.outcomes.size() == 6,"Other-resource target and amount alternatives")
	f = Forecast.predict(sample({"random_gain_range_other":{"min":1,"max":1},"random_sabotage":1}),a,b)
	check(f.complete and f.outcomes.size() == 6,"Forced range draw does not hide later forks")
	f = Forecast.predict(sample({"random_gain":1,"conditional":{"attribute":"energy","comparison":"above","threshold":40,"then":{"damage":50},"else":{"conditional":{"then":{"hull":2}}}}}),a,b)
	check(f.complete and f.possible_win and not f.guaranteed_win,"Random precursor selects real conditional branches")
	a.hull = 4
	a.shields = 0
	f = Forecast.predict(Cards.CARDS[40],a,b)
	check(f.complete and f.possible_self_destruction and not f.guaranteed_self_destruction,"Collapse risk distinguished from guaranteed death")
	f = Forecast.predict(sample({"damage":100,"self_damage":1}),a,b,{"kind":4,"miss_rate":30})
	check(f.possible_win and not f.guaranteed_win and f.outcomes.size() == 2,"Nebula hit is possible, not guaranteed")
	for item in f.outcomes:
		check(item.actor.hull == 3,"Nebula miss retains direct self-damage")
	f = Forecast.predict(sample({"random_gain_range_other":{"min":1,"max":10000},"conditional":{"then":{"damage":50}}}),a,b)
	check(not f.complete and f.uncertain and not f.guaranteed_win and not f.guaranteed_self_destruction and f.replays <= Forecast.MAX_REPLAYS,"Bounded approximation never promises guarantees")
	var unaffordable = sample({"damage":100})
	unaffordable.cost = 999
	f = Forecast.predict(unaffordable,a,b)
	check(not f.affordable and f.outcomes.is_empty(),"Unaffordable card never spends or resolves")
	# Measured rather than asserted timing: environment speed is not gameplay correctness.
	var started: int = Time.get_ticks_usec()
	for repeat in range(100):
		for index in [11,40,42,18,55,61]: Forecast.predict(Cards.CARDS[index],a,b,{"kind":2,"active":true,"ion_factor":0.5})
	print("Forecast timing: 100 six-card hands = %.2f ms" % ((Time.get_ticks_usec()-started)/1000.0))
