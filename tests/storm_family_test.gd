extends SceneTree
const Mod = preload("res://scripts/combat_modifier.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Data = preload("res://scripts/cards/card_data.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
const Forecast = preload("res://scripts/combat/combat_forecast.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
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
func _initialize() -> void:
	check(Mod.NAMES.slice(0,6) == ["None","Asteroid belt","Ion storm","Solar flare","Nebula","Temporal Rift"],"Original IDs unchanged")
	check(Mod.NAMES.size() == 8 and Mod.storm_family(6) == "materials" and Mod.storm_family(7) == "crew","Appended IDs and families")
	for seed_value in range(32):
		var storms: Array = []
		for kind in [2,6,7]:
			var mod = Mod.new()
			mod.configure(kind,seed_value)
			storms.append(mod)
		for round_number in range(1,31):
			var reference: Array = []
			for mod in storms:
				var rng_before: int = mod.rng.state
				var stable: bool = mod.active and round_number < mod.ends_round
				var factor: float = mod.ion_factor
				mod.begin_round(round_number)
				var values: Array = [mod.active,mod.ion_factor,mod.next_round,mod.ends_round,mod.rng.state]
				if reference.is_empty(): reference = values
				check(values == reference,"Storm schedule, factor and RNG exactly match Ion")
				if stable: check(mod.rng.state == rng_before and mod.ion_factor == factor,"Active storm does not reroll")
				if mod.active: check(mod.ends_round - round_number in [1,2,3],"Three complete rounds")
		for mod in storms: mod.free()
	var cases: int = 0
	for kind in [2,6,7]:
		for factor in [0.5,2.0]:
			for base in Cards.CARDS:
				for level in range(3):
					var card: Resource = base if level == 0 else base.with_upgrade(level)
					var before: Array = [card.effects.duplicate(true),card.description,card.cost,card.play_again]
					var mod = Mod.new()
					mod.configure(kind,77)
					mod.active = true
					mod.ion_factor = factor
					var shown: Resource = mod.preview(card)
					var matches: bool = card.family == Mod.storm_family(kind)
					check(shown.effects == (Mod._scaled(card.effects,factor) if matches else card.effects),"Only matching family preview scales")
					check(shown.cost == card.cost and shown.play_again == card.play_again,"Payment and extra action unchanged")
					var a: Dictionary = ship()
					var b: Dictionary = ship()
					var forecast: Dictionary = Forecast.predict(card,a,b,mod.forecast_context())
					check(forecast.complete,"All authored storm forecasts are complete")
					mod.play(card,a,b)
					check(forecast.outcomes.any(func(item):return item.actor == a and item.target == b and item.damage == mod.last_hull_damage),"Forecast includes actual scaled outcome")
					if not matches:
						var normal = Mod.new()
						normal.configure(0,77)
						var x: Dictionary = ship()
						var y: Dictionary = ship()
						normal.play(card,x,y)
						check([a,b,mod.rng.state] == [x,y,normal.rng.state],"Other families do not change resolution or RNG")
						normal.free()
					check(before == [card.effects,card.description,card.cost,card.play_again],"Shared definitions never mutate")
					mod.active = false
					check(mod.preview(card) == card,"Inactive storm leaves all cards alone")
					mod.free()
					cases += 1
	equivalent_fixtures()
	persistence_and_distribution()
	print("Storm family: %d authored card/upgrade/factor/storm cases; %d checks, %d failures" % [cases,checks,failures])
	quit(1 if failures else 0)
func equivalent_fixtures() -> void:
	var values: Dictionary = {"hull":3,"shields":5,"damage":7,"pierce":0.5,"materials":3,"energy":3,"crew":3,"synthesizer":1,"reactor":1,"quarters":1,"sabotage":true,"steal":{"materials":2,"energy":2,"crew":2},"random_gain":3,"conditional":{"attribute":"hull","comparison":"above","threshold":1,"then":{"damage":3}}}
	check(Mod._scaled({"crew":-3,"pierce":0.5,"shield_collapse_below":10,"conditional":{"threshold":10,"then":{"damage":7}},"shield_collapse":{"threshold":10,"chance":0.5,"self_damage":7},"sabotage":true},0.5) == {"crew":-2,"pierce":0.5,"shield_collapse_below":10,"conditional":{"threshold":10,"then":{"damage":3}},"shield_collapse":{"threshold":10,"chance":0.5,"self_damage":3},"sabotage":0},"Exact floor, recursion and excluded-field semantics")
	for factor in [0.5,2.0]:
		var reference: Array = []
		for kind in [2,6,7]:
			var card = Data.new()
			card.family = Mod.storm_family(kind)
			card.cost = 2
			card.play_again = true
			card.effects = values.duplicate(true)
			var mod = Mod.new()
			mod.configure(kind,321)
			mod.active = true
			mod.ion_factor = factor
			var a: Dictionary = ship()
			var b: Dictionary = ship()
			mod.play(card,a,b)
			a[card.family] += card.cost # Normalize only the different payment slot.
			var result: Array = [a,b,mod.last_hull_damage,mod.rng.state]
			if reference.is_empty(): reference = result
			check(result == reference,"Equivalent Energy/Materials/Crew fixture, same seeded draws")
			var swapped = Mod.new()
			swapped.configure(kind,321)
			swapped.active = true
			swapped.ion_factor = factor
			var player: Dictionary = ship()
			var enemy: Dictionary = ship()
			swapped.play(card,enemy,player)
			enemy[card.family] += card.cost
			check([enemy,player,swapped.last_hull_damage,swapped.rng.state] == result,"Player/enemy roles share the same storm")
			swapped.configure(kind,321)
			var inactive_a: Dictionary = ship()
			var inactive_b: Dictionary = ship()
			swapped.play(card,inactive_a,inactive_b)
			var normal = Mod.new()
			normal.configure(0,321)
			var normal_a: Dictionary = ship()
			var normal_b: Dictionary = ship()
			normal.play(card,normal_a,normal_b)
			check([inactive_a,inactive_b,swapped.rng.state] == [normal_a,normal_b,normal.rng.state],"Inactive matching-family storm has no gameplay/RNG effect")
			normal.free()
			swapped.free()
			var ai = AI.new()
			var dying: Dictionary = ship()
			dying.hull = 4
			dying.shields = 0
			var risky = Data.new()
			risky.family = card.family
			risky.effects = {"self_damage":3}
			var safe = Data.new()
			safe.family = card.family
			safe.effects = {"hull":1}
			if factor == 2.0: check(ai.choose([risky,safe],dying,ship(),mod.forecast_context()).slot == 1,"Shared AI safety sees doubled self-damage for every family")
			ai.free()
			mod.free()
func persistence_and_distribution() -> void:
	var rng = RandomNumberGenerator.new()
	var expected = RandomNumberGenerator.new()
	rng.seed = 31415
	expected.seed = 31415
	var seen: Dictionary = {}
	for i in range(1000):
		var value: int = Mod.roll_encounter(rng)
		seen[value] = true
		check(value == expected.randi_range(0,7) and rng.state == expected.state,"Exactly one current uniform selection call")
	check(seen.size() == 8,"All eight IDs reachable")
	var state = State.new()
	state.start(0,Rules,123)
	for kind in range(8):
		var slot: int = -1
		for i in range(state.encounters.size()):
			if state.encounters[i].kind == "battle": slot = i; break
		check(slot >= 0,"Generated battle for save fixture")
		state.encounters[slot].modifier = kind
		var loaded = Save.new().decode(Save.encode(state),Rules)
		check(loaded != null and loaded.encounters[slot].modifier == kind,"Version-1 saves preserve every old/new ID")
	# The live eight-way system is deterministic across generation and resume.
	var a = State.new()
	var b = State.new()
	a.start(1,Rules,88441)
	b.start(1,Rules,88441)
	for i in range(12):
		check(Save.encode(a) == Save.encode(b),"Eight-way expedition seed/resume parity")
		a.generate_system()
		b = Save.new().decode(Save.encode(b),Rules)
		b.generate_system()
