extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const Sector = preload("res://scripts/expedition/warzone_sector.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> State:
	var state := State.new()
	state.start(0, Rules, 19)
	state.defense.complete = true
	state.generate_system()
	return state

func run() -> void:
	var state := fresh()
	var op = state.warzone
	var enemy := state.warzone_fleet(0)
	op.player_preparation = {"shields": 6, "reactor": 1, "disrupt": "energy"}
	op.fleet_preparations[str(enemy.id)] = {"energy": 5, "quarters": 1, "disrupt": "materials"}
	state.navigation.checkpoint_position([80.0, 0.0, 80.0])
	check(state.prepare_battle(0) == null and not op.player_preparation.is_empty(),
		"Unsuccessful entry leaves both packages pending")
	state.navigation.checkpoint_position(State.Defense.wire(enemy.position))
	var persistence := Persistence.new()
	persistence.store.path = "user://warzone-preparation-test.json"
	persistence.store.clear_run()
	var snapshot := persistence.checkpoint_battle(state, 0, 419)
	check(snapshot.saved and snapshot.environment.preparations.player.reactor == 1,
		"Pending preparations freeze into the existing battle marker")
	var replay: Dictionary = persistence.store.load_run()
	var expected_shields := state.starting_value(state.ship(), "shields") + 6
	var expected_materials := maxi(0, state.starting_value(state.ship(), "materials") - 4)
	var setup := state.prepare_battle(0, null, snapshot.environment)
	check(setup.player_state.shields == expected_shields
		and setup.player_state.reactor == state.production("reactor") + 1
		and setup.player_state.materials == expected_materials,
		"Player preparation affects detached starting stats and observes enemy disruption")
	check(setup.enemy_state.energy == setup.enemy_profile.energy + 1
		and setup.enemy_state.quarters == setup.enemy_profile.quarters + 1
		and op.player_preparation.is_empty() and not op.fleet_preparations.has(str(enemy.id)),
		"Enemy preparation and player disruption apply once")
	if not replay.is_empty():
		var resumed: State = replay.state
		var restored := resumed.prepare_battle(0, null, replay.battle.environment)
		check(restored.player_state.snapshot() == setup.player_state.snapshot()
			and restored.enemy_state.snapshot() == setup.enemy_state.snapshot()
			and resumed.warzone.player_preparation.is_empty(), "Battle resume recreates the same starts without stacking")
	else:
		check(false, "Battle checkpoint can be restored")
	persistence.store.clear_run()
	check_automated()
	print("Warzone preparation: %d failures" % failures)
	quit(int(failures > 0))


func check_automated() -> void:
	var state := fresh()
	var op = state.warzone
	var ally: Dictionary = op.fleets[0]
	var enemy: Dictionary = op.fleets[2]
	var shields_before: int = ally.strength
	var before: float = op.prepared_shot(ally)
	check(before == op._shot_damage(ally), "Unprepared volley equals the existing damage")
	op.engagement_preparation.records.clear()
	op.fleet_preparations["0"] = {"materials": 10, "reactor": 1, "shields": 12}
	op.fleet_preparations["2"] = {"disrupt": "energy"}
	op._assign_engagements()
	var record: Dictionary = op.engagement_preparation.records["0"]
	check(record.offense + record.shield <= minf(3.0, ally.strength * 0.30) + 0.00001
		and record.penalty == 0.75 and ally.strength == shields_before
		and op.fleet_preparations.is_empty(), "NPC commitment freezes capped bonuses without repairing integrity")
	op._assign_engagements()
	op._exchange_damage()
	check(record.shield < 2.0 and ally.strength <= shields_before and enemy.strength < enemy.strength_limit,
		"Prepared volleys and defensive strength affect actual attrition")
	var copy := Sector.new()
	var payload: Dictionary = JSON.parse_string(JSON.stringify(op.snapshot()))
	check(copy.restore(payload, op.tuning), "Prepared engagement save is valid")
	check(JSON.stringify(copy.engagement_preparation.records) == JSON.stringify(op.engagement_preparation.records),
		"Engagement bonuses and fractional carry survive save restoration")
