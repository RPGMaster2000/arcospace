extends "res://tests/card_progression_simulation.gd"
# Reproducible single-encounter diagnostic using production draw, effects, modifier,
# AI, failure and EMP components. No presentation, rewards or expedition bonuses.
const Modifier = preload("res://scripts/combat_modifier.gd")
const Drive = preload("res://scripts/ftl_drive.gd")
const Board = preload("res://scripts/board.gd")
const SEEDS = 20
const ROUND_LIMIT = 100
const ACTION_LIMIT = 100
const SOURCE_REVISION = "8864ed8ee1b9ea594ddc4cca5ce257fd9a866721"
var records: Array = []

func run() -> void:
	var settings = Board.new()
	failure_turns = settings.systems_failure_turns
	settings.free()
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
	output.store_string(JSON.stringify({"source_revision": SOURCE_REVISION, "seeds": SEEDS, "round_limit": ROUND_LIMIT, "matches": records}))
	output.close()
	quit()

func outcome(states: Array, clock: RefCounted) -> String:
	if states[0].hull <= 0 and states[1].hull <= 0:
		return "draw_hull"
	if states[1].hull <= 0:
		return "win_hull"
	if states[0].hull <= 0:
		return "loss_hull"
	var player_failed: bool = clock.remaining.player == 0 and Rules.systems_failure_triggered(states[0])
	var enemy_failed: bool = clock.remaining.enemy == 0 and Rules.systems_failure_triggered(states[1])
	if player_failed and enemy_failed:
		return "draw_systems"
	if enemy_failed:
		return "win_systems"
	if player_failed:
		return "loss_systems"
	return ""

func play_match(player: Resource, enemy: Resource, kind: int, seed_value: int) -> Dictionary:
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
	hands[1].family_weights = enemy.card_family_weights
	hands[1].effect_weights = enemy.card_effect_weights
	brains[1].tactical_weights = enemy.tactical_weights
	brains[1].tactical_variation = enemy.tactical_variation
	hands[0].deal_player_opening()
	hands[1].deal(6)
	var result := ""
	var rounds := 0
	var actions := 0
	var disruptions := 0
	var activations := [0, 0]
	for round_number in range(1, ROUND_LIMIT + 1):
		rounds = round_number
		for hand in hands:
			hand.current_round = round_number
		for side in range(2):
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
			Rules.income(states[side])
			# EMP is legal before taking an action and can save an expiring ship.
			if side == 0 and use_emp and drive.can_warp():
				result = "emp_escape"
				break
			var completed_turn := false
			for action_index in range(ACTION_LIMIT):
				for index in range(2):
					states[index].systems_failure_remaining = clock.remaining[names[index]]
				if side == 0:
					hands[0].select_allocation("systems" if Rules.systems_failure_triggered(states[0]) else "balanced")
				var move: Dictionary = brains[side].choose(hands[side].cards, states[side], states[1-side])
				if move.is_empty():
					completed_turn = true
					break
				var card: Resource = hands[side].cards[move.slot]
				assert(move.discard or states[side][card.family] >= card.cost)
				var before_hull: int = states[0].hull
				if move.discard:
					states[side][card.family] += floori(card.cost / 3.0)
				else:
					modifier.play(card, states[side], states[1-side])
					# Report tracks intermediate damage before any same-card healing.
					var key := "actor" if side == 0 else "target"
					var report: Dictionary = modifier.last_hull_damage
					var amount: int = report.get(key, 0)
					var prior: int = report.get(key + "_before", before_hull)
					if drive.take_hull_damage(Board.permanent_damage(prior, prior - amount, player.hull_capacity)):
						disruptions += 1
				hands[side].replace_card(move.slot)
				actions += 1
				var previous: Dictionary = clock.remaining.duplicate()
				clock.sync({"player": states[0], "enemy": states[1]}, names[side], failure_turns)
				for index in range(2):
					if previous[names[index]] < 0 and clock.remaining[names[index]] >= 0:
						activations[index] += 1
				result = outcome(states, clock)
				if not result.is_empty():
					break
				if side == 0 and use_emp and drive.can_warp():
					result = "emp_escape"
					break
				if move.discard or not card.play_again:
					completed_turn = true
					break
			if not result.is_empty():
				break
			if not completed_turn:
				result = "action_limit"
				break
			clock.end_turn(names[side])
			result = outcome(states, clock)
			if not result.is_empty():
				break
		if not result.is_empty():
			break
	if result.is_empty():
		result = "round_limit"
	assert(not (player.ship_name == "Titania" and result == "emp_escape"))
	var record := {"player": player.ship_name, "enemy": enemy.ship_name, "rank": enemy.enemy_rank, "modifier": Modifier.NAMES[kind], "seed": seed_value, "outcome": result, "rounds": rounds, "actions": actions, "emp_disruptions": disruptions, "failure_activations": activations}
	for node in hands + brains + [modifier, drive]:
		node.free()
	return record
