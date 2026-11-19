extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Store = preload("res://scripts/persistence/expedition_save.gd")
const Sector = preload("res://scripts/expedition/warzone_sector.gd")

var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func fresh(seed_value: int, integrity: int = 80) -> Resource:
	var state := State.new()
	state.start(0, Rules, seed_value)
	state.defense.integrity = integrity
	state.defense.revealed = true
	for unit in state.defense.units: state.defense.neutralize(unit.encounter)
	state._secure_defense()
	state.generate_system()
	return state


func travel(state: Resource, site: int) -> void:
	var index := site + State.Warzone.HOSTILE_GROUPS
	var point: Vector3 = state.warzone.objectives[site].position
	state.begin_travel(index)
	state.navigation.report_movement(State.Defense.wire(point))
	state.arrive_destination(index)


func act(state: Resource, site: int, name: String) -> bool:
	travel(state, site)
	return state.warzone_operate(site + State.Warzone.HOSTILE_GROUPS, name)


func roundtrip(state: Resource) -> Resource:
	var original := Store.encode(state)
	var encoded := JSON.stringify(original)
	var restored := Store.new().decode(JSON.parse_string(encoded), state.rules)
	check(restored != null and JSON.stringify(Store.encode(restored)) == encoded, "Exact persisted sector")
	return restored


func generation() -> void:
	var patterns := {}
	for seed_value in range(1, 65):
		var state := fresh(seed_value)
		var op: RefCounted = state.warzone
		patterns[op.pattern] = true
		check(op.is_lattice() and state.system_number == 2, "System 2 uses the lattice")
		check(op.objectives.size() in [9, 12] and op.controlled() == 3, "Hostile starts with majority")
		check(state.can_engage(0) and op.engagement_count() == 2, "Opening fights and accessible contact")
		check(state.enemy_profile(state.encounters[0]).enemy_rank == 1
			and state.enemy_profile(state.encounters[2]).enemy_rank == 2, "Lattice uses Tier 2 and optional Tier 3 opposition")
		check(op.supplied.allied.size() >= 2 and op.supplied.hostile.size() >= 2, "Both sides have viable supply")
		check(not state.environmental_instances.any(func(region): return region.type == "SOLAR_INTERFERENCE"), "No solar influence in the sector")
		check(op.snapshot() == fresh(seed_value).warzone.snapshot(), "Same seed reproduces geometry and deployments")
		check(roundtrip(state) != null, "Generated sector reloads")
	check(patterns.size() == Sector.Lattice.PATTERNS.size(), "All six pattern families occur")


func logistics() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var hostile_before: int = op.supplied.hostile.size()
	var start_clock: int = op.clock_ms
	check(act(state, 7, "sabotage"), "Hostile supply root can be sabotaged behind the front")
	check(op.supplied.hostile.size() < hostile_before and op.objectives[7].owner == "hostile",
		"Cutoff isolates without claiming territory")
	check(op.disrupted.has(7) and op.effort >= Rules.warzone_tuning.operation_effort
		and op.clock_ms > start_clock, "Sabotage consumes time and changes the strategic ledger")
	var prior: int = op.effort
	check(not state.warzone_operate(State.Warzone.HOSTILE_GROUPS + 7, "sabotage")
		and op.effort == prior, "Operations cannot be farmed")
	var malformed := Store.encode(state)
	malformed.warzone.lattice.links = []
	check(Store.new().decode(malformed, state.rules) == null, "A disconnected stored lattice is rejected")
	var restored := roundtrip(state)
	if restored != null:
		for pass_index in 3:
			state.wait_in_warzone()
			restored.wait_in_warzone()
		check(JSON.stringify(Store.encode(state)) == JSON.stringify(Store.encode(restored)), "Simulation remains deterministic after Continue")


