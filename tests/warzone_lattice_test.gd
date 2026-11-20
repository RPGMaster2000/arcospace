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
		check(op.objectives.size() in range(9, 13) and op.controlled() in range(2, 5), "Hostile starts with majority")
		check(state.can_engage(0) and op.engagement_count() == 2, "Opening fights and accessible contact")
		check(state.enemy_profile(state.encounters[0]).enemy_rank == 1
			and state.enemy_profile(state.encounters[2]).enemy_rank == 2, "Lattice uses Tier 2 and optional Tier 3 opposition")
		check(op.supplied.allied.size() >= 2 and op.supplied.hostile.size() >= 2, "Both sides have viable supply")
		check(not state.environmental_instances.any(func(region): return region.type == "SOLAR_INTERFERENCE"), "No solar influence in the sector")
		check(op.snapshot() == fresh(seed_value).warzone.snapshot(), "Same seed reproduces geometry and deployments")
		check(roundtrip(state) != null, "Generated sector reloads")
	check(patterns.size() == Sector.Lattice.PATTERNS.size(), "All seven pattern families occur")


func graph_audit() -> void:
	var graph_shapes := {}
	var counts := {}
	var territories := {}
	var orientations := {}
	var bottleneck_maps := 0
	var length := Vector2(INF, 0)
	var playable := 0
	const SAMPLE := 512
	for seed_value in range(1, SAMPLE + 1):
		var op := Sector.new()
		op.setup_sector(Rules.warzone_tuning, 9, 1.0, seed_value, 2)
		counts[op.objectives.size()] = counts.get(op.objectives.size(), 0) + 1
		territories[op.controlled()] = true
		var side: Vector3 = op.objectives[op.root("allied")].position
		orientations[floori((atan2(side.z, side.x) + PI) * 4.0 / PI)] = true
		var degrees := []
		for index in op.objectives.size(): degrees.append(Sector.Lattice.neighbors(index, op.links).size())
		degrees.sort()
		graph_shapes[str(degrees)] = true
		if not Sector.Lattice.bottlenecks(op.objectives, op.links).is_empty(): bottleneck_maps += 1
		var clear := op.links.all(func(edge): return not Sector.Lattice._crosses(edge, op.links, op.objectives))
		var contact: float = op.fleets[0].position.distance_to(op.fleets[1].position)
		length = Vector2(minf(length.x, contact), maxf(length.y, contact))
		if clear and op.engagement_count() == 2 and op.supplied.allied.size() >= 2 and op.supplied.hostile.size() >= 5:
			# Verify an actual capture path through supplied territory before
			# consolidating a deep command. Interceptions are resolved directly
			# here, so hundreds of cases do not require full card battles.
			for fleet in op.fleets:
				if fleet.side == "hostile" and op.active(fleet): op.player_victory(fleet.id)
			op.reserve_launched[Sector.HOSTILE_RESERVE] = true
			for round_index in op.objectives.size():
				if op.complete: break
				var frontier := false
				for index in op.objectives.size():
					if op.objectives[index].owner == "allied" or not op._capture_connected(index, "allied"): continue
					var at: Vector3 = op.objectives[index].position
					op.advance(op.tuning.capture_seconds * 1000, at, at)
					frontier = true
				if not frontier: break
			if op.final_command >= 0:
				var command: Vector3 = op.objectives[op.final_command].position
				op.advance(op.tuning.consolidation_seconds * 1000, command, command)
			if op.complete: playable += 1
	print("Warzone graph audit: ", SAMPLE, " seeds · ", counts, " · ", graph_shapes.size(),
		" degree patterns · ", bottleneck_maps, " with chokepoints · frontline spacing ", length)
	check(playable == SAMPLE, "Every sampled Warzone supports opening engagements and a supplied final victory")
	check(counts.size() == 4 and territories.size() == 3 and orientations.size() == 8 and graph_shapes.size() >= 100,
		"Counts, ownership, orientation and actual graph structure vary across the seed sample")
	check(bottleneck_maps > 100 and bottleneck_maps < SAMPLE and length.y - length.x >= 5.0,
		"Chokepoints and frontline spacing vary meaningfully")


