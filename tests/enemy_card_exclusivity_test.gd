extends SceneTree

const Cards = preload("res://scripts/cards/card_library.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Expedition = preload("res://scripts/expedition_state.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Hand = preload("res://scripts/cards/card_hand.gd")
const State = preload("res://scripts/combat/ship_combat_state.gd")
const Execution = preload("res://scripts/combat/combat_execution.gd")
const EffectContract = preload("res://scripts/cards/card_effect_contract.gd")
const Brain = preload("res://scripts/enemy_ai.gd")
const Scenario = preload("res://tests/faction_balance_scenarios.gd")
const BATTERY = preload("res://tests/fixtures/faction_balance/iron_counterbattery.tres")
const PRODUCTION_BATTERY = preload("res://cards/enemy/iron_counterbattery.tres")
const LUNGE = preload("res://tests/fixtures/faction_balance/feeding_lunge.tres")
const PRIVATE = [BATTERY, PRODUCTION_BATTERY, LUNGE]
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, reason: String) -> void:
	if not ok:
		failures += 1
		push_error(reason)


func verifies_exclusion(pool: Array) -> bool:
	return pool.all(func(card): return card == null or PRIVATE.all(func(private): return private.identity_key() != card.identity_key()))


func run() -> void:
	check(verifies_exclusion(Cards.CARDS), "Enemy cards must stay out of the player catalog")
	check(PRODUCTION_BATTERY.effects == BATTERY.effects and PRODUCTION_BATTERY.cost == BATTERY.cost,
		"Production Counterbattery keeps the screened card's effects and cost")
	for index in Ships.PLAYERS.size():
		var expedition := Expedition.new()
		expedition.start(index, Rules, 4712)
		check(verifies_exclusion(expedition.ship().starting_cards), "Enemy card in a player starting deck")
		check(verifies_exclusion(expedition.player_pool()), "Enemy card in a player battle or replacement pool")
		check(verifies_exclusion(expedition.available_reward_cards()), "Enemy card in the reward catalog")
		check(verifies_exclusion(expedition.random_card_offers()), "Enemy card in generated acquisition choices")
		check(verifies_exclusion(expedition.shared_pool()), "Enemy card in the shared battle pool")
	var trade := Expedition.new()
	trade.start(0, Rules, 42)
	for attempt in 128:
		if not trade.service.is_empty():
			break
		for encounter in trade.encounters:
			if encounter.get("mandatory_boss", false):
				encounter.completed = true
		trade.ftl_access = true
		trade.generate_system()
	trade.salvage = 100
	var offers: Array = trade.service_card_offers(2)
	check(offers.size() == 6 and verifies_exclusion(offers), "No enemy exclusives in six shop offers")
	check(trade.purchase_service(2, trade.service_revision, 0, 0), "Selected shop card can be purchased")
	var hand := Hand.new()
	hand.rng.seed = 20
	hand.current_round = 12
	var draws: Array = []
	for index in 256:
		draws.append(hand.draw_card())
	check(verifies_exclusion(draws), "Enemy card from an empty-pool fallback draw")
	hand.free()
	for ship in Factions.ships(Rules):
		check(ship.starting_cards.has(PRODUCTION_BATTERY) == (ship.ship_name == "Siege Monitor"),
			"Counterbattery belongs only to Siege Monitor")
		check(not ship.starting_cards.has(BATTERY) and not ship.starting_cards.has(LUNGE),
			"Experimental resources must stay outside the live roster")
		if ship.ship_name in ["Siege Monitor", "Choir Guardian"]:
			var candidate: Resource = ship if ship.ship_name == "Siege Monitor" else Scenario.adjusted(ship, Scenario.ARMS["faction-prototypes"][ship.ship_name])
			var expedition := Expedition.new()
			expedition.start(0, Rules, 32)
			var setup := expedition.prepare_battle(-1, candidate)
			check(not verifies_exclusion(setup.enemy_cards) and verifies_exclusion(setup.player_cards),
				"Battle setup puts private identities only in the targeted enemy hand")
	for card in PRIVATE:
		check(EffectContract.card(card).is_empty(), "Card effects must satisfy the existing contract")
		var actor: Dictionary = State.new().snapshot()
		var target: Dictionary = State.new().snapshot()
		actor.hull_capacity = 20
		actor.hull = 10
		actor.shields = 8
		actor[card.family] = card.cost - 1
		target.hull = 30
		target.shields = 12
		check(not Execution.can_play(card, false, actor), "Reject payment one resource below cost")
		check(Execution.resolve(card, false, actor, target) == null, "Unaffordable effect must not resolve")
		actor[card.family] += 1
		var plain: Dictionary = actor.duplicate(true)
		var plain_target: Dictionary = target.duplicate(true)
		plain.hull = 11
		plain.shields = 7
		check(Execution.resolve(card, false, plain, plain_target) != null, "Resolve the card below its bonus conditions")
		check(Execution.resolve(card, false, actor, target) != null and actor[card.family] == 0, "Pay the exact cost once")
		if card != LUNGE:
			check(target.shields == 8 and target.hull == 26 and plain_target.shields == 8 and plain_target.hull == 30,
				"Counterbattery adds piercing damage only when the shooter has eight Shields")
		else:
			check(target.shields == 7 and target.hull == 30 and actor.hull == 13 and plain.hull == 11,
				"Lunge restores Hull only at or below the half-Hull threshold")
		actor[card.family] = card.cost
		actor.shields = 8
		target.hull = 4
		target.shields = 0
		var brain := Brain.new()
		brain.rng.seed = 1
		var move := brain.choose([card], actor, target)
		check(not move.is_empty() and not move.discard, "Enemy AI selects an affordable lethal exclusive attack")
		brain.free()
	print("Enemy card exclusivity: %d failures" % failures)
	quit(1 if failures else 0)
