extends SceneTree
const Cards = preload("res://scripts/card_library.gd")
const Ships = preload("res://scripts/ship_library.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Hand = preload("res://scripts/card_hand.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const Effects = preload("res://scripts/card_effects.gd")
const Match = preload("res://scripts/match_rules.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func snapshot() -> Dictionary:
	return {"hull":30,"shields":10,"materials":100,"energy":100,"crew":100,"synthesizer":2,"reactor":2,"quarters":2}
func run() -> void:
	check(Cards.CARDS.size() == 68, "Expanded library has 68 identities")
	for card in Cards.CARDS:
		var original: Dictionary = card.effects.duplicate(true)
		check(card.upgrade_effects.size() == 2 and card.upgrade_level == 0, "Two upgrade definitions: " + card.card_name)
		for level in [1, 2]:
			var upgraded: Resource = card.with_upgrade(level)
			check(upgraded.cost == card.cost and upgraded.tier == card.tier, "Unchanged cost and rarity: " + card.card_name)
			check(upgraded.identity_key() == card.identity_key() and upgraded.upgrade_level == level, "Stable upgraded identity")
			check(upgraded.card_name.ends_with("+".repeat(level)) and upgraded.description == card.describe_effects(upgraded.effects) + ("; play again" if card.play_again else ""), "Accurate UI")
			check(upgraded.effects != original and upgraded.play_again == card.play_again, "Meaningful upgrade without new action: " + card.card_name)
			var actor: Dictionary = snapshot()
			var enemy: Dictionary = snapshot()
			var generator = RandomNumberGenerator.new()
			generator.seed = 987
			check(Effects.play(upgraded, actor, enemy, generator), "All upgrade effects resolve")
			check(actor.hull >= 0 and enemy.hull >= 0, "Valid Hull")
		check(card.effects == original and card.upgrade_level == 0, "Library never mutated")
	var reward_t2: int = 0
	for ship_index in range(preload("res://scripts/ship_library.gd").PLAYERS.size()):
		var state = State.new()
		state.start(ship_index, Rules, 65537)
		check(state.player_pool().size() == 25, "25 starting identities: " + state.ship().ship_name)
		var identities: Dictionary = {}
		var production: Dictionary = {}
		for card in state.player_pool():
			identities[card.identity_key()] = true
			check(card.tier == 1, "Starting cards are Tier 1")
			for key in Match.PRODUCTION:
				if card.effects.has(key): production[key] = true
			if card.effects.has("production_other"): production[card.effects.production_other.type] = true
		check(production.size() == 3, "Each ship can improve every production type")
		check(identities.size() == 25, "No duplicate starting identities")
		var excluded: Dictionary = {}
		for card in Cards.CARDS:
			if not identities.has(card.identity_key()): excluded[card.identity_key()] = false
		for trial in range(1000):
			var offers: Array[Resource] = state.random_card_offers()
			check(offers.size() == 3 and offers[0] != offers[1] and offers[1] != offers[2] and offers[0] != offers[2], "Three distinct rewards")
			for offer in offers:
				check(not identities.has(offer.identity_key()), "Rewards exclude owned")
				excluded[offer.identity_key()] = true
			if ship_index == 0 and offers[0].tier == 2: reward_t2 += 1
		for key in excluded: check(excluded[key], "Every excluded card obtainable")
		for card in state.random_card_offers(2): check(card.tier >= 2, "Minimum rarity honored")
		var enemy_before: Array[Resource] = state.shared_pool()
		state.pending_choice = "card"
		state.card_offers = state.random_card_offers()
		check(state.choose_card(0) and not state.choose_card(0), "Acquisition single use")
		check(state.player_pool().size() == 26 and state.shared_pool() == enemy_before, "Separate pools")
		var acquired: Resource = state.acquired_cards[0]
		var hand = Hand.new()
		state.active_player_hand = hand
		hand.card_pool = state.player_pool()
		hand.cards.assign([acquired, acquired])
		for level in [1, 2]:
			state.pending_choice = "upgrade"
			check(state.choose_upgrade(acquired.identity_key()), "Acquired card upgrades twice")
			for held in hand.cards:
				check(held.upgrade_level == level and held.effects == acquired.upgrade_effects[level - 1], "Every held copy updated")
			for pooled in state.player_pool():
				if pooled.identity_key() == acquired.identity_key(): check(pooled.upgrade_level == level, "Every pool copy updated")
		state.pending_choice = "upgrade"
		check(not state.choose_upgrade(acquired.identity_key()), "No third upgrade")
		check(acquired.upgrade_level == 0, "Enemy original remains base")
		hand.free()
		state.pending_choice = ""
		for profile in Rules.enemy_ships:
			var board = load("res://scenes/board_3d.tscn").instantiate()
			board.expedition = state
			board.setup_settings = {"player_ship":ship_index, "enemy_data":profile}
			board.get_node("BattleEffects").enabled = false
			root.add_child(board)
			board.enemy_timer.stop()
			check(board.hand.card_pool.size() == 26 and board.enemy_hand.card_pool.size() == 68, "Real battle uses separate pools")
			for pooled in board.hand.card_pool:
				if pooled.identity_key() == acquired.identity_key(): check(pooled.upgrade_level == 2, "Upgrades persist into successive battles")
			for pooled in board.enemy_hand.card_pool: check(pooled.upgrade_level == 0, "Real enemy pool remains base")
			check(board.enemy_hand.family_weights == profile.card_family_weights and board.enemy_ai.tactical_weights == profile.tactical_weights, "Real board applies enemy configuration")
			board.free()
			await process_frame
		# Exhaust the eligible reward pool without introducing duplicate offers.
		state.acquired_cards.assign(Cards.CARDS)
		check(state.random_card_offers().is_empty(), "Exhausted rewards empty internally")
		var outcome = preload("res://scripts/encounter_outcome.gd").new()
		outcome.card_reward = true
		state._apply_outcome(outcome)
		check(state.pending_choice.is_empty(), "Exhausted rewards never strand the UI")
		state.acquired_cards.clear()
		var unowned_t2: Array[Resource] = []
		for card in Cards.CARDS:
			if card.tier == 2: unowned_t2.append(card)
		for slot in range(unowned_t2.size() - 2): state.acquired_cards.append(unowned_t2[slot])
		check(state.random_card_offers(2).size() == 2, "Two remaining rewards show two choices")
	check(absf(reward_t2 / 1000.0 - 0.6) < 0.06, "60/40 reward tier weighting")
	var draw = Hand.new()
	draw.rng.seed = 720
	draw.tier_two_chance = 1.0
	for round_number in [1, 2]:
		draw.current_round = round_number
		for trial in range(100): check(draw.draw_card().tier == 1, "Tier 2 locked through round two")
	draw.current_round = 3
	for trial in range(100): check(draw.draw_card().tier == 2, "Tier 2 eligible round three")
	draw.card_pool.assign([Cards.CARDS[0], Cards.CARDS[1]])
	draw.identity_weights[Cards.CARDS[0].identity_key()] = 3.0
	var weighted: int = 0
	for trial in range(10000):
		if draw.draw_card() == Cards.CARDS[0]: weighted += 1
	check(absf(weighted / 10000.0 - 0.75) < 0.025, "Acquired 3x weight observable within rarity")
	draw.free()
	await test_enemies()
	print("Card progression checks: %d failures" % failures)
	quit(1 if failures else 0)

func test_enemies() -> void:
	for profile in Rules.enemy_ships:
		var hand = Hand.new()
		hand.rng.seed = 1234
		hand.current_round = 3
		hand.family_weights = profile.card_family_weights
		hand.effect_weights = profile.card_effect_weights
		var seen: Dictionary = {}
		var attack: int = 0
		var defense: int = 0
		for trial in range(20000):
			var card: Resource = hand.draw_card()
			seen[card.identity_key()] = true
			check(card.upgrade_level == 0 and card in Cards.CARDS, "Enemy draws base library")
			if card.effects.has("damage"): attack += 1
			if card.effects.has("hull") or card.effects.has("shields"): defense += 1
		check(seen.size() == 68, "Soft weights retain full library: " + profile.ship_name)
		print("%s seeded draw sample: attacks %.1f%%; repairs/shields %.1f%%" % [profile.ship_name, attack / 200.0, defense / 200.0])
		var ai = AI.new()
		ai.rng.seed = 100
		ai.tactical_weights = profile.tactical_weights
		ai.tactical_variation = 0
		ai.hull_capacity = profile.hull_capacity
		var actor: Dictionary = snapshot()
		actor.hull = 12
		var enemy: Dictionary = snapshot()
		var move: Dictionary = ai.choose([Cards.CARDS[11], Cards.CARDS[6], Cards.CARDS[3]], actor, enemy, 100)
		check(not move.discard, "Archetype chooses affordable legal action")
		print("%s tactical fixture chooses %s" % [profile.ship_name, [Cards.CARDS[11], Cards.CARDS[6], Cards.CARDS[3]][move.slot].card_name])
		actor.hull = profile.hull_capacity
		move = ai.choose([Cards.CARDS[11], Cards.CARDS[1], Cards.CARDS[3]], actor, enemy, 100)
		var expected: int = 0 if profile.ship_name.begins_with("Marauder") else (1 if profile.ship_name.begins_with("Sentinel") else 2)
		check(move.slot == expected, "Observable archetype tactical preference: " + profile.ship_name)
		for key in Match.RESOURCES: actor[key] = 0
		move = ai.choose([Cards.CARDS[11]], actor, enemy, 100)
		check(move.discard and move.slot == 0, "Unaffordable enemy hand discards")
		ai.free()
		hand.free()
	await process_frame
