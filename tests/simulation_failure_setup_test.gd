extends "res://tests/enemy_roster_simulation.gd"
# Exercise inherited startup with run() overridden, just like the roster diagnostic.
var checks: int = 0
var failures: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var settings = preload("res://scripts/board.gd").new()
	check(failure_turns == settings.systems_failure_turns, "Overridden run inherits Board countdown configuration")
	check(failure_turns == 3, "Current gameplay allows three affected-ship turns")
	settings.free()
	for side in ["player", "enemy"]:
		var other: String = "enemy" if side == "player" else "player"
		for acting_side in [side, other]:
			var states: Dictionary = {"player": state(Ships.PLAYERS[0]), "enemy": state(Ships.ENEMIES[0])}
			states[side].reactor = 0
			states[side].quarters = 0
			var clock = Failure.new()
			clock.sync(states, acting_side, failure_turns)
			check(clock.remaining[side] == 3, "Simulation starts a three-turn countdown")
			clock.end_turn(other)
			check(clock.remaining[side] == 3, "Opponent turns do not consume recovery time")
			if acting_side == side:
				clock.end_turn(side)
				check(clock.remaining[side] == 3, "Own activation turn is spared")
			for remaining in [2, 1, 0]:
				clock.end_turn(side)
				check(clock.remaining[side] == remaining, "Countdown expires only after three affected turns")
			states[side].reactor = 1
			clock.sync(states, other, failure_turns)
			check(clock.remaining[side] == -1, "Recovery clears the countdown")
	print("Simulation failure setup: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
