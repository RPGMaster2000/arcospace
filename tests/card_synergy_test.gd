extends SceneTree

const Cards = preload("res://scripts/cards/card_library.gd")
const Deck = preload("res://scripts/expedition/expedition_deck.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Forecast = preload("res://scripts/combat/combat_forecast.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
const Hand = preload("res://scripts/cards/card_hand.gd")
const AI = preload("res://scripts/enemy_ai.gd")

var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func ship() -> Dictionary:
	return {"hull":39, "hull_capacity":80, "shields":6, "materials":80, "energy":80,
		"crew":80, "synthesizer":4, "reactor":4, "quarters":4}


func catalogue() -> void:
	var distribution := {2: {"materials":0, "energy":0, "crew":0}, 3: {"materials":0, "energy":0, "crew":0}}
	# One independent primary outcome for every card at each of its three levels.
	var cases := [
		["energy", 89, 1], ["energy", 86, 1], ["hull", 47, 2], ["hull", 28, -2],
		["crew", 84, 1], ["shields", 11, 1], ["hull", 23, -3], ["materials", 87, 1],
		["shields", 0, 0], ["materials", 88, 2], ["energy", 72, -2], ["materials", 88, 2],
		["hull", 32, -2], ["reactor", 3, 0], ["hull", 49, 2], ["materials", 88, 2],
		["hull", 31, -2], ["crew", 70, -2], ["energy", 96, 2], ["shields", 28, 3],
		["hull", 22, -3], ["materials", 90, 2], ["hull", 15, -3], ["materials", 96, 2],
		["hull", 27, -3], ["reactor", 5, 0], ["hull", 57, 3],
	]
	var opponent_cases := [3, 6, 10, 12, 13, 16, 17, 20, 22, 24]
	var offensive_exposure := [3, 6, 20, 22]
	for index in Cards.SYNERGY_CARDS.size():
		var base: Resource = Cards.SYNERGY_CARDS[index]
		distribution[base.tier][base.family] += 1
		check(base.max_upgrades == 2 and not base.play_again, "Two upgrades and one action for " + base.card_name)
		for profile in Ships.PLAYERS:
			check(base not in profile.starting_cards, "Excluded from ship openings")
		for level in range(3):
			var card: Resource = base.with_upgrade(level)
			var actor := ship()
			var target := ship()
			# The attack cases exercise exact shield boundaries and pre-/post-hit checks.
			if index in offensive_exposure: target.shields = {3:5, 6:0, 20:5, 22:0}[index]
			if index in [7, 21]: target.shields = 5
			var expected: Array = cases[index]
			var forecast := Forecast.predict(card, actor, target)
			check(Effects.play(card, actor, target), "Legal variant resolves " + card.card_name)
			var observed: Dictionary = target if index in opponent_cases else actor
			check(observed[expected[0]] == expected[1] + level * expected[2], "Specified outcome for " + card.card_name)
			check(forecast.outcomes.size() == 1 and forecast.outcomes[0].actor == actor
				and forecast.outcomes[0].target == target, "Runtime and forecast agree for " + card.card_name)
	check(distribution == {2:{"materials":6,"energy":6,"crew":6}, 3:{"materials":3,"energy":3,"crew":3}}, "Family and rarity distribution")


func timing() -> void:
	for level in range(3):
		var actor := ship()
		var target := ship()
		var execution: Resource = Cards.SYNERGY_CARDS[6].with_upgrade(level)
		target.shields = 10 + 2 * level
		check(Effects.play(execution, actor, target) and target.shields == 0 and target.hull == 33 - level,
			"Execution Beam follows exactly enough damage to clear Shields")
		actor = ship()
		target = ship()
		target.shields = 11 + 2 * level
		check(Effects.play(execution, actor, target) and target.shields == 1 and target.hull == 39,
			"Execution Beam grants no follow-up if Shields survive")
		var dividend: Resource = Cards.SYNERGY_CARDS[7].with_upgrade(level)
		actor = ship()
		target = ship()
		check(Effects.play(dividend, actor, target) and actor.materials == 80, "Tied Shields grant no dividend")
		actor = ship()
		actor.hull = 40
		var foundry: Resource = Cards.SYNERGY_CARDS[1].with_upgrade(level)
		check(Effects.play(foundry, actor, target) and actor.energy == 80, "Exactly half Hull is outside recovery threshold")
		actor = ship()
		actor.reactor = 3
		var cascade: Resource = Cards.SYNERGY_CARDS[9].with_upgrade(level)
		check(Effects.play(cascade, actor, target) and actor.reactor == 4 and actor.shields == 11 + 2 * level
			and actor.materials == 80, "Reactor Cascade tests production before the increase")
		actor = ship()
		actor.shields = 5
		var capacitor: Resource = Cards.SYNERGY_CARDS[8].with_upgrade(level)
		var before := actor.duplicate()
		check(not Effects.play(capacitor, actor, target) and actor == before, "Sacrifice fails atomically")
		var ai := AI.new()
		check(ai.choose([capacitor], actor, target).discard, "AI cannot bypass Shield payment")
		target.hull = 1
		target.shields = 10 + 2 * level
		check(ai.choose([Cards.SYNERGY_CARDS[7], execution], actor, target).slot == 1, "AI recognizes post-Shield lethal")
		ai.free()
		actor = ship()
		target = ship()
		target.materials = 0
		target.energy = 2
		target.crew = 1
		var infiltration: Resource = Cards.SYNERGY_CARDS[24].with_upgrade(level)
		check(Effects.play(infiltration, actor, target) and actor.materials == 80 and actor.energy == 82
			and actor.crew == 59 and target.energy == 0 and target.crew == 0, "Theft is bounded by reserves")
		for kind in range(Modifier.NAMES.size()):
			var modifier := Modifier.new()
			modifier.configure(kind, 49101)
			modifier.active = kind in [2, 3, 6, 7]
			var context: Dictionary = modifier.forecast_context()
			var ready := ship()
			var enemy := ship()
			var prediction := Forecast.predict(execution, ready, enemy, context)
			var generator := RandomNumberGenerator.new()
			generator.seed = 8128
			Modifier.resolve_effects(execution, ready, enemy, context, generator, {})
			check(prediction.outcomes.any(func(row): return row.actor == ready and row.target == enemy),
				"Forecast covers runtime for modifier " + Modifier.NAMES[kind])
			modifier.free()


func alternative_branches() -> void:
	# Each fixture holds other state fixed and changes only the branch predicate.
	var fixtures := [
		[2, {"synthesizer":3}, {}, {"crew":[80,80,80]}, {}],
		[3, {}, {"shields":25}, {"energy":[83,84,85]}, {"shields":[15,13,11], "hull":[39,39,39]}],
		[4, {"synthesizer":3}, {}, {"crew":[80,80,80], "quarters":[5,5,5]}, {}],
		[5, {"reactor":3}, {}, {"energy":[87,88,89], "shields":[6,6,6]}, {}],
		[10, {}, {"reactor":3}, {"crew":[84,85,86]}, {"energy":[80,80,80]}],
		[11, {"crew":14}, {"crew":15}, {"crew":[24,26,28], "materials":[84,85,86]}, {}],
		[13, {}, {"reactor":2}, {"energy":[80,80,80], "shields":[11,12,13]}, {"energy":[72,70,68], "reactor":[2,2,2]}],
		[14, {"hull":40}, {}, {"hull":[40,40,40], "shields":[14,16,18]}, {}],
		[15, {"quarters":3}, {}, {"quarters":[4,4,4], "materials":[84,85,86], "energy":[84,85,86]}, {}],
		[16, {}, {"shields":10}, {"energy":[85,86,87]}, {"shields":[0,0,0], "hull":[39,39,39]}],
		[17, {}, {"crew":14}, {"hull":[45,47,49], "materials":[86,87,88]}, {"crew":[14,14,14]}],
		[19, {"hull":40}, {}, {"hull":[50,52,54], "shields":[22,25,28]}, {}],
		[20, {}, {"shields":20}, {"crew":[80,80,80]}, {"hull":[34,29,26], "shields":[0,0,0]}],
		[21, {}, {}, {"materials":[80,80,80], "shields":[24,28,32]}, {}],
		[22, {}, {"shields":30}, {"crew":[80,80,80]}, {"hull":[39,34,29], "shields":[0,0,0]}],
		[23, {"reactor":3}, {}, {"reactor":[4,4,4], "materials":[88,90,92], "crew":[88,90,92]}, {}],
		[25, {"synthesizer":3}, {}, {"synthesizer":[4,4,4], "reactor":[4,4,4]}, {}],
		[26, {"hull":40}, {}, {"hull":[40,40,40], "shields":[16,18,20]}, {"hull":[35,33,31]}],
	]
	for fixture in fixtures:
		for level in range(3):
			var card: Resource = Cards.SYNERGY_CARDS[fixture[0]].with_upgrade(level)
			var actor := ship()
			var target := ship()
			actor.merge(fixture[1], true)
			target.merge(fixture[2], true)
			var prediction := Forecast.predict(card, actor, target)
			check(Effects.play(card, actor, target), "Alternative branch resolves for " + card.card_name)
			for side in [0, 1]:
				var observed: Dictionary = [actor, target][side]
				var expected: Dictionary = fixture[side + 3]
				for key in expected:
					check(observed[key] == expected[key][level], card.card_name + " alternative branch " + key)
			check(prediction.outcomes.size() == 1 and prediction.outcomes[0].actor == actor
				and prediction.outcomes[0].target == target, "Alternative branch forecast agrees")


func progression() -> void:
	var hand := Hand.new()
	hand.card_pool.assign([Cards.BASE_CARDS[0], Cards.SYNERGY_CARDS[0], Cards.SYNERGY_CARDS[18]])
	hand.rng.seed = 11421
	for round_index in [2, 3, 5, 6]:
		hand.current_round = round_index
		var counts := [0, 0, 0, 0]
		for draw in 12000:
			counts[hand.draw_card().tier] += 1
		check((counts[2] == 0 if round_index < 3 else absi(counts[2] - 1800) < 160), "Tier 2 at 15% starting round three")
		check((counts[3] == 0 if round_index < 6 else absi(counts[3] - 600) < 110), "Tier 3 at 5% starting round six")
	hand.cards.assign([Cards.SYNERGY_CARDS[0], Cards.SYNERGY_CARDS[18]])
	for draw in 200:
		check(hand.draw_card().tier == 1, "Occupied rarities fall back to Tier 1")
	check(hand._eligible(Cards.SYNERGY_CARDS[18], 1) and hand._eligible(Cards.SYNERGY_CARDS[0], 0),
		"Independent rarity caps permit both tiers in one hand")
	hand.cards.clear()
	hand.card_pool.append(Cards.SYNERGY_CARDS[19])
	hand.tier_two_chance = 0.0
	hand.tier_three_chance = 1.0
	hand.identity_weights[Cards.SYNERGY_CARDS[19].identity_key()] = Rules.acquired_card_draw_weight
	var weighted := 0
	for draw in 6000:
		weighted += int(hand.draw_card() == Cards.SYNERGY_CARDS[19])
	check(absi(weighted - 4500) < 160, "Owned Tier 3 weight applies within Tier 3")
	hand.free()
	var deck := Deck.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44494
	for rare in [false, true]:
		var offers := deck.random_card_offers(Ships.PLAYERS[0], Rules, rng, 1, rare)
		check(offers.size() == 5 and offers.filter(func(card): return card.tier == 3).size() == int(rare),
			"Ordinary and rare drafts have five distinct slots")
	var ordinary: Resource = preload("res://ships/enemy/sentinel.tres")
	var elite: Resource = preload("res://ships/enemy/marauder_vanguard.tres")
	for scenario in [[ordinary, 1, 0, 0], [ordinary, 2, 0, 0], [ordinary, 3, 6, 0],
		[ordinary, 5, 6, 2], [elite, 3, 6, 3]]:
		var pool := Deck.enemy_pool(scenario[0], scenario[1], true)
		var additions := pool.filter(func(card): return card in Cards.SYNERGY_CARDS)
		check(additions.filter(func(card): return card.tier == 2).size() == scenario[2]
			and additions.filter(func(card): return card.tier == 3).size() == scenario[3], "Enemy stage/rank eligibility")
		for card in scenario[0].starting_cards:
			check(card in pool, "Authored faction card survives")
	var custom := elite.duplicate()
	custom.starting_cards.assign([Cards.BASE_CARDS[0], Cards.PROTOTYPES[4]])
	check(Deck.enemy_pool(custom, 10, false) == custom.starting_cards, "Explicit custom deck retained")


func shop_and_save() -> void:
	const State = preload("res://scripts/expedition_state.gd")
	const Save = preload("res://scripts/persistence/expedition_save.gd")
	var config := Rules.duplicate()
	config.game_mode = "exploration"
	config.log_rolls = false
	var expedition := State.new()
	expedition.start(0, config, 717)
	for attempt in range(20):
		if not expedition.service.is_empty(): break
		expedition.ftl_access = true
		expedition.generate_system()
	check(not expedition.service.is_empty(), "Deterministic fixture reaches a Trading Outpost")
	if expedition.service.is_empty(): return
	expedition.system_number = 2
	check(expedition.service_card_offers(2).all(func(card): return card.tier < 3), "No Tier 3 trading in System 2")
	expedition.system_number = 3
	var offers := expedition.service_card_offers(2)
	var index := offers.find_custom(func(card): return card.tier == 3)
	check(index >= 0 and offers.filter(func(card): return card.tier == 3).size() == 1, "One Tier 3 purchase from System 3")
	if index < 0: return
	var price := expedition.service_card_cost(2, offers[index])
	check(price == 25 and expedition.service_card_cost(2, offers[0]) == 15, "Per-card prices retain the normal price")
	var revision := expedition.service_revision
	expedition.salvage = 24
	check(not expedition.purchase_service(2, revision, 0, index) and expedition.salvage == 24
		and expedition.service_revision == revision, "Unaffordable Tier 3 does not spend or reroll")
	expedition.salvage = 25
	check(expedition.purchase_service(2, revision, 0, index) and expedition.salvage == 0, "Tier 3 purchase commits once")
	check(not expedition.purchase_service(2, revision, 0, index), "Stale confirmation cannot duplicate a purchase")
	var deck := Deck.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 49103
	expedition.card_offers = deck.random_card_offers(expedition.ship(), config, rng, 1, true)
	expedition.pending_choice = "card"
	var saved := Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(expedition))), config)
	check(saved != null and saved.card_offers == expedition.card_offers and offers[index] in saved.acquired_cards,
		"Pending rare offers and owned rare cards survive serialization")


func exceptional_discovery() -> void:
	const State = preload("res://scripts/expedition_state.gd")
	const Debris = preload("res://encounters/pirate_debris_field.tres")
	var config := Rules.duplicate()
	config.game_mode = "exploration"
	config.log_rolls = false
	for roll in [0.0, 0.99]:
		var expedition := State.new()
		expedition.start(0, config, 44494)
		expedition.encounters.assign([{"kind":"poi", "poi":Debris, "completed":false}])
		expedition.production_upgrades.quarters = 4
		var before: int = expedition.rng.state
		check(expedition.resolve_approach(0, 3, roll), "Boarding resolves exactly once")
		check(expedition.card_offers.filter(func(card): return card.tier == 3).size() == int(roll == 0.0),
			"Only successful exceptional boarding reserves a rare reward")
		check(expedition.rng.state == before, "A committed card draft leaves the system RNG untouched")


func _initialize() -> void:
	catalogue()
	timing()
	alternative_branches()
	progression()
	shop_and_save()
	exceptional_discovery()
	print("Synergy catalogue, timing, AI, and rarity: %d failures" % failures)
	quit(1 if failures else 0)