func discoveries_and_modifiers() -> void:
	var authored := 0
	var feature_count := 0
	var physical_baseline := 0
	var total := 0
	var counts := {}
	var pool := {}
	var find_state: Resource
	for seed_value in range(1, 129):
		var state := fresh(seed_value)
		var already := {}
		for index in state.encounters.size():
			var entry: Dictionary = state.encounters[index]
			var location := state.warzone_discovery(index) as Array
			if not location.is_empty():
				check(state.warzone_objective(index).is_empty() and state.warzone_fleet(index).is_empty()
					and state.Defense.point(location) == state.navigation_destination(index, Vector3.ZERO, Vector3.INF),
					"Discovery is a real navigation destination outside the lattice and fleet registries")
				if find_state == null: find_state = state
			if entry.kind != "battle": continue
			total += 1
			if state.preview_modifier(index) > 0: feature_count += 1
			if entry.modifier > 0:
				check(not already.has(entry.modifier), "Contact modifier assignments do not repeat within the sector")
				already[entry.modifier] = true
				pool[entry.modifier] = true
				authored += 1
			if State.EnvironmentData.modifier_id(State.EnvironmentData.evaluate(state, state.battle_location(index),
					state.environmental_instances, index)) > 0: physical_baseline += 1
		counts[state.encounter_positions.size()] = true
	print("Warzone encounters: ", authored, "/", total, " assigned · ", feature_count, "/", total,
		" visible including hazards · ", physical_baseline, "/", total, " physical-only")
	check(counts.size() == 4 and pool.size() == 6 and float(feature_count) / total >= 0.50
		and float(feature_count) / total <= 0.65 and feature_count > physical_baseline,
		"Discovery counts and modifier variety meet the intended distribution")
	if find_state == null: return
	var state := find_state
	var saved := roundtrip(state)
	if saved == null: return
	var index := int(state.encounter_positions.keys().front())
	var cost: int = state.rules.defense_tuning.poi_seconds
	var elapsed: int = state.warzone.clock_ms
	check(not state.resolve_approach(index, 0, 0.0), "Discoveries require the player to arrive")
	state.update_navigation_position(state.warzone_discovery(index))
	state.arrive_destination(index)
	var transaction := {}
	var approach: Resource = state.poi_approaches(index).front()
	var prior: int = state.salvage
	var valid: bool = state.resolve_approach(index, 0, 0.0, func(activity, finish):
		transaction.activity = activity
		transaction.finish = finish)
	check(valid and not transaction.is_empty() and state.warzone.clock_ms == elapsed,
		"A discovery offers the shared Strategic Time activity before spending time")
	if not valid or transaction.is_empty(): return
	transaction.activity.advance_to(cost)
	transaction.finish.call()
	check(state.warzone.clock_ms == elapsed + cost * 1000 and state.salvage == prior + approach.success.salvage - approach.salvage_cost
		and state.encounters[index].completed and not state.resolve_approach(index, 0, 0.0),
		"Existing discovery rewards and time apply exactly once")
	check(roundtrip(state) != null and state.warzone.effort == 0 and not state.can_jump(),
		"Completed discoveries persist without awarding War Effort or FTL access")
	var malformed := Store.encode(saved)
	malformed.encounter_positions[str(index)] = State.Defense.wire(saved.warzone.objectives[0].position)
	check(Store.new().decode(malformed, saved.rules) == null, "A discovery on a lattice objective is rejected")


func seed_replay() -> void:
	var a := State.new()
	var b := State.new()
	a.start(0, Rules)
	b.start(0, Rules)
	check(a.seed_used != b.seed_used, "Normal expeditions choose a fresh seed by default")
	var launch := {"mode": "warzone", "stage": 2, "rank": -1}
	a.start(0, Rules, 0, launch)
	b.start(0, Rules, 0, launch)
	check(a.seed_used != b.seed_used and a.warzone.links != b.warzone.links,
		"Developer Launch selects a fresh Warzone graph by default")
	var replay := State.new()
	replay.start(0, Rules, a.seed_used, launch)
	check(a.warzone.snapshot() == replay.warzone.snapshot() and a.encounter_positions == replay.encounter_positions
		and a.encounters == replay.encounters, "An explicit Developer Launch seed reproduces encounters, discoveries and modifiers")


