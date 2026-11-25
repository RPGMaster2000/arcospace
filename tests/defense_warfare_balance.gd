extends "res://tests/six_ship_gameplay_simulation.gd"
## Paired combat audit with authoritative battle preparations and attainable draft progression.
const State = preload("res://scripts/expedition_state.gd")
const Deck = preload("res://scripts/expedition/expedition_deck.gd")
const Preferences = preload("res://scripts/cards/card_preferences.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const POLICIES := [
	["balanced", {"production":4.0, "resources":0.4}, {}],
	["offense", {"damage":2.2,"disruption":0.7}, {"energy":1.7}],
	["defense", {"hull":1.8,"shields":1.05,"damage":1.4}, {"materials":1.2}],
	["systems", {"production":5.7,"resources":0.5}, {"materials":1.6}],
	["defense", {"shields":1.30,"damage":1.45}, {"energy":1.5}],
	["offense", {"disruption":1.1,"damage":1.7}, {"crew":1.7}],
]


func run() -> void:
	var results := {}
	for stage in [3, 4, 5]:
		for rank in [0, 1, 2]:
			var group := {"matches":0,"later_wins":0,"baseline_wins":0,"later_rounds":0,
				"baseline_rounds":0,"tier2_plays":0,"tier3_plays":0,"by_ship":{}}
			for ship_index in Ships.PLAYERS.size():
				var profile: Resource = Ships.PLAYERS[ship_index]
				var wins := [0, 0]
				for trial in 8:
					var seed_value: int = 19851 + trial + rank * 781
					var state := make_run(ship_index, stage, seed_value, rank)
					if state == null:
						push_error("Audit did not select an eligible enemy rank")
						quit(2)
						return
					var index: int = state.defense.contact
					prepare_player(state, stage, seed_value, ship_index)
					var base: Resource = state.encounters[index].enemy_data
					var setup: RefCounted = state.prepare_battle(index)
					var role_profile: Resource = setup.enemy_profile
					var kind: int = [setup.modifier, 2, 3, 4, 5, 6, 7, 0][trial]
					var metrics := {}
					var policy: Array = POLICIES[ship_index]
					var config := {"battle_setup":setup,"allocation":policy[0],"weights":policy[1],
						"emp":false,"cards":{},"enemy_cards":metrics}
					var hostile := play_match(profile, role_profile, kind, seed_value, config)
					wins[0] += int(str(hostile.outcome).begins_with("win_"))
					setup.enemy_profile = Config.progression.scaled_enemy(base, stage, true)
					setup.enemy_state.configure_profile(setup.enemy_profile)
					setup.enemy_cards = Deck.enemy_pool(setup.enemy_profile, stage, true)
					setup.enemy_draw_rates = Vector2(0.15,0.05)
					config.cards = {}
					config.enemy_cards = {}
					var baseline := play_match(profile, setup.enemy_profile, kind, seed_value, config)
					wins[1] += int(str(baseline.outcome).begins_with("win_"))
					group.matches += 1
					group.later_rounds += hostile.rounds
					group.baseline_rounds += baseline.rounds
					for row in metrics.values():
						if row.tier in [2, 3]:
							group["tier%d_plays" % row.tier] += int(row.get("played", 0))
				group.later_wins += wins[0]
				group.baseline_wins += wins[1]
				group.by_ship[profile.ship_name] = wins
			results["%d/%d" % [stage, rank]] = group
			print("STARFRONT_COMBAT %d/%d %s" % [stage, rank, JSON.stringify(group)])
	quit()


func make_run(ship: int, stage: int, seed_value: int, rank: int) -> Resource:
	for offset in 24:
		var state := State.new()
		state.start(ship, Config, seed_value + offset, {"mode":"defense","stage":stage,"rank":-1})
		var candidates: Array = state.defense.units.filter(func(unit):
			return state.encounters[unit.encounter].enemy_data.enemy_rank == rank)
		if candidates.is_empty(): continue
		var unit: Dictionary = candidates.front()
		if unit.mothership:
			state.defense.revealed = true
		elif unit.reinforcement:
			unit.status = "active"
		state.defense.contact = unit.encounter
		return state
	return null


func prepare_player(state: Resource, stage: int, seed_value: int, ship_index: int) -> void:
	var deck := Deck.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value ^ 12373
	var families: Dictionary = POLICIES[ship_index][2]
	for slot in stage - 1:
		# Ordinary drafts are the default. A subset of System 5 runs has one earlier rare opportunity.
		var rare: bool = stage == 5 and slot == 0 and seed_value % 4 == 0
		var offers := deck.random_card_offers(state.ship(), Config, rng, 1, rare)
		var chosen: Resource = offers.back() if rare else offers.front()
		if not rare:
			for option in offers:
				if Preferences.draw_weight(option, families, {}) > Preferences.draw_weight(chosen, families, {}):
					chosen = option
		deck.acquired_cards.append(chosen)
		if slot < 2 and chosen.max_upgrades > 0:
			deck.upgraded_cards[chosen.identity_key()] = chosen.with_upgrade(1)
	state.acquired_cards = deck.acquired_cards
	state.upgraded_cards = deck.upgraded_cards
	if seed_value % 2 == 0:
		state.add_modifiers({"materials":5, "shields":4})
