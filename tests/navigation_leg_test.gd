extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var config = Rules.duplicate(true)
	config.chasedown_chance = 1.0
	config.maximum_chasedown_chance = 1.0
	config.log_rolls = false
	var state = State.new()
	state.start(0, config, 42)
	state.navigation_origin = state.FREE_DESTINATION
	state.update_navigation_position([0,0,0])
	# Guaranteed miss advances exactly one RNG draw; redirects never roll again.
	var expected := RandomNumberGenerator.new()
	expected.seed = state.chasedown_rng.seed
	expected.state = state.chasedown_rng.state
	expected.randf()
	check(not state.begin_free_travel([1,0,1], 1.0), "Forcedmiss moves normally")
	# Forced hook deliberately doesn't draw: repeat with actual miss using chance tiny.
	state.arrive_free_destination()
	state.advance_chasedown_cooldown(10)
	config.chasedown_chance = 0.0000001
	config.pressure_chasedown_increment = 0
	check(not state.begin_free_travel([2,0,2]), "Lowchance leg normally misses")
	check(state.chasedown_rng.state == expected.state, "One probability draw on newleg")
	for index in range(10):
		check(not state.begin_free_travel([index+3,0,index+3]), "Redirect doesn't intercept")
	check(state.chasedown_rng.state == expected.state, "Ten redirects exactlyone draw")
	state.advance_chasedown_cooldown(11)
	check(not state.begin_free_travel([20,0,20]) and state.chasedown_rng.state == expected.state, "Long journey never rerolls")
	state.arrive_free_destination()
	check(not state.begin_free_travel([21,0,21]), "New journey permitted after stop")
	expected.randf()
	check(state.chasedown_rng.state == expected.state, "New journey draws once")
	state.arrive_free_destination()
	check(not state.begin_free_travel([22,0,22]) and state.chasedown_rng.state == expected.state, "Tinyjourney cooldown prevents reroll")
	state.advance_chasedown_cooldown(11)
	check(not state.begin_free_travel([23,0,23]) and state.chasedown_rng.state == expected.state, "Skipped leg staysskipped pastcooldown")
	var saved: Dictionary = Save.encode(state)
	var restored = Save.new().decode(saved, config)
	check(restored != null, "Navigation and risk-policy roundtrip through unchanged save shape")
	check(restored != null and restored.navigation.leg_active and restored.chasedown_roll_policy.rolled_this_leg, "Resume protects active journey")
	state.arrive_free_destination()
	config.chasedown_chance = 1
	check(state.begin_free_travel([24,0,24],0), "Neweligible leg intercepts")
	check(state.travel_destination == -1 and not state.navigation.leg_active, "Interception cancelsdestination")
	state.stop_intercepted_travel([4,0,7])
	state.stop_intercepted_travel([99,0,99])
	check(state.navigation.position == [4,0,7], "Firstinterceptionpositionauthoritative")
	check(state.pressure == 0 and not state.ftl_access, "Movement andinterception don'taward progression")
	print("Navigation legs: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
