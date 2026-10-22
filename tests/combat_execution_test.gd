extends SceneTree
const Execution = preload("res://scripts/combat/combat_execution.gd")
const State = preload("res://scripts/combat/ship_combat_state.gd")
const Failure = preload("res://scripts/combat/systems_failure.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var actor: Dictionary = State.new().snapshot()
	var target: Dictionary = State.new().snapshot()
	actor.energy = 0
	var before: Dictionary = actor.duplicate(true)
	check(Execution.resolve(Cards.CARDS[11], false, actor, target) == null and actor == before, "Illegal actions do not mutate state")
	var result = Execution.resolve(Cards.CARDS[11], true, actor, target)
	check(result != null and not result.extra_action and actor.energy == floori(Cards.CARDS[11].cost / 3.0), "Discard resolves refund without effects")
	var states: Dictionary = {"player": actor, "enemy": target}
	var clock = Failure.new()
	actor.reactor = 0
	actor.quarters = 0
	Execution.end_turn(states, clock, "player", 3)
	check(clock.remaining.player == 3, "Own activation turn is spared")
	for remaining in [2, 1, 0]:
		Execution.end_turn(states, clock, "player", 3)
		check(clock.remaining.player == remaining, "Three own turns before expiry")
	check(Execution.outcome(states, clock) == "loss_systems", "Shared outcome recognizes expiry")
	target.hull = 0
	check(Execution.outcome(states, clock) == "win_hull", "Hull wins before Systems Failure")
	actor.hull = 0
	check(Execution.outcome(states, clock) == "draw_hull", "Simultaneous Hull loss is a draw")
	check(Execution.next_turn("player", 2) == {"side": "enemy", "round": 2} and Execution.next_turn("enemy", 2) == {"side": "player", "round": 3}, "Round advances only after enemy turn")
	var board = load("res://scenes/board.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	var modifier = preload("res://scripts/combat_modifier.gd").new()
	for kind in range(6):
		for side in ["player", "enemy"]:
			for index in [0, 11, 13, 18, 20, 33]:
				var initial: Dictionary = State.new().snapshot()
				for key in State.RESOURCES: initial[key] = 100
				board.apply_ship_snapshot("player", initial)
				board.apply_ship_snapshot("enemy", initial)
				board.systems_failure = Failure.new()
				board.winner = ""
				board.result_recorded = false
				for environment in [modifier, board.modifier]:
					environment.configure(kind)
					environment.rng.seed = 55
					environment.active = kind in [2, 3]
					environment.ion_factor = 2.0
				var expected_actor: Dictionary = initial.duplicate(true)
				var expected_target: Dictionary = initial.duplicate(true)
				Execution.resolve(Cards.CARDS[index], false, expected_actor, expected_target, modifier)
				board._resolve_card(side, 0, false, Cards.CARDS[index])
				var other: String = "enemy" if side == "player" else "player"
				check(board.ship_snapshot(side) == expected_actor and board.ship_snapshot(other) == expected_target, "Live adapter and headless resolution agree: modifier %d card %d side %s" % [kind, index, side])
	modifier.free()
	board.winner = "player"
	var salvage: int = board.salvage
	board.refresh_display()
	check(not board.result_recorded and board.salvage == salvage, "HUD refresh cannot commit rewards")
	board._record_result()
	var awarded: int = board.salvage
	board.refresh_display()
	board._record_result()
	check(board.result_recorded and board.salvage == awarded, "Explicit conclusion commits rewards once")
	board.free()
	print("Combat execution: %d failures" % failures)
	quit(1 if failures else 0)
