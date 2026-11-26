extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Moving = preload("res://scripts/expedition/moving_poi.gd")
const Result = preload("res://scripts/combat/battle_result.gd")
const Contact = preload("res://tests/fixtures/expedition_contact.gd")
var checks := 0
var failures := 0


func check(condition: bool, description: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	if failures < 30: push_error(description)


func launch(stage: int, seed_value: int, overrides := {}, simulation_fixture := false) -> Resource:
	var rules := Rules.duplicate()
	rules.log_rolls = false
	if simulation_fixture:
		rules.defense_tuning = Rules.defense_tuning.duplicate()
		rules.defense_tuning.pressure_per_second = 0.0
	var state := State.new()
	var options := {"mode":"defense", "stage":stage, "rank":-1}
	options.merge(overrides, true)
	state.start(0, rules, seed_value, options)
	return state


func reload_run(run: Resource) -> Resource:
	return Save.new().decode(State.SystemVariation.canonical(Save.encode(run)), run.rules)


func advance(run: Resource, seconds: float, carry := true) -> Dictionary:
	var player: Vector3 = run.defense.start
	return run._advance_strategy(seconds, player, player, carry, false)


func generation() -> void:
	check(launch(1, 5).defense.convoy == null, "Introductory Starfront has no convoy")
	check(launch(2, 5, {"mode":"warzone"}).defense == null, "Warzone has no Starfront state")
	var missing := 0
	var bent := 0
	var minimum_eta := INF
	var formations := {}
	var factions := {}
	var opening := [0, 0, 0]
	for stage in [3, 4, 5]:
		for seed_value in range(1, 181):
			var run := launch(stage, seed_value)
			var fleet: RefCounted = run.defense
			var convoy: RefCounted = fleet.convoy
			check(convoy != null, "Evacuation generated for %d/%d" % [stage, seed_value])
			if convoy == null:
				missing += 1
				continue
			formations[fleet.military.formation] = true
			factions[run.faction_id] = true
			check(convoy.maximum_integrity == 40 and convoy.integrity == 40 and convoy.speed == 0.7, "Default convoy tuning")
			check(convoy.remaining_seconds() >= 35.0 and convoy.remaining_seconds() <= 55.0, "Evacuation duration")
			check(convoy.route.front().distance_to(fleet.home) > 4.6 and convoy.destination().distance_to(fleet.home) >= 16.0, "Separate departure and extraction")
			check(convoy.pursuers.size() > 0 and 2 * convoy.pursuers.size() < fleet.active_attackers(), "Opening threats leave the majority on Homeworld")
			opening[convoy.pursuers.size()] += 1
			bent += int(convoy.route.size() > 2)
			for i in range(1, convoy.route.size()):
				check(State.SystemLayout.navigable(convoy.route[i], run.layout_expansion), "Convoy waypoint inside navigation bounds")
				check(State.SystemLayout.clear_stellar_segment(convoy.route[i - 1], convoy.route[i], fleet.stellar_clearance()), "Convoy leg clears stellar core")
			for index in convoy.pursuers:
				var enemy: Dictionary = fleet.unit_for(index)
				var eta: float = convoy.pursuit_time(enemy.position, fleet._speed(enemy))
				minimum_eta = minf(eta, minimum_eta)
				var response: float = fleet.start.distance_to(fleet.intercept_point(index, fleet.start)) * fleet.tuning.seconds_per_distance
				check(not enemy.mothership and fleet.target_kind(enemy) == "convoy" and response + fleet.tuning.battle_seconds < eta, "Player can intercept each initial pursuer")
			if seed_value <= 8:
				for unit in fleet.units:
					if unit.mothership or unit.reinforcement: continue
					var approach := reload_run(run)
					check(approach != null and Contact.reach(approach, unit.encounter),
						"Opening attacker %d remains reachable with convoy active in %d/%d" % [unit.encounter, stage, seed_value])
			if seed_value <= 4 or convoy.route.size() > 2:
				var copy := reload_run(run)
				check(copy != null and copy.defense.convoy.snapshot() == convoy.snapshot(), "Committed route and pursuers survive JSON save")
				check(launch(stage, seed_value).defense.convoy.snapshot() == convoy.snapshot(), "Independent RNG reproduces committed convoy")
	check(formations.size() == 5 and factions.size() == 4, "All doctrines and factions represented")
	check(launch(5, 7, {"convoy_integrity":20, "convoy_force_pursuit":true}).defense.convoy.integrity == 20, "Developer override sets starting integrity")
	print("CONVOY_GENERATION ", JSON.stringify({"systems":540,"missing":missing,"bent":bent,"opening":opening,"min_pursuit_eta":minimum_eta}))


func movement() -> void:
	var moving := Moving.new()
	moving.route.assign([Vector3(8,0,8), Vector3(15,0,8), Vector3(15,0,15)])
	moving.speed = 0.7
	moving.travel_span(5)
	check(moving.position().is_equal_approx(Vector3(11.5,0,8)) and is_equal_approx(moving.leg_seconds(), 5.0), "Uniform strategic speed")
	var copy := Moving.new()
	check(copy.restore_route(moving.route_snapshot(), 1.0) and copy.position() == moving.position(), "Persist partial waypoint progress")
	moving.travel_span(5)
	check(not moving.finish_leg() and moving.velocity().is_equal_approx(Vector3(0,0,0.7)), "Waypoint changes heading")
	moving.travel_span(10)
	check(moving.finish_leg() and moving.position() == moving.destination(), "Finish at exact endpoint")
	var eta := Moving.meeting_time(Vector3(20,0,0), Vector3(0.7,0,0), 2.0, 2.5)
	check(is_equal_approx(eta, 17.5 / 1.3), "Closed-form contact against a moving target")
	var whole := launch(5, 8)
	var slices := launch(5, 8)
	var before: Vector3 = slices.defense.convoy.position()
	check(advance(slices, 0.0).elapsed == 0 and slices.defense.convoy.position() == before, "Zero strategic time leaves convoy stationary")
	advance(whole, 48)
	for i in 192: advance(slices, 0.25)
	var large: RefCounted = whole.defense.convoy
	var small: RefCounted = slices.defense.convoy
	check(large.activity == small.activity and large.integrity == small.integrity and large.attackers == small.attackers, "Swept outcomes invariant under step size")
	check(large.position().distance_to(small.position()) < 0.001 and is_equal_approx(whole.defense.pressure, slices.defense.pressure), "Split clocks agree within precision")


func controlled() -> Resource:
	var run := launch(5, 8, {}, true)
	run.defense.reinforcement_remaining = 60.0
	return run


func position_strike(run: Resource, offset: Vector3, count: int) -> Array[int]:
	var fleet: RefCounted = run.defense
	var convoy: RefCounted = fleet.convoy
	var available: Array = fleet.units.filter(func(unit): return fleet.available(unit) and not unit.mothership and not convoy.attackers.has(unit.encounter))
	var ids: Array[int] = []
	for i in count:
		var unit: Dictionary = available[i]
		unit.position = convoy.position() + offset
		ids.append(unit.encounter)
	convoy.pursuers.assign(ids)
	return ids


func outcomes() -> void:
	var run := controlled()
	var fleet: RefCounted = run.defense
	var convoy: RefCounted = fleet.convoy
	var initial_salvage: int = run.salvage
	var ids := position_strike(run, Vector3.ZERO, 1)
	advance(run, 0.1)
	check(convoy.integrity == 20 and convoy.attackers == ids and run.salvage == initial_salvage, "A convoy attack consumes its enemy without granting a reward")
	check(run.encounters[ids.front()].resolution == "convoy_strike" and run.encounters[ids.front()].completed, "Spent attacker is resolved")
	advance(run, 0.1)
	check(convoy.integrity == 20 and fleet.integrity == fleet.tuning.base_integrity, "Spent attacker cannot strike again or damage Homeworld")
	var restored := reload_run(run)
	check(restored != null and restored.defense.convoy.attackers == ids, "Save remembers first contact")
	var original_count: int = run.encounters.size()
	fleet.pressure = fleet.reveal_threshold() - 10
	position_strike(run, Vector3.ZERO, 1)
	var loss := advance(run, 0.1)
	check(convoy.activity == "destroyed" and convoy.integrity == 0 and fleet.revealed and loss.revealed, "Loss causes immediate reveal from pressure")
	check(is_equal_approx(fleet.pressure, fleet.reveal_threshold() + 10) and run.salvage == initial_salvage, "Loss applies exactly 20 Pressure and no evacuation money")
	check(run.encounters.size() == original_count + 1 and fleet.ship_profile(fleet.unit_for(convoy.punitive_index)).enemy_rank == 1, "Exactly one genuine elite is queued")
	check(not run.can_jump() and fleet._punitive_pending(), "Queued elite is mandatory")
	restored = reload_run(run)
	check(restored != null and restored.defense.convoy.punitive_index == convoy.punitive_index, "Pending elite and timer survive save")
	fleet.neutralize(fleet.mothership_index())
	run.encounters[fleet.mothership_index()].completed = true
	advance(run, 5.8)
	check(fleet._punitive_pending(), "Elite remains queued until its six-second delay")
	advance(run, 0.2)
	var punitive: Dictionary = fleet.unit_for(convoy.punitive_index)
	check(fleet.available(punitive) and not fleet.mothership_advancing and fleet.missiles.active.is_empty(), "Elite deploys after mothership defeat without restarting escalation")
	check(fleet.reinforcements_spawned == 0 and run.encounters.size() == original_count + 1, "Punitive launch leaves ordinary budget intact")
	var hp: int = fleet.integrity
	punitive.position = fleet.target_for(punitive)
	advance(run, 0.2)
	check(fleet.available(punitive) and punitive.get("holding", false) and hp - fleet.integrity == 20, "Elite lands one strike and remains a mandatory active contact")
	hp = fleet.integrity
	advance(run, 0.2)
	check(fleet.integrity == hp and not run.can_jump(), "Stationary punitive contact cannot damage Homeworld twice")
	for reserved in fleet.units:
		if reserved.status == "secured": run.encounters[reserved.encounter].completed = true
	var settled := reload_run(run)
	check(settled != null and settled.defense.unit_for(convoy.punitive_index).get("holding", false) and not settled.can_jump()
		and settled.defense.integrity == hp, "Stationary mandatory contact and damage survive resume")
	for unit in fleet.units:
		if unit.status == "active" and not unit.get("punitive", false):
			fleet.neutralize(unit.encounter)
			run.encounters[unit.encounter].completed = true
	check(not fleet.complete, "Mothership and ordinary threats cleared still do not unlock FTL")
	var reward := Result.new()
	run.active_battle = convoy.punitive_index
	fleet.contact = run.active_battle
	reward.result_id = 82
	reward.encounter_index = run.active_battle
	reward.system_number = run.system_number
	reward.winner = "player"
	reward.player_hull = run.hull
	reward.escaped_by_ftl = true
	check(run.record_battle(reward) and fleet.complete, "Existing EMP neutralization resolves the mandatory elite")


func victory(run: Resource, index: int, escaped := false) -> Result:
	var report := Result.new()
	run.active_battle = index
	run.defense.contact = index
	report.result_id = index + 1
	report.encounter_index = index
	report.system_number = run.system_number
	report.winner = "player"
	report.player_hull = run.hull
	report.escaped_by_ftl = escaped
	return report if run.record_battle(report) else null


func decoys_and_pressure() -> void:
	var run := controlled()
	var fleet: RefCounted = run.defense
	var convoy: RefCounted = fleet.convoy
	var raider: Dictionary = fleet.unit_for(convoy.pursuers.front())
	var ahead: Vector3 = raider.position.move_toward(fleet.target_for(raider), 1.2)
	fleet.place_decoy(ahead)
	check(fleet.target_kind(raider) == "decoy" and convoy.pursuers.has(raider.encounter), "Decoy diverts without discarding the convoy assignment")
	fleet.clear_decoy()
	check(fleet.target_kind(raider) == "convoy", "The original pursuit resumes when the decoy clears")
	fleet.pressure = fleet.tuning.pressure_maximum - 4
	fleet.revealed = true
	fleet.missiles.countdown = 30
	position_strike(run, Vector3.ZERO, 2)
	var event := advance(run, 0.01)
	check(convoy.activity == "destroyed" and event.escalated and fleet.mothership_advancing, "Pressure reaches the advancement threshold in the loss event")
	check(fleet.pressure == fleet.tuning.pressure_maximum, "Pressure penalty is clamped")
	var full_cap: int = fleet.military.cap
	fleet.military.cap = fleet.active_attackers()
	advance(run, 6)
	check(fleet._punitive_pending() and convoy.punitive_remaining == 0.0, "A full attacker cap defers the single queued elite")
	fleet.military.cap = full_cap
	advance(run, 0.05)
	check(fleet.available(fleet.unit_for(convoy.punitive_index)), "Available slot releases the waiting elite")
	var battle := victory(run, convoy.punitive_index)
	check(battle != null and run.upgrades_remaining == run.rules.elite_upgrades, "Punitive victory retains elite upgrade count")
	check(run.pending_choice == "battle_reward" and run.card_offers.all(func(card): return card.tier < 3), "Convoy loss cannot farm an extra Tier 3 reward")


func priorities() -> void:
	var run := controlled()
	var fleet: RefCounted = run.defense
	var convoy: RefCounted = fleet.convoy
	var ids := position_strike(run, Vector3.ZERO, 1)
	var at: Vector3 = convoy.position()
	var event: Dictionary = run._advance_strategy(0.1, at, at, false, false)
	check(event.contact == ids.front() and convoy.integrity == 40, "Player contact wins simultaneous hostile contact")
	var direct := controlled()
	var safe: RefCounted = direct.defense.convoy
	safe.travel_span(safe.leg_seconds())
	position_strike(direct, Vector3.ZERO, 1)
	var before: int = direct.salvage
	var extracted := advance(direct, 0.1)
	check(safe.activity == "extracted" and safe.integrity == 40 and extracted.convoy_reward == 15, "Exact extraction beats hostile contact and grants fifteen Salvage")
	var decoded := reload_run(direct)
	check(decoded != null and direct.salvage == before + 15 and decoded.salvage == direct.salvage, "Claim survives save")
	advance(decoded, 0.1)
	check(decoded.salvage == before + 15, "No payout duplication on resume")
	var terminal := controlled()
	var terminal_fleet: RefCounted = terminal.defense
	terminal_fleet.revealed = true
	for unit in terminal_fleet.units:
		if terminal_fleet.available(unit):
			terminal_fleet.neutralize(unit.encounter)
			terminal.encounters[unit.encounter].completed = true
	var settled := advance(terminal, 0.1)
	check(terminal_fleet.convoy.activity == "extracted" and terminal_fleet.complete and terminal._claim_evacuation() + settled.get("convoy_reward", 0) == 15, "Winning the battlefield safely resolves a surviving convoy")


func last_missile() -> void:
	var run := controlled()
	var fleet: RefCounted = run.defense
	fleet.revealed = true
	var missile_id: int = fleet.missiles.next_id
	var mother: Dictionary = fleet.unit_for(fleet.mothership_index())
	fleet.missiles.next_id += 1
	fleet.missiles.active[missile_id] = {"origin":mother.position, "remaining":mother.position.distance_to(fleet.home), "hull":fleet.tuning.missile_hull}
	fleet.missiles.pending = missile_id
	for unit in fleet.units:
		if fleet.available(unit):
			fleet.neutralize(unit.encounter)
			run.encounters[unit.encounter].completed = true
		if unit.status == "secured": run.encounters[unit.encounter].completed = true
	check(not fleet.complete and fleet.convoy.traveling(), "A live missile blocks safe battlefield evacuation")
	var before: int = run.salvage
	check(run.resolve_missile(missile_id, "direct") and run.can_jump(), "Last missile resolves the sector and evacuation at once")
	check(fleet.convoy.reward_claimed and run.salvage == before + 15 + fleet.tuning.secured_salvage, "Missile resolution pays exactly one evacuation and secured reward")
	check(not run.resolve_missile(missile_id, "direct") and run._claim_evacuation() == 0, "Repeating missile resolution cannot duplicate evacuation currency")


func _initialize() -> void:
	generation()
	movement()
	outcomes()
	decoys_and_pressure()
	priorities()
	last_missile()
	print("Starfront convoy: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
