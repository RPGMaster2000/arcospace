extends SceneTree
const Policy = preload("res://scripts/expedition/chasedown_roll_policy.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var policy = Policy.new()
	check(not policy.claim_roll(false) and not policy.rolled_this_leg and policy.cooldown_remaining == 0.0, "Inactive navigation cannot consume a roll or cooldown")
	check(policy.claim_roll(true) and policy.cooldown_remaining == 10.0, "First active journey claims its single roll")
	for redirect in range(10):
		check(not policy.claim_roll(true), "Ten mid-journey redirects cannot claim again")
	policy.advance(12.0)
	check(not policy.claim_roll(true), "Expired cooldown does not reopen an uninterrupted journey")
	policy.reset_leg()
	check(policy.claim_roll(true), "Completed arrival permits a new roll after cooldown")
	policy.advance(4.0)
	policy.reset_leg()
	check(not policy.claim_roll(true) and policy.cooldown_remaining == 6.0, "New short journey moves while its probability check is skipped")
	policy.advance(10.0)
	check(not policy.claim_roll(true), "Skipped journey stays skipped when cooldown expires")
	policy.reset_leg()
	check(policy.claim_roll(true), "Next completed-leg journey can roll")
	for seconds in [-1.0, NAN, INF]:
		policy.advance(seconds)
		check(policy.cooldown_remaining == 10.0, "Invalid elapsed time cannot alter cooldown")
	var snapshot: Dictionary = policy.snapshot()
	var copy = Policy.new()
	check(copy.restore(snapshot) and copy.snapshot() == snapshot, "Risk policy restores exact remaining guard and cooldown")
	for bad in [{"rolled_this_leg": 1, "cooldown_remaining": 2}, {"rolled_this_leg": false, "cooldown_remaining": -1}, {"rolled_this_leg": false, "cooldown_remaining": 10.1}, {"rolled_this_leg": false, "cooldown_remaining": NAN}]:
		check(not copy.restore(bad) and copy.snapshot() == snapshot, "Malformed policy does not partially mutate restored state")
	# These are the existing v1 navigation payloads, not a new or migrated format.
	var store = Save.new()
	var state = State.new()
	state.start(0, Rules, 42)
	var original: Dictionary = Save.encode(state)
	for active in [false, true]:
		var data: Dictionary = original.duplicate(true)
		data.navigation = {"position": [1.0, 0.0, 2.0], "target": [8.0, 0.0, 3.0] if active else [],
			"leg_active": active, "rolled_this_leg": active, "cooldown_remaining": 6.25}
		data.travel_destination = state.FREE_DESTINATION if active else -1
		var restored = store.decode(data)
		check(restored != null, "Existing stopped and active v1 navigation payloads decode")
		if restored != null:
			check(JSON.stringify(Save.encode(restored)) == JSON.stringify(data), "Combined wire payload remains byte-for-byte identical after ownership extraction")
			check(not restored.navigation.snapshot().has("rolled_this_leg") and not restored.navigation.snapshot().has("cooldown_remaining"), "Movement snapshot has no exploration-policy fields")
			check(restored.chasedown_roll_policy.cooldown_remaining == 6.25 and restored.chasedown_roll_policy.rolled_this_leg == active, "Policy is the sole in-memory risk owner")
	var invalid: Dictionary = original.duplicate(true)
	invalid.navigation.rolled_this_leg = true
	check(store.decode(invalid) == null, "Stopped movement cannot retain a consumed active-leg guard")
	state.ftl_access = true
	state.pressure = 0
	state.chasedown_roll_policy.cooldown_remaining = 7.0
	check(state.system_objective_complete() and state.can_jump(), "Persistent objective boundary enables normal departure")
	state.pending_choice = "resource"
	check(state.system_objective_complete() and not state.can_jump(), "Pending choice blocks transient readiness without undoing objective completion")
	state.pending_choice = ""
	check(state.generate_system() and state.chasedown_roll_policy.cooldown_remaining == 7.0 and not state.chasedown_roll_policy.rolled_this_leg, "System transition ends the leg while preserving cooldown")
	check(not state.system_objective_complete(), "Next system objective begins incomplete")
	state.system_number = 6
	state.ftl_access = true
	check(not state.system_objective_complete() and not state.can_jump(), "Missing mandatory Boss keeps persistent objective boundary closed")
	print("Chasedown roll policy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
