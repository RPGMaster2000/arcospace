extends "res://tests/card_progression_simulation.gd"
# Reproducible single-encounter diagnostic using production draw, effects, modifier,
# AI, failure and EMP components. No presentation, rewards or expedition bonuses.
const Modifier = preload("res://scripts/combat_modifier.gd")
const Drive = preload("res://scripts/ftl_drive.gd")
const Board = preload("res://scripts/board.gd")
const SEEDS = 20
const ROUND_LIMIT = 100
const ACTION_LIMIT = 100
func source_revision() -> String:
	var output: Array = []
	if OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], output) == 0:
		return str(output[0]).strip_edges()
	return "unknown"
var records: Array = []

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var selected := int(args[0]) if not args.is_empty() else -1
	for player_index in range(Ships.PLAYERS.size()):
		if selected >= 0 and player_index != selected:
			continue
		var player: Resource = Ships.PLAYERS[player_index]
		for enemy in Config.enemy_ships:
			for kind in range(Modifier.NAMES.size()):
				for seed_value in range(1, SEEDS + 1):
					records.append(play_match(player, enemy, kind, seed_value))
		print("Completed %s: %d battles" % [player.ship_name, records.size()])
	var suffix := str(selected) if selected >= 0 else "all"
	var output := FileAccess.open("res://.godot/six-ship-simulation-" + suffix + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"source_revision": source_revision(), "seeds": SEEDS, "round_limit": ROUND_LIMIT, "matches": records}))
	output.close()
	quit()

func outcome(states: Array, clock: RefCounted) -> String:
	return Execution.outcome({"player": states[0], "enemy": states[1]}, clock)

