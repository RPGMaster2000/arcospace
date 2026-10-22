extends SceneTree
# Deterministic balance diagnostic, not a full match: no modifiers or EMP Pulse.
# Baseline reproduces the previous full pools, round-six unlock and unweighted enemy AI.
const Cards = preload("res://scripts/cards/card_library.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Config = preload("res://encounters/expedition_rules.tres")
const Hand = preload("res://scripts/cards/card_hand.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const Execution = preload("res://scripts/combat/combat_execution.gd")
const Failure = preload("res://scripts/combat/systems_failure.gd")
var failure_turns: int
const Rules = preload("res://scripts/match_rules.gd")
func _initialize() -> void:
	# Configure every diagnostic before dispatching its overridable run().
	var match_settings = preload("res://scripts/board.gd").new()
	failure_turns = match_settings.systems_failure_turns
	match_settings.free()
	call_deferred("run")
func state(profile: Resource) -> Dictionary:
	var result: Dictionary = {"hull":profile.hull_capacity, "shields":profile.shields, "hull_capacity":profile.hull_capacity}
	for key in Rules.RESOURCES + Rules.PRODUCTION: result[key] = profile.get(key)
	return result
func run() -> void:
	print("mode,player,enemy,wins,losses,unresolved,average_rounds,tier2_drawn,tier2_played,early_enemy_tier2_plays,max_early_enemy_tier2_damage")
	for mode in ["baseline", "updated", "progressed"]:
		for player in Ships.PLAYERS:
			for enemy in Config.enemy_ships:
				var totals: Dictionary = {"wins":0,"losses":0,"unresolved":0,"rounds":0,"drawn":0,"played":0,"early":0,"burst":0}
				for seed_value in range(1, 11):
					simulate(player, enemy, mode, seed_value, totals)
				print("%s,%s,%s,%d,%d,%d,%.1f,%d,%d,%d,%d" % [mode,player.ship_name,enemy.ship_name,totals.wins,totals.losses,totals.unresolved,totals.rounds / 10.0,totals.drawn,totals.played,totals.early,totals.burst])
	quit()
func simulate(player: Resource, enemy: Resource, mode: String, seed_value: int, totals: Dictionary) -> void:
	var updated: bool = mode != "baseline"
	var hands: Array = [Hand.new(), Hand.new()]
	var brains: Array = [AI.new(), AI.new()]
	var failure = Failure.new()
	var names: Array[String] = ["player", "enemy"]
	var states: Array = [state(player), state(enemy)]
	var combat = RandomNumberGenerator.new()
	combat.seed = seed_value * 117
	for side in range(2):
		hands[side].rng.seed = seed_value * 101 + side
		hands[side].tier_two_locked_turns = 2 if updated else 5
		brains[side].rng.seed = seed_value * 109 + side
		brains[side].hull_capacity = [player,enemy][side].hull_capacity
	if updated:
		hands[0].card_pool.assign(player.starting_cards)
		if not enemy.starting_cards.is_empty(): hands[1].card_pool.assign(enemy.starting_cards)
		hands[1].family_weights = enemy.card_family_weights
		hands[1].effect_weights = enemy.card_effect_weights
		brains[1].tactical_weights = enemy.tactical_weights
		brains[1].tactical_variation = enemy.tactical_variation
		if mode == "progressed":
			# Three acquired identities and three upgrades, no production/Salvage bonuses.
			var acquired: Array = [29,31,37]
			var upgrades: Dictionary = {6:2,11:1}
			if player.ship_name == "Thunderbolt":
				acquired = [31,32,42]
				upgrades = {8:2,11:1}
			elif player.ship_name == "Titania":
				acquired = [29,30,37]
				upgrades = {6:2,27:1}
			for index in acquired:
				hands[0].card_pool.append(Cards.CARDS[index])
				hands[0].identity_weights[Cards.CARDS[index].identity_key()] = Config.acquired_card_draw_weight
			var replacements: Dictionary = {}
			for index in upgrades:
				replacements[Cards.CARDS[index].identity_key()] = Cards.CARDS[index].with_upgrade(upgrades[index])
			hands[0].apply_upgrades(replacements)
	if updated: hands[0].deal_player_opening()
	else: hands[0].deal(6)
	hands[1].deal(6)
	var finished: bool = false
	var rounds: int = 0
	var cursor: Dictionary = {"side": "player", "round": 1}
	while cursor.round <= 40:
		var round_number: int = cursor.round
		var side: int = 0 if cursor.side == "player" else 1
		rounds = round_number
		for hand in hands: hand.current_round = round_number
		Execution.begin_turn(states[side])
		# Safety bound only for this diagnostic; production turn logic is unchanged.
		for action in range(30):
			for index in range(2): states[index].systems_failure_remaining = failure.remaining[names[index]]
			var move: Dictionary = brains[side].choose(hands[side].cards,states[side],states[1-side])
			if move.is_empty(): break
			var card: Resource = hands[side].cards[move.slot]
			var resolution = Execution.resolve(card, move.discard, states[side], states[1-side], null, combat)
			assert(resolution != null)
			if not move.discard and card.tier == 2:
				totals.played += 1
				if side == 1 and round_number <= 5:
					totals.early += 1
					totals.burst = maxi(totals.burst, int(card.effects.get("damage",0)))
			hands[side].replace_card(move.slot)
			var replacement: Resource = hands[side].cards[move.slot]
			if replacement != null and replacement.tier == 2: totals.drawn += 1
			failure.sync({"player":states[0], "enemy":states[1]}, names[side], failure_turns)
			var result: String = Execution.outcome({"player": states[0], "enemy": states[1]}, failure)
			if not result.is_empty():
				# This historical diagnostic counts draws as player losses.
				totals["wins" if result.begins_with("win") else "losses"] += 1
				finished = true
				break
			if not resolution.extra_action: break
		if not finished:
			Execution.end_turn({"player":states[0], "enemy":states[1]}, failure, names[side], failure_turns)
			var result: String = Execution.outcome({"player":states[0], "enemy":states[1]}, failure)
			if not result.is_empty():
				totals["wins" if result.begins_with("win") else "losses"] += 1
				finished = true
		if finished: break
		cursor = Execution.next_turn(names[side], round_number)
	if not finished: totals.unresolved += 1
	totals.rounds += rounds
	for node in hands + brains: node.free()
