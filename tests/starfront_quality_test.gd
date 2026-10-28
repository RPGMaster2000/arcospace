extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Result = preload("res://scripts/combat/battle_result.gd")
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh() -> Resource:
	var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
	rules.game_mode = "defense"
	rules.defense_tuning = rules.defense_tuning.duplicate(true)
	var state = State.new()
	state.start(0, rules, 42042)
	return state
func result_for(state: Resource, index: int) -> RefCounted:
	state.defense.contact = index
	state.prepare_battle(index)
	var result = Result.new()
	result.result_id = 1000 + index
	result.encounter_index = index
	result.system_number = state.system_number
	result.winner = "player"
	result.escaped_by_ftl = true
	result.player_hull = state.hull
	result.salvage = state.salvage
	result.battles_won = state.battles_won + 1
	return result
func run() -> void:
	var state = fresh()
	check(is_equal_approx(state.rules.defense_tuning.player_speed, 7.0) and is_equal_approx(state.rules.defense_tuning.seconds_per_distance, 1.0/7.0), "Player and strategic rates use v1.1 calibration")
	var index: int = -1
	var approach_index: int = -1
	for i in range(state.encounters.size()):
		if state.encounters[i].kind != "poi": continue
		var poi: Resource = state.encounters[i].poi
		for j in poi.approaches.size():
			var approach: Resource = poi.approaches[j]
			if state.locked_reason(approach).is_empty() and approach.success.hull >= 0:
				index = i
				approach_index = j
				break
		if index >= 0: break
	var before: Vector3 = state.defense.units[0].position
	check(index >= 0 and state.resolve_approach(index, approach_index, 0.0), "PoI interaction resolves")
	check(absf(before.distance_to(state.defense.units[0].position)-1.8) < 0.0001, "Completed PoI advances exactly 1.5 strategic seconds")
	before = state.defense.units[0].position
	check(not state.resolve_approach(index, approach_index, 0.0) and state.defense.units[0].position == before, "Repeated PoI cannot advance time again")
	state = fresh()
	var result = result_for(state, 0)
	before = state.defense.units[1].position
	state.record_battle(result)
	check(state.defense.revealed and absf(before.distance_to(state.defense.units[1].position)-3.0) < 0.0001, "Battle advances exactly 2.5 strategic seconds")
	before = state.defense.units[1].position
	state.record_battle(result)
	check(before == state.defense.units[1].position, "Repeated battle result has no second penalty")
	state.active_battle = -1
	state = fresh()
	state.defense.neutralize(0)
	state.consume_defense_reveal()
	state.rules.defense_tuning.enemy_speed = 0.0
	var away := Vector3(0,100,0)
	state.defense.advance_time(6.9, away, away, true)
	check(state.defense.reinforcements_spawned == 0, "No reinforcement before first deadline")
	state.defense.advance_time(0.1, away, away, true)
	check(state.defense.reinforcements_spawned == 1 and state.defense.active_attackers() == 2, "First reinforcement after seven strategic seconds")
	state.defense.advance_time(9, away, away, true)
	check(state.defense.reinforcements_spawned == 2 and state.defense.active_attackers() == 3, "Subsequent reinforcement after nine seconds")
	state.defense.advance_time(20, away, away, true)
	check(state.defense.reinforcements_spawned == 2 and state.defense.reinforcement_remaining == 0, "Fleet cap defers a single spawn without a burst")
	var occupied: int = state.defense.units[1].encounter
	state.defense.neutralize(occupied)
	state.defense.advance_time(0.1, away, away, true)
	check(state.defense.reinforcements_spawned == 3 and state.defense.active_attackers() == 3, "Freeing a slot deploys only one deferred ship")
	state.defense.neutralize(state.defense.units[3].encounter)
	state.defense.advance_time(9.0, away, away, true)
	check(state.defense.reinforcements_spawned == 4, "Fourth reinforcement respects the configured lifetime limit")
	state.defense.neutralize(state.defense.units[4].encounter)
	state.defense.advance_time(100.0, away, away, true)
	check(state.defense.reinforcements_spawned == 4, "No fifth reinforcement is generated")
	var snapshot: Dictionary = state.defense.snapshot()
	check(Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state)))) == null, "Test-only direct mutations cannot bypass ledger validation")
	var copy = State.Defense.new()
	var entries: Array = state.encounters.duplicate(true)
	for unit in state.defense.units: entries[unit.encounter].completed = unit.status not in ["active", "reserve"]
	check(copy.restore(snapshot, state.rules.defense_tuning, entries), "Fleet timing and identities restore from validated snapshot")
	check(copy.reinforcements_spawned == 4 and is_equal_approx(copy.reinforcement_remaining,state.defense.reinforcement_remaining), "Reinforcement countdown and count survive restoration")
	state.defense.neutralize(2)
	state.defense.advance_time(100, away, away, true)
	check(state.defense.complete and state.defense.reinforcements_spawned == 4, "Mothership victory cancels future reinforcements")
	state = fresh()
	result = result_for(state, 0)
	state.record_battle(result)
	state.active_battle = -1
	check(is_equal_approx(state.defense.reinforcement_remaining, 7.0), "Reinforcement clock waits for the reveal presentation")
	state.consume_defense_reveal()
	state._commit_activity_time(7.0)
	check(state.defense.reinforcements_spawned == 1, "Committed activity time advances reinforcement scheduling")
	var restored: Resource = Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))))
	check(restored != null and restored.defense.snapshot() == state.defense.snapshot(), "Spawned reinforcement, timer and unit identity survive a complete save roundtrip")
	state = fresh()
	var version2: Dictionary = Save.encode(state)
	version2.metagame_version = 2
	version2.defense.units.resize(3)
	version2.defense.erase("reinforcement_remaining")
	version2.defense.erase("reinforcements_spawned")
	version2.defense.erase("deferred_seconds")
	for unit in version2.defense.units:
		unit.erase("reinforcement")
		unit.erase("spawned")
	version2.encounters.resize(version2.encounters.size() - 4)
	var migrated: Resource = Save.new().decode(JSON.parse_string(JSON.stringify(version2)))
	check(migrated != null and migrated.defense.units.size() == 7, "Version-2 defense save receives deterministic inactive reserves")
	if migrated != null:
		check(Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(migrated)))) != null, "Migrated defense save writes and validates as version 3")
	state = fresh()
	var target_unit: Dictionary = state.defense.units[0]
	target_unit.position = state.defense.home
	state.begin_travel(0)
	var origin: Vector3 = State.Defense.point(state.navigation.position)
	state.navigation.report_movement(State.Defense.wire(origin.move_toward(Vector3.ZERO, 1.0)))
	check(target_unit.status == "arrived" and not state.navigation.leg_active and state.travel_destination == -1, "Pursuit cancels when its target reaches the homeworld")
	state = fresh()
	var player: Vector3 = State.Defense.point(state.navigation.position)
	var toward_home: Vector3 = (state.defense.home-player).normalized()
	state.defense.units[0].position = player - toward_home * 4.0
	var hostile_before: Vector3 = state.defense.units[0].position
	state._commit_activity_time(3.0)
	check(state.defense.contact == -1 and is_zero_approx(state.defense.deferred_seconds), "Activity penalty never starts a new battle, even when an enemy passes the stationary player")
	check(absf(hostile_before.distance_to(state.defense.units[0].position) - 3.6) < 0.0001, "Enemy movement still advances during a suppressed-contact activity penalty")
	check(Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state)))) != null, "Activity penalty without contact remains saveable")
	var other_before: Vector3 = state.defense.units[1].position
	var resumed_result = result_for(state, 0)
	state.record_battle(resumed_result)
	check(state.defense.contact == -1 and is_zero_approx(state.defense.deferred_seconds), "Battle completion penalty also suppresses immediate chain battles")
	check(absf(other_before.distance_to(state.defense.units[1].position) - 2.5 * 1.2) < 0.0001, "Battle penalty still advances other hostile ships once")
	other_before = state.defense.units[1].position
	state.record_battle(resumed_result)
	check(other_before == state.defense.units[1].position, "Replaying a battle result cannot repeat its strategic-time penalty")
	state = fresh()
	var target: Vector3 = state.defense.intercept_point(0, state.defense.start)
	var path: float = target.distance_to(state.defense.start)
	var event: Dictionary = state.defense.advance_time(path * state.rules.defense_tuning.seconds_per_distance, state.defense.start, target)
	check(event.contact == 0, "Analytic destination produces a swept interception")
	print("Starfront v1.1 quality: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
