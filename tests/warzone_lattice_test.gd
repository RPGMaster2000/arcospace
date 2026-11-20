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
	for second in baseline.warzone.tuning.exchange_seconds:
		baseline.wait_in_warzone()
		cutoff.wait_in_warzone()
	check(op.fleets[0].strength > baseline.warzone.fleets[0].strength,
		"Disrupting hostile supply improves actual allied combat survival")
	for fleet in op.fleets:
		check(fleet.withdrawing or fleet.engaged >= 0 or op.route_valid(fleet.side, fleet.at, fleet.destination),
			"Autonomous fleet orders remain backed by usable lattice routes")


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
	check(fleet.destination != 4 and op.route_valid(fleet.side, 4, fleet.destination),
		"Allied fleets advance to a connected frontier after a capture")


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
	for wait_index in 72:
		if state.can_jump(): break
		state.wait_in_warzone()
	print(strategy, ": ", op.effort, " effort, ", op.supplied, " ", op.events)
	check(state.can_jump() and op.player_victories == 0, strategy + " wins with zero direct battles")
	if state.can_jump():
		var next := roundtrip(state)
		if next != null:
			check(next.generate_system() and next.system_number == 3
				and next.warzone_outcome.effort == op.effort, "Victory survives the campaign transition")


func _edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


func capture_cutoff(side: String) -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var site := 4
	var origin := Sector.ALLIED_ROOT if side == "allied" else Sector.HOSTILE_ROOT
	var other := Sector.HOSTILE_ROOT if side == "allied" else Sector.ALLIED_ROOT
	var owner := "hostile" if side == "allied" else "allied"
	op.links.assign([_edge(origin, 0), _edge(origin, 2), _edge(0, site), _edge(2, site), _edge(other, origin)])
	for node in op.objectives.size():
		if node not in [origin, other, 0, 2, site]: op.links.append(_edge(other, node))
	op.objectives[0].owner = side
	op.objectives[2].owner = side
	op.objectives[site].owner = owner
	op.convoy.clear()
	for fleet in op.fleets:
		fleet.strength = 0
		fleet.engaged = -1
	var attacker_id := 0 if side == "allied" else 2
	var attacker: Dictionary = op.fleets[attacker_id]
	attacker.strength = 4
	attacker.at = 0
	attacker.destination = site
	attacker.position = op.objectives[site].position
	var absent := Vector3(300, 0, 300)
	op.note_player_position(absent)
	op._refresh_supply()
	op._capture(site, absent)
	op._capture(site, absent)
	check(op.objectives[site].progress == 2, side + " begins capture through supplied routes")
	op.disrupted[0] = 5
	op._refresh_supply()
	check(op.objectives[site].progress == 2, side + " retains progress through an alternate supplied route")
	op.disrupted[2] = 5
	op._refresh_supply()
	check(op.objectives[site].progress == 0 and op.objectives[site].capturing == "neutral"
		and op.objectives[site].owner == owner and op.capture_cutoffs.has(site),
		side + " cutoff immediately resets progress and preserves ownership")
	var opponent: Dictionary = op.fleets[2 if side == "allied" else 0]
	opponent.strength = 4
	opponent.position = attacker.position + Vector3(1.0, 0, 0)
	op._assign_engagements()
	check(attacker.engaged == opponent.id, side + " fleets may still fight at the disconnected objective")
	opponent.strength = 0
	op._assign_engagements()
	state._sync_warzone()
	var restored := roundtrip(state)
	if restored == null: return
	op = restored.warzone
	op.disrupted.clear()
	op._refresh_supply()
	op._capture(site, absent)
	check(op.objectives[site].progress == 0, side + " restored supply cannot restart the same interrupted capture")
	attacker = op.fleets[attacker_id]
	attacker.position = op.objectives[0].position
	op._capture(site, absent)
	attacker.position = op.objectives[site].position
	op._capture(site, absent)
	check(op.objectives[site].progress == 1, side + " can start a fresh capture after re-entering")
	for second in range(1, op.tuning.capture_seconds):
		op._capture(site, absent)
	op.disrupted[origin] = 5
	op._refresh_supply()
	check(op.objectives[site].owner == side and op.objectives[site].progress == 0,
		side + " ownership survives a cutoff after capture completes")


func direct_movement() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	op.links.assign([Vector2i(0, 1), Vector2i(0, 4)])
	op.objectives[0].position = Vector3(0, 0, 10)
	op.objectives[1].position = Vector3.ZERO
	op.objectives[4].position = Vector3(10, 0, 0)
	var fleet: Dictionary = op.fleets[0]
	fleet.at = 1
	fleet.destination = 1
	fleet.position = Vector3.ZERO
	op._refresh_supply()
	op._move_fleet(fleet)
	check(fleet.destination == 4 and fleet.position.x > 0.5 and is_zero_approx(fleet.position.z),
		"Fleet flies directly to a connected target beyond an intermediate node")
	var position: Vector3 = fleet.position
	op.disrupted[0] = 5
	op._refresh_supply()
	op._move_fleet(fleet, 0.1)
	check(fleet.destination == 1 and fleet.position.x < position.x,
		"A severed route immediately redirects the ship without snapping")
	op.disrupted.clear()
	op.objectives[0].owner = "hostile"
	op._refresh_supply()
	check(not op.route_valid(fleet.side, 1, 4), "Ownership changes also invalidate direct orders")


