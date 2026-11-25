extends "res://tests/six_ship_gameplay_simulation.gd"
# Run with --script tests/card_synergy_balance.gd -- OUTPUT [SHIP INDEX] [recovery_control]
const Deck = preload("res://scripts/expedition/expedition_deck.gd")
const Preparation = preload("res://scripts/combat/combat_preparation.gd")
const Setup = preload("res://scripts/combat/battle_setup.gd")
const ShipState = preload("res://scripts/combat/ship_combat_state.gd")
const MODES := ["baseline", "drafted", "specialized", "late_heavy"]
const AFFINITY := [
	[5, 11, 15, 23, 25], [3, 6, 10, 20, 22], [1, 2, 14, 19, 26],
	[0, 3, 4, 18, 20], [7, 8, 5, 21, 26], [12, 13, 16, 17, 24],
]
const OPPONENTS := [
	preload("res://ships/enemy/siege_monitor.tres"),
	preload("res://ships/enemy/marauder_vanguard.tres"),
	preload("res://ships/enemy/axiom_command_nexus.tres"),
	preload("res://ships/enemy/choir_leviathan.tres"),
]
const PRODUCTION := ["quarters", "reactor", "synthesizer", "synthesizer", "reactor", "quarters"]


func loadout(profile: Resource, index: int, mode: String, seed_value: int) -> RefCounted:
	var deck := Deck.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 6353
	for slot in range(5):
		if mode == "baseline":
			var existing: Array = deck.available_reward_cards(profile).filter(
				func(card): return card not in Cards.SYNERGY_CARDS and card.tier == (3 if slot == 4 else 2))
			deck.acquired_cards.append(existing[rng.randi_range(0, existing.size() - 1)])
		elif mode == "drafted":
			var draft := deck.random_card_offers(profile, Config, rng, 1, slot == 4)
			deck.acquired_cards.append(draft.back() if slot == 4 else draft.front())
		elif mode == "recovery_control" and slot >= 3:
			# Same Titania loadout, enemies and draw policy, with two pre-expansion rares.
			deck.acquired_cards.append(Cards.PROTOTYPES[6 if slot == 3 else 4])
		else:
			var selection: Array = AFFINITY[index].duplicate()
			if mode == "late_heavy":
				selection.assign(AFFINITY[index].slice(0, 2))
				for card_index in AFFINITY[index]:
					if card_index >= 18: selection.append(card_index)
				if selection.size() < 4: selection.append(25 if 25 not in selection else 18)
				for card_index in [18, 21, 24, 26]:
					if selection.size() == 5: break
					if card_index not in selection: selection.append(card_index)
			deck.acquired_cards.append(Cards.SYNERGY_CARDS[selection[slot]])
	for card in deck.acquired_cards:
		if card.tier >= 2 and card.max_upgrades > 0:
			deck.upgraded_cards[card.identity_key()] = card.with_upgrade(2 if mode == "late_heavy" else 1)
	return deck


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(2)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	var modes := MODES
	if args.size() >= 3:
		if args[1] != "2" or args[2] != "recovery_control":
			quit(2)
			return
		modes = ["recovery_control"]
	for index in Ships.PLAYERS.size():
		if args.size() > 1 and int(args[1]) != index: continue
		var player: Resource = Ships.PLAYERS[index]
		for mode in modes:
			var totals := {"wins":0, "rounds":0, "round6":0, "draw_by_8":0, "draw_by_10":0,
				"draw_by_15":0, "drawn2":0, "drawn3":0, "played2":0, "played3":0, "played3_battles":0,
				"held3":0, "affordable3":0, "held3_never_played":0, "hull":0, "shields":0,
				"production":0, "outcomes":{}, "cards":{}, "prepared":{"wins":0,"rounds":0},
				"unprepared":{"wins":0,"rounds":0}}
			for trial in 100:
				var seed_value := 50000 + trial
				var deck := loadout(player, index, mode, seed_value)
				var system := 8 if mode == "late_heavy" else 5
				var enemy: Resource = Config.progression.scaled_enemy(OPPONENTS[trial % OPPONENTS.size()], system)
				var setup := Setup.new()
				setup.player_state = ShipState.new()
				setup.player_state.configure_profile(player)
				setup.enemy_state = ShipState.new()
				setup.enemy_state.configure_profile(enemy)
				var attribute: String = PRODUCTION[index]
				setup.player_state.set(attribute, setup.player_state.get(attribute) + (2 if system == 8 else 1))
				setup.player_cards = deck.player_pool(player)
				setup.identity_weights = deck.acquired_draw_weights(Config)
				setup.enemy_cards = Deck.enemy_pool(enemy, system, mode != "baseline")
				var prepared := trial % 8 >= 4
				if prepared:
					Preparation.apply(setup.player_state, {"shields":6, "materials":5, attribute:1}, {"disrupt":"energy"})
					Preparation.apply(setup.enemy_state, {"crew":5, "reactor":1}, {})
				var stats := {}
				var result := play_match(player, enemy, (trial / 8) % Modifier.NAMES.size(), seed_value,
					{"battle_setup":setup, "cards":stats, "weights":{"damage":1.5, "production":4.0},
					"allocation":"balanced", "emp":false,
					"rarity_policy":{"chance":0.10 if mode == "baseline" else 0.05,
						"locked":2 if mode == "baseline" else 5, "enemy_chance":0.0 if mode == "baseline" else 0.05}})
				var win := str(result.outcome).begins_with("win_")
				totals.wins += int(win)
				totals.rounds += result.rounds
				totals.round6 += int(result.rounds >= 6)
				totals.hull += result.remaining_hull
				totals.shields += result.remaining_shields
				totals.production += result.production.reduce(func(sum, n): return sum + n, 0)
				totals.outcomes[result.outcome] = int(totals.outcomes.get(result.outcome, 0)) + 1
				var sample: Dictionary = totals.prepared if prepared else totals.unprepared
				sample.wins += int(win)
				sample.rounds += result.rounds
				var first_rare := 101
				var played_rare := false
				for item in stats.values():
					if item.tier > 1:
						totals["drawn%d" % item.tier] += int(item.get("drawn", 0))
						totals["played%d" % item.tier] += int(item.get("played", 0))
					if item.tier == 3:
						first_rare = mini(first_rare, int(item.get("first_draw_round", 101)))
						played_rare = played_rare or int(item.get("played", 0)) > 0
						totals.held3 += int(item.get("held_turns", 0))
						totals.affordable3 += int(item.get("affordable", 0))
					if not totals.cards.has(item.name): totals.cards[item.name] = {"drawn":0,"played":0}
					totals.cards[item.name].drawn += int(item.get("drawn", 0))
					totals.cards[item.name].played += int(item.get("played", 0))
				totals.played3_battles += int(played_rare)
				totals.held3_never_played += int(first_rare < 101 and not played_rare)
				for round_index in [8, 10, 15]:
					totals["draw_by_%d" % round_index] += int(first_rare <= round_index)
			file.store_line(JSON.stringify({"ship":player.ship_name,"mode":mode,"totals":totals}))
			file.flush()
			print(player.ship_name, " / ", mode, ": 100 battles")
	file.close()
	quit()
