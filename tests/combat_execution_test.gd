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
	verify_lethal_hit()
	var board = load("res://scenes/board.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	board.developer_one_hit_kill = true
	check(board.settings_button.find_child("DeveloperOneHitKill", true, false) == null,
		"Standalone and normal combat do not expose the developer toggle")
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


func verify_lethal_hit() -> void:
	var actor: Dictionary = State.new().snapshot()
	var target: Dictionary = State.new().snapshot()
	for key in State.RESOURCES: actor[key] = 100
	target.hull = 40
	target.shields = 100
	var attack := CardData.new()
	attack.family = "energy"
	attack.cost = 1
	attack.effects = {"damage": 1}
	var utility := CardData.new()
	utility.family = "energy"
	utility.effects = {"energy": 1}
	var ordinary = Execution.resolve(attack, false, actor, target)
	check(ordinary.direct_damage == 1 and target.hull == 40 and target.shields == 99,
		"An ordinary positive hit can be fully absorbed by shields")
	Execution.resolve(utility, false, actor, target, null, null, "", true)
	Execution.resolve(attack, true, actor, target, null, null, "", true)
	check(target.hull == 40 and target.shields == 99, "Utility cards and discards do not trigger One-Hit Kill")
	var lethal = Execution.resolve(attack, false, actor, target, null, null, "", true)
	check(lethal.direct_damage == 1 and lethal.hull_damage.target == 40 and target.hull == 0 and target.shields == 0,
		"A shield-absorbed hit defeats the enemy and keeps the real hit report for VFX")
	check(Execution.outcome({"player": actor, "enemy": target}, Failure.new()) == "win_hull"
		and attack.effects.damage == 1, "One-Hit Kill uses the normal Hull outcome and preserves card stats")