func logistics() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var index: int = op.site("depot")
	var hostile_before: int = op.supplied.hostile.size()
	var start_clock: int = op.clock_ms
	check(act(state, index, "sabotage"), "A hostile depot can be sabotaged behind the front")
	check(op.supplied.hostile.size() < hostile_before and op.objectives[index].owner == "hostile",
		"Cutoff isolates without claiming territory")
	check(op.disrupted.has(index) and op.accomplishments["cut:%d" % index] <= 8
		and op.clock_ms > start_clock, "Sabotage consumes time and changes the strategic ledger")
	var prior: int = op.effort
	check(not state.warzone_operate(State.Warzone.HOSTILE_GROUPS + index, "sabotage")
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
	var op: RefCounted = cutoff.warzone
	var index: int = op.root("hostile")
	op.disrupted[index] = op.tuning.sabotage_seconds
	op._refresh_supply()
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
	var junction: int = op.site("junction")
	var protected_contact: int = op.fleets[2].engaged
	op.objectives[junction].owner = "allied"
	op._refresh_supply()
	op._counterattack(junction)
	check(op.fleets[2].counter_target == -1 and op.fleets[2].engaged == protected_contact,
		"An ongoing engagement keeps its target during a counterattack")
	check(op.fleets.any(func(fleet): return fleet.counter_target == junction),
		"A reachable capture draws a routed hostile counterattack")
	var fleet: Dictionary = op.fleets[0]
	fleet.at = junction
	fleet.position = op.objectives[junction].position
	fleet.destination = junction
	fleet.strength = 8
	op._move_fleet(fleet)
	check(fleet.destination != junction and op.route_valid(fleet.side, junction, fleet.destination),
		"Allied fleets advance to a connected frontier after a capture")


func battle_progression() -> void:
	var state := fresh(19)
	var entry := State.Defense.point(state.navigation.position)
	check(state.can_engage(0), "Opening Tier 2 engagement is reachable")
	var preview: int = state.preview_modifier(0)
	var setup = state.prepare_battle(0)
	check(setup != null and setup.enemy_profile.enemy_rank == 1 and setup.modifier == preview
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


func facilities() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var repair: int = op.site("repair")
	var command: int = op.root("allied")
	var relay: int = op.site("relay")
	for site in op.objectives.size():
		check(op.operations(site, 100).size() == 1, "Each installation quotes exactly one signature operation")
	check(not op.operations(op.root("hostile"), 100).front().enabled, "Hostile command cannot direct allied fleets")
	check(not op.operations(repair, 0).front().enabled, "Repair Dock enforces its Salvage cost")
	check(not op.operations(repair, 20).front().enabled, "Undamaged fleets cannot buy repairs")
	op.fleets[0].strength -= 5
	op.fleets[1].strength -= 1
	check(act(state, repair, "repair"), "Repair Dock restores the weakest allied formation")
	check(op.facility_cooldowns.has(repair) and not op.facility_cooldowns.has(command)
		and not op.operations(repair, 20).front().enabled, "Recharge is local to the facility instance")
	var cooling: int = op.facility_cooldowns[repair]
	var restored := roundtrip(state)
	if restored != null:
		check(restored.warzone.facility_cooldowns[repair] == cooling, "Save preserves the exact remaining recharge")
		restored.wait_in_warzone()
		check(restored.warzone.facility_cooldowns[repair] == cooling - 1, "One-second Wait spends one recharge second")
	var start_effort: int = op.effort
	check(act(state, relay, "jam") and op.jam_until > op.clock_ms and not op.disrupted.has(relay),
		"Communications jamming delays orders without severing the supply graph")
	check(op.effort == start_effort, "Facility activation alone grants no War Effort")
	check(roundtrip(state) != null, "Active communications disruption persists")
	var deploy := fresh(19)
	var sector: RefCounted = deploy.warzone
	var yard: int = sector.site("shipyard")
	sector.objectives[yard].owner = "allied"
	var edge := _edge(sector.root("allied"), yard)
	if edge not in sector.links: sector.links.append(edge)
	sector._refresh_supply()
	check(act(deploy, yard, "deploy") and sector.fleets[Sector.ALLIED_RESERVE].arriving,
		"Supplied Shipyard dispatches an off-map allied reserve")
	check(not sector.can_deploy_allied() and roundtrip(deploy) != null, "Shipyard cannot exceed the fleet cap")


func facility_effects() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var root: int = op.root("allied")
	var fort: int = op.site("outpost")
	var depot: int = op.site("depot")
	var command: Dictionary = op.operations(root, 20).front()
	check(command.enabled, "Supplied command can coordinate a reachable offensive")
	op.operate(root, command)
	var allied: Dictionary = op.fleets[0]
	var hostile: Dictionary = op.fleets[2]
	allied.position = op.objectives[op.offensive_target].position
	var boosted: int = op._shot_damage(allied)
	op.offensive_until = 0
	check(boosted == op._shot_damage(allied) + 1, "Coordinated volleys change strategic attrition")
	op.objectives[fort].owner = "allied"
	var edge := _edge(root, fort)
	if edge not in op.links: op.links.append(edge)
	op._refresh_supply()
	var fortify: Dictionary = op.operations(fort, 20).front()
	allied.position = op.objectives[fort].position
	hostile.engaged = allied.id
	var unfortified: int = op._shot_damage(hostile)
	op.operate(fort, fortify)
	check(op._shot_damage(hostile) == unfortified - 1, "Fortifications mitigate hostile volleys at their own site")
	op.facility_cooldowns.erase(fort)
	check(op._shot_damage(hostile) == unfortified, "Expired fortifications stop mitigating volleys")
	var cut: Dictionary = op.operations(depot, 20).front()
	op.operate(depot, cut)
	var reward: int = op.effort
	op.facility_cooldowns.erase(depot)
	op.disrupted.clear()
	op._refresh_supply()
	op.operate(depot, op.operations(depot, 20).front())
	check(reward > 0 and op.effort == reward, "Recharged logistics disruption cannot pay the same cutoff twice")
	var recovery := fresh(19, 1)
	for fleet in recovery.warzone.fleets:
		if fleet.side == "allied": fleet.strength = 0
	recovery.salvage = 0
	check(act(recovery, recovery.warzone.site("repair"), "repair") and recovery.warzone.fleet_count("allied") > 0,
		"An emergency recovery is possible after a rout with no Salvage")


func approach(state: Resource, site: int) -> void:
	var op: RefCounted = state.warzone
	var from := State.Defense.point(state.navigation.position)
	var to: Vector3 = op.objectives[site].position
	state.advance_warzone_map(from.distance_to(to) / state.rules.defense_tuning.player_speed, from, to)
	if not op.complete:
		state.update_navigation_position(State.Defense.wire(to))
		travel(state, site)


func scenario(seed_value: int, strategy: String) -> void:
	var state := fresh(seed_value, 75)
	var op: RefCounted = state.warzone
	var visited := {}
	var clock_before_visit := 0
	for round_index in 12:
		if op.complete: break
		var route := ["relay", "depot", "shipyard", "repair", "allied_command"] if strategy == "infrastructure" \
			else ["allied_command", "repair", "outpost", "relay", "depot", "shipyard"]
		for role in ["west_hub", "east_hub"]:
			if op.site(role) >= 0: route.append(role)
		for role in route:
			var site: int = op.site(role)
			if op.complete: break
			if strategy == "infrastructure" and round_index == 0 and role == "allied_command": continue
			var action: Dictionary = op.operations(site, state.salvage).front()
			if not action.enabled: continue
			approach(state, site)
			if not op.complete and state.warzone_operate(site + State.Warzone.HOSTILE_GROUPS, action.id):
				visited[site] = true
		if op.complete: break
		var targets: Array = range(op.objectives.size())
		targets.sort_custom(func(a, b): return op.role_index(a) < op.role_index(b))
		if op.final_command >= 0:
			targets.erase(op.final_command)
			targets.push_front(op.final_command)
		for site in targets:
			var eligible: bool = op._capture_connected(site, "allied") and op.objectives[site].owner != "allied"
			var defended: bool = op.fleets.any(func(fleet): return fleet.side == "hostile" and op.active(fleet) \
				and not fleet.withdrawing and fleet.position.distance_to(op.objectives[site].position) <= op.tuning.objective_radius)
			if (eligible and not defended) or site == op.final_command:
				approach(state, site)
				visited[site] = true
				break
		state._commit_activity_time(16)
		clock_before_visit = op.clock_ms
	print(strategy, ": ", op.effort, " effort, ", visited.size(), " locations, ", clock_before_visit / 1000, "s, ", op.events)
	check(state.can_jump() and op.player_victories == 0, strategy + " wins with zero direct battles")
	check(visited.size() >= 4, strategy + " uses multiple strategic locations")
	if state.can_jump():
		check(op.final_command in op.command_sites() and op._command_ready(), "Victory requires a supplied deep command")
		var next := roundtrip(state)
		if next != null:
			check(next.generate_system() and next.system_number == 3
				and next.warzone_outcome.effort == op.effort, "Victory survives the campaign transition")


func final_offensive() -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var away := Vector3(25, 0, 25)
	op._award("fixture", 50, "Opening gains")
	op._award("fixture:2", 10, "Second gains")
	op.objectives[op.site("junction")].owner = "allied"
	op._refresh_supply()
	op.advance(20000, away, away)
	check(op.final_command == -1 and not op.complete, "NPC-only War Effort cannot end the operation")
	op.player_intervened = true
	op._update_final_offensive(true)
	check(op.final_command in op.command_sites() and op.consolidation == 0, "War Effort unlocks a deep command offensive")
	if roundtrip(state) == null: return
	for site in op.objectives.size():
		op.objectives[site].owner = "allied"
	op._refresh_supply()
	op._update_final_offensive(true)
	check(op.consolidation == 1, "Consolidation starts only with supplied control")
	op.disrupted[op.final_command] = 5
	op._refresh_supply()
	op._update_final_offensive(true)
	check(op.consolidation == 0 and not op.complete, "A cutoff interrupts final consolidation")


func _edge(a: int, b: int) -> Vector2i:
	return Vector2i(mini(a, b), maxi(a, b))


func capture_cutoff(side: String) -> void:
	var state := fresh(19)
	var op: RefCounted = state.warzone
	var site: int = op.site("junction")
	var left: int = op.site("repair")
	var right: int = op.site("outpost")
	var origin: int = op.root(side)
	var other: int = op.root("hostile") if side == "allied" else op.root("allied")
	var owner := "hostile" if side == "allied" else "allied"
	op.links.assign([_edge(origin, left), _edge(origin, right), _edge(left, site), _edge(right, site), _edge(other, origin)])
	for node in op.objectives.size():
		if node not in [origin, other, left, right, site]: op.links.append(_edge(other, node))
	op.objectives[left].owner = side
	op.objectives[right].owner = side
	op.objectives[site].owner = owner
	state.encounter_positions.clear()
	state.encounters.resize(State.Warzone.HOSTILE_GROUPS + op.objectives.size() + 1)
	op.convoy.clear()
	for fleet in op.fleets:
		fleet.strength = 0
		fleet.engaged = -1
	var attacker_id := 0 if side == "allied" else 2
	var attacker: Dictionary = op.fleets[attacker_id]
	attacker.strength = 4
	attacker.at = left
	attacker.destination = site
	attacker.position = op.objectives[site].position
	var absent := Vector3(300, 0, 300)
	op.note_player_position(absent)
	op._refresh_supply()
	op._capture(site, absent)
	op._capture(site, absent)
	check(op.objectives[site].progress == 2, side + " begins capture through supplied routes")
	op.disrupted[left] = 5
	op._refresh_supply()
	check(op.objectives[site].progress == 2, side + " retains progress through an alternate supplied route")
	op.disrupted[right] = 5
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
	attacker.position = op.objectives[left].position
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
	var origin: int = op.root("allied")
	var mid: int = op.site("repair")
	var goal: int = op.site("junction")
	op.links.assign([_edge(origin, mid), _edge(mid, goal)])
	op.objectives[mid].position = Vector3(0, 0, 10)
	op.objectives[origin].position = Vector3.ZERO
	op.objectives[goal].position = Vector3(10, 0, 0)
	var fleet: Dictionary = op.fleets[0]
	fleet.at = origin
	fleet.destination = origin
	fleet.position = Vector3.ZERO
	op._refresh_supply()
	op._move_fleet(fleet)
	check(fleet.destination == goal and fleet.position.x > 0.5 and is_zero_approx(fleet.position.z),
		"Fleet flies directly to a connected target beyond an intermediate node")
	var position: Vector3 = fleet.position
	op.disrupted[mid] = 5
	op._refresh_supply()
	op._move_fleet(fleet, 0.1)
	check(fleet.destination == origin and fleet.position.x < position.x,
		"A severed route immediately redirects the ship without snapping")
	op.disrupted.clear()
	op.objectives[mid].owner = "hostile"
	op._refresh_supply()
	check(not op.route_valid(fleet.side, origin, goal), "Ownership changes also invalidate direct orders")


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
	op.disrupted[op.root("hostile")] = 45
	op._refresh_supply()
	state._commit_activity_time(31)
	var allied: Dictionary = op.fleet_at(Sector.ALLIED_RESERVE)
	var hostile: Dictionary = op.fleet_at(Sector.HOSTILE_RESERVE)
	check(op.active(allied) and not op.active(hostile), "A severed supply root delays its reinforcements only")
	var from: Vector3 = hostile.position
	op.disrupted.clear()
	op._refresh_supply()
	state._commit_activity_time(2)
	check(op.active(hostile) and hostile.position.distance_to(op.objectives[op.root("hostile")].position)
		< from.distance_to(op.objectives[op.root("hostile")].position), "Restored supply admits a moving hostile wave")
	var encounter: int = op.encounter_for_fleet(hostile)
	check(state.can_visit(encounter) and not state.encounters[encounter].completed
		and state.warzone_fleet(encounter).id == hostile.id, "Hostile reserve opens its own interceptable contact")
	check(op.reserve_launched.size() == 2 and roundtrip(state) != null, "Bounded reinforcements persist without respawning")


func historical_roster() -> void:
	var state := fresh(19)
	while state.warzone.objectives.size() != 12:
		state = fresh(state.seed_used + 1)
	var historical := Store.encode(state)
	var lattice: Dictionary = historical.warzone.lattice
	var order: Array = lattice.roles
	var canonical := func(index): return Sector.Lattice.ROLES.find(order[int(index)])
	var objectives := []
	objectives.resize(order.size())
	var encounters: Array = historical.encounters.slice(0, State.Warzone.HOSTILE_GROUPS)
	encounters.resize(State.Warzone.HOSTILE_GROUPS + order.size())
	for index in order.size():
		objectives[canonical.call(index)] = historical.warzone.objectives[index]
		encounters[State.Warzone.HOSTILE_GROUPS + canonical.call(index)] = historical.encounters[State.Warzone.HOSTILE_GROUPS + index]
	historical.warzone.objectives = objectives
	historical.encounters = encounters
	historical.encounter_positions = {}
	lattice.links = lattice.links.map(func(edge):
		var a: int = canonical.call(edge[0])
		var b: int = canonical.call(edge[1])
		return [mini(a, b), maxi(a, b)])
	lattice.version = 2
	lattice.pattern = mini(5, lattice.pattern)
	lattice.erase("roles")
	lattice.erase("reserve_launched")
	lattice.erase("capture_cutoffs")
	lattice.convoy.clear()
	historical.warzone.fleets.resize(Sector.ALLIED_RESERVE)
	for fleet in historical.warzone.fleets:
		fleet.at = canonical.call(fleet.at)
		fleet.destination = canonical.call(fleet.destination)
	var restored := Store.new().decode(JSON.parse_string(JSON.stringify(historical)), state.rules)
	check(restored != null and not restored.warzone.has_reserves() and restored.warzone.root("hostile") == 7,
		"Version 2 lattice saves retain their original roles, roster and encounter indices")


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
	graph_audit()
	discoveries_and_modifiers()
	seed_replay()
	logistics()
	supply_combat()
	fleet_routing_and_convoys()
	battle_progression()
	scenario(19, "infrastructure")
	scenario(27, "fleet support")
	facilities()
	facility_effects()
	final_offensive()
	print("Warzone lattice: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