func play_match(player: Resource, enemy: Resource, kind: int, seed_value: int, audit: Dictionary = {}) -> Dictionary:
	var modern := not audit.is_empty()
	var hands: Array = [Hand.new(), Hand.new()]
	var brains: Array = [AI.new(), AI.new()]
	var states: Array = [state(player), state(enemy)]
	var names: Array[String] = ["player", "enemy"]
	var clock = Failure.new()
	var modifier = Modifier.new()
	modifier.configure(kind)
	modifier.rng.seed = seed_value * 127 + kind
	modifier.next_round = 1 + modifier.rng.randi_range(modifier.MIN_INTERVAL, modifier.MAX_INTERVAL)
	var drive = Drive.new()
	drive.charge_target = player.ftl_turns
	drive.failure_multiplier = 1.0 - player.ftl_resistance
	drive.rng.seed = seed_value * 131 + kind
	var use_emp: bool = player.ship_name != "Titania"
	for side in range(2):
		hands[side].rng.seed = seed_value * 101 + side
		hands[side].card_pool.assign([player, enemy][side].starting_cards)
		hands[side].drop_multiplier = modifier.TEMPORAL_DROP_MULTIPLIER if kind == 5 else 1.0
		brains[side].rng.seed = seed_value * 109 + side
		brains[side].hull_capacity = states[side].hull_capacity
	hands[0].configure_player_allocation(2.0)
	# Historical trace fixtures explicitly opt out of the new soft draw preference.
	if player.has_meta("legacy_draws"): hands[0].anti_repeat_enabled = false
	hands[1].family_weights = enemy.card_family_weights
	hands[1].effect_weights = enemy.card_effect_weights
	brains[1].tactical_weights = enemy.tactical_weights
	brains[1].tactical_variation = enemy.tactical_variation
	if modern:
		modifier.configure(kind, seed_value)
		drive.rng.seed = seed_value ^ 109
		hands[0].rng.seed = seed_value ^ 101
		hands[1].rng.seed = seed_value ^ 103
		brains[0].rng.seed = seed_value ^ 113
		brains[1].rng.seed = seed_value ^ 107
		hands[0].configure_player_allocation(preload("res://resources/power_allocation.tres").matching_draw_weight)
		hands[0].signature_card = player.signature_card
		brains[0].tactical_weights = audit.weights
		drive.charge_target += int(audit.get("emp_bonus", 0))
		use_emp = audit.emp
	hands[0].deal_player_opening()
	hands[1].deal(6)
	var stats: Dictionary = audit.get("cards", {})
	if modern:
		for card in hands[0].cards: _count_card(stats, card, "drawn")
	var resource_sum := Vector3.ZERO
	var samples := 0
	var dead_hands := [0, 0]
	var turns := [0, 0]
	var gross_damage := 0
	var result := ""
	var rounds := 0
	var actions := 0
	var disruptions := 0
	var activations := [0, 0]
	var cursor: Dictionary = {"side": "player", "round": 1}
	while cursor.round <= ROUND_LIMIT:
		var round_number: int = cursor.round
		var side: int = 0 if cursor.side == "player" else 1
		rounds = round_number
		for hand in hands:
			hand.current_round = round_number
		if side == 0:
			var before_hull: int = states[0].hull
			var notice: String = modifier.begin_round(round_number)
			if kind == 1 and not notice.is_empty():
				modifier.asteroid_strike(states[0], states[1])
				if drive.take_hull_damage(Board.permanent_damage(before_hull, states[0].hull, player.hull_capacity)):
					disruptions += 1
			result = outcome(states, clock)
			if not result.is_empty():
				break
			drive.begin_player_turn()
		Execution.begin_turn(states[side])
		var used_slot := -1
		if modern:
			turns[side] += 1
			var actor: Dictionary = states[side]
			if not hands[side].cards.any(func(card): return card != null and Execution.can_play(card, false, actor)):
				dead_hands[side] += 1
			if side == 0:
				resource_sum += Vector3(actor.materials, actor.energy, actor.crew)
				samples += 1
				for card in hands[0].cards:
					_count_card(stats, card, "held_turns")
					if card != null and Execution.can_play(card, false, actor): _count_card(stats, card, "affordable")
		# EMP is legal before taking an action and can save an expiring ship.
		if side == 0 and use_emp and drive.can_warp():
			result = "emp_escape"
			break
		var completed_turn := false
		for action_index in range(ACTION_LIMIT):
			for index in range(2):
				states[index].systems_failure_remaining = clock.remaining[names[index]]
			if side == 0:
				hands[0].select_allocation("systems" if Rules.systems_failure_triggered(states[0]) else audit.get("allocation", "balanced"))
			var move: Dictionary = brains[side].choose(hands[side].cards, states[side], states[1-side], modifier.forecast_context() if modern else {})
			if move.is_empty():
				completed_turn = true
				break
			var card: Resource = hands[side].cards[move.slot]
			assert(move.discard or states[side][card.family] >= card.cost)
			var before_hull: int = states[0].hull
			var old_shields: int = states[side].shields
			var old_hull: int = states[side].hull
			var old_resource: int = states[side][card.family]
			var resolution = Execution.resolve(card, move.discard, states[side], states[1-side], modifier)
			assert(resolution != null)
			if not move.discard:
				# Intermediate damage precedes any same-card healing.
				var key := "actor" if side == 0 else "target"
				var report: Dictionary = resolution.hull_damage
				var amount: int = report.get(key, 0)
				var prior: int = report.get(key + "_before", before_hull)
				gross_damage += Board.permanent_damage(prior, prior - amount, player.hull_capacity)
				if drive.take_hull_damage(Board.permanent_damage(prior, prior - amount, player.hull_capacity)):
					disruptions += 1
			if modern:
				if side == 0:
					_count_card(stats, card, "discarded" if move.discard else "played")
					if not move.discard:
						_count_card(stats, card, "target_hull", resolution.hull_damage.get("target", 0))
						_count_card(stats, card, "shield_gain", maxi(0, states[0].shields - old_shields))
						_count_card(stats, card, "hull_gain", maxi(0, states[0].hull - old_hull))
						_count_card(stats, card, "family_net", states[0][card.family] - old_resource)
				hands[side].cards[move.slot] = null
				used_slot = move.slot
			else: hands[side].replace_card(move.slot)
			actions += 1
			var previous: Dictionary = clock.remaining.duplicate()
			clock.sync({"player": states[0], "enemy": states[1]}, names[side], failure_turns)
			for index in range(2):
				if previous[names[index]] < 0 and clock.remaining[names[index]] >= 0:
					activations[index] += 1
			result = outcome(states, clock)
			if not result.is_empty():
				break
			if modern and resolution.extra_action:
				_refill(hands, side, used_slot, round_number, stats)
				used_slot = -1
			if side == 0 and use_emp and drive.can_warp():
				result = "emp_escape"
				break
			if not resolution.extra_action:
				completed_turn = true
				break
		if not result.is_empty():
			break
		if not completed_turn:
			result = "action_limit"
			break
		Execution.end_turn({"player": states[0], "enemy": states[1]}, clock, names[side], failure_turns)
		result = outcome(states, clock)
		if not result.is_empty():
			break
		cursor = Execution.next_turn(names[side], round_number)
		if modern and used_slot >= 0: _refill(hands, side, used_slot, cursor.round, stats)
	if result.is_empty():
		result = "round_limit"
	assert(modern or not (player.ship_name == "Titania" and result == "emp_escape"))
	var record := {"player": player.ship_name, "enemy": enemy.ship_name, "rank": enemy.enemy_rank, "modifier": Modifier.NAMES[kind], "seed": seed_value, "outcome": result, "rounds": rounds, "actions": actions, "emp_disruptions": disruptions, "failure_activations": activations}
	if modern:
		record.merge({"hull_lost": maxi(0, player.hull_capacity - states[0].hull), "gross_hull_damage": gross_damage,
			"resource_sum": [int(resource_sum.x), int(resource_sum.y), int(resource_sum.z)],
			"resource_samples": samples, "dead_hands": dead_hands, "turns": turns})
	for node in hands + brains + [modifier, drive]:
		node.free()
	return record

func _refill(hands: Array, side: int, slot: int, round_number: int, stats: Dictionary) -> void:
	hands[side].current_round = round_number
	hands[side].replace_card(slot)
	if side == 0: _count_card(stats, hands[side].cards[slot], "drawn")

func _count_card(stats: Dictionary, card: Resource, metric: String, amount: int = 1) -> void:
	if card == null: return
	var key: String = card.identity_key()
	if not stats.has(key): stats[key] = {"name": card.card_name, "family": card.family, "tier": card.tier}
	var item: Dictionary = stats[key]
	item[metric] = int(item.get(metric, 0)) + amount