func supply_combat() -> void:
	var baseline := fresh(19, 1)
	var cutoff := fresh(19, 1)
	var index := Sector.HOSTILE_ROOT
	var op: RefCounted = cutoff.warzone
	var order: Dictionary = op.operations(index, cutoff.salvage).front()
	op.operate(index, order)
	baseline.wait_in_warzone()
	cutoff.wait_in_warzone()
	check(op.fleets[0].strength > baseline.warzone.fleets[0].strength,
		"Disrupting hostile supply improves actual allied combat survival")
	for fleet in op.fleets:
		check(fleet.destination == fleet.at or fleet.destination in Sector.Lattice.neighbors(fleet.at, op.links),
			"Autonomous fleet orders use only neighboring lattice waypoints")


func fleet_routing_and_convoys() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var convoy_origin: Vector3 = op.convoy_position()
	state.wait_in_warzone()
	check(not op.convoy.is_empty() and not op.convoy_position().is_equal_approx(convoy_origin),
		"The convoy advances along its supplied route")
	var protected_contact: int = op.fleets[2].engaged
	op.objectives[4].owner = "allied"
	op._refresh_supply()
	op._counterattack(4)
	check(op.fleets[2].counter_target == -1 and op.fleets[2].engaged == protected_contact,
		"An ongoing engagement keeps its target during a counterattack")
	check(op.fleets.any(func(fleet): return fleet.counter_target == 4),
		"A reachable capture draws a routed hostile counterattack")
	var fleet: Dictionary = op.fleets[0]
	fleet.at = 4
	fleet.position = op.objectives[4].position
	fleet.destination = 4
	fleet.strength = 8
	op._move_fleet(fleet)
	check(fleet.destination != 4 and fleet.destination in Sector.Lattice.neighbors(4, op.links),
		"Allied fleets advance to a neighboring frontier after a capture")


func battle_progression() -> void:
	var state := fresh(19)
	var entry := State.Defense.point(state.navigation.position)
	check(state.can_engage(0), "Opening Tier 2 engagement is reachable")
	var setup = state.prepare_battle(0)
	check(setup != null and setup.enemy_profile.enemy_rank == 1
		and setup.environment.get("friendly_support", {}).get("source") == "allied_fleet",
		"The new Tier 2 contact uses existing supported battle setup")
	var result := preload("res://scripts/combat/battle_result.gd").new()
	result.encounter_index = 0
	result.system_number = 2
	result.winner = "player"
	result.player_hull = state.hull
	result.battles_won = 1
	result.allied_support = true
	check(state.record_battle(result) and state.pending_choice == "battle_reward"
		and state.warzone.player_victories == 1 and state.warzone.effort > 0,
		"An elite lattice victory keeps card progression and awards War Effort")
	check(State.Defense.point(state.navigation.position).is_equal_approx(entry), "Battle preserves the player position")


func scenario(seed_value: int, strategy: String) -> void:
	var state := fresh(seed_value, 75 if strategy == "infrastructure" else 1)
	if strategy == "infrastructure":
		act(state, 7, "sabotage")
		act(state, 5, "sabotage")
		act(state, 3, "sabotage")
	else:
		check(act(state, 5, "raid") and act(state, 1, "repair"), "Raid funds emergency repairs")
		act(state, 8, "sabotage")
		act(state, 7, "sabotage")
	act(state, 4, "breach")
	var op: RefCounted = state.warzone
	for wait_index in 12:
		if state.can_jump(): break
		state.wait_in_warzone()
	print(strategy, ": ", op.effort, " effort, ", op.supplied, " ", op.events)
	check(state.can_jump() and op.player_victories == 0, strategy + " wins with zero direct battles")
	if state.can_jump():
		var next := roundtrip(state)
		if next != null:
			check(next.generate_system() and next.system_number == 3
				and next.warzone_outcome.effort == op.effort, "Victory survives the campaign transition")


func run() -> void:
	generation()
	logistics()
	supply_combat()
	fleet_routing_and_convoys()
	battle_progression()
	scenario(19, "infrastructure")
	scenario(27, "repair and raids")
	print("Warzone lattice: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