func reinforces_and_forecasts() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var forecasts: Dictionary = op.engagement_predictions()
	check(forecasts.has(2) and forecasts[2].seconds > 0, "Active engagement has a positive resolution estimate")
	op.fleets[2].strength = 2
	var changed: Dictionary = op.engagement_predictions()[2]
	check(changed.allied_share > forecasts[2].allied_share and changed.seconds < forecasts[2].seconds,
		"Estimated odds and time respond to real attrition")
	var bounds := Sector.Layout.bounds(state.layout_expansion)
	for id in [Sector.ALLIED_RESERVE, Sector.HOSTILE_RESERVE]:
		var reserve: Dictionary = op.fleet_at(id)
		var at: Vector3 = reserve.position
		check(not bounds.has_point(Vector2(at.x, at.z)) and not op.active(reserve),
			"Each reserve starts dormant beyond the navigable boundary")
	op.disrupted[Sector.HOSTILE_ROOT] = 45
	op._refresh_supply()
	state._commit_activity_time(31)
	var allied: Dictionary = op.fleet_at(Sector.ALLIED_RESERVE)
	var hostile: Dictionary = op.fleet_at(Sector.HOSTILE_RESERVE)
	check(op.active(allied) and not op.active(hostile), "A severed supply root delays its reinforcements only")
	var from: Vector3 = hostile.position
	op.disrupted.clear()
	op._refresh_supply()
	state._commit_activity_time(2)
	check(op.active(hostile) and hostile.position.distance_to(op.objectives[Sector.HOSTILE_ROOT].position)
		< from.distance_to(op.objectives[Sector.HOSTILE_ROOT].position), "Restored supply admits a moving hostile wave")
	var encounter: int = op.encounter_for_fleet(hostile)
	check(state.can_visit(encounter) and not state.encounters[encounter].completed
		and state.warzone_fleet(encounter).id == hostile.id, "Hostile reserve opens its own interceptable contact")
	check(op.reserve_launched.size() == 2 and roundtrip(state) != null, "Bounded reinforcements persist without respawning")


func historical_roster() -> void:
	var state := fresh(19)
	var historical := Store.encode(state)
	historical.warzone.fleets.resize(Sector.ALLIED_RESERVE)
	historical.encounters.pop_back()
	historical.warzone.lattice.erase("reserve_launched")
	historical.warzone.lattice.erase("capture_cutoffs")
	var restored := Store.new().decode(JSON.parse_string(JSON.stringify(historical)), state.rules)
	check(restored != null and not restored.warzone.has_reserves(),
		"Existing lattice saves retain their original roster and encounter indices")


func continuous_clock() -> void:
	var slow := fresh(19)
	var fast := fresh(19)
	var origin := State.Defense.point(slow.navigation.position)
	var target := origin + Vector3(10.0, 0.0, 6.0)
	for state in [slow, fast]:
		var partitions := 30 if state == slow else 144
		for frame in partitions:
			var from := origin.lerp(target, float(frame) / partitions)
			var to := origin.lerp(target, float(frame + 1) / partitions)
			state.advance_warzone_map(3.25 / partitions, from, to)
	check(slow.warzone.snapshot() == fast.warzone.snapshot(), "Same movement and combat at different frame rates")
	var start_clock: int = slow.warzone.clock_ms
	slow.begin_free_travel(State.Defense.wire(target))
	slow.navigation.report_movement(State.Defense.wire(target))
	var before: int = slow.warzone.clock_ms
	var expected := floori(origin.distance_to(target) * 1000.0 / slow.rules.defense_tuning.player_speed)
	check(absi(before - start_clock - expected) <= 1, "Travel charges exactly the elapsed motion at the ship's speed")
	slow.navigation.report_movement(State.Defense.wire(target))
	check(slow.warzone.clock_ms == before, "Repeated stationary samples spend no time")
	slow.cancel_travel()
	slow.active_battle = 0
	slow.advance_warzone_map(0.5, target, target)
	check(slow.warzone.clock_ms == before, "An active card battle blocks live strategic time")
	slow.active_battle = -1
	check(slow.wait_in_warzone() and slow.warzone.clock_ms == before + slow.warzone.tuning.wait_seconds * 1000,
		"Explicit waiting advances exactly its quoted strategic time")
	var restored := roundtrip(slow)
	if restored != null:
		slow.advance_warzone_map(0.75, target, target)
		restored.advance_warzone_map(0.75, target, target)
		check(slow.warzone.snapshot() == restored.warzone.snapshot(), "Resume from a fractional tick continues identically")


func run() -> void:
	direct_movement()
	capture_cutoff("allied")
	capture_cutoff("hostile")
	reinforces_and_forecasts()
	historical_roster()
	continuous_clock()
	generation()
	logistics()
	supply_combat()
	fleet_routing_and_convoys()
	battle_progression()
	scenario(19, "infrastructure")
	scenario(27, "repair and raids")
	print("Warzone lattice: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
