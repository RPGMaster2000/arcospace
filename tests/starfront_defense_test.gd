extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Defense = preload("res://scripts/expedition/defense_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Result = preload("res://scripts/combat/battle_result.gd")
const VisualSystem = preload("res://scripts/presentation/star_system/visual_system.gd")
const DefenseVisual = preload("res://scripts/presentation/star_system/defense_presentation.gd")
const VisualSettings = preload("res://resources/presentation/star_system_settings.tres")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fresh(seed_value: int = 42) -> Resource:
	var state = State.new()
	var rules = Rules.duplicate(true)
	rules.game_mode = "defense"
	state.start(0, rules, seed_value)
	return state
func win(state: Resource, index: int, emp: bool) -> void:
	state.defense.contact = index
	state.prepare_battle(index)
	var result = Result.new()
	result.result_id = index + 100
	result.encounter_index = index
	result.system_number = state.system_number
	result.winner = "player"
	result.escaped_by_ftl = emp
	result.player_hull = state.hull
	result.battles_won = state.battles_won + 1
	result.salvage = state.salvage + state.victory_salvage(result)
	state.record_battle(result)
	var total: int = state.salvage
	state.record_battle(result)
	check(state.salvage == total, "Duplicate result cannot award twice")
	state.active_battle = -1
	while state.pending_choice == "upgrade" and state.upgrades_remaining > 0 and not state.upgrade_candidates().is_empty():
		state.choose_upgrade(state.upgrade_candidates()[0].identity_key())
	state.finish_upgrades()
func run() -> void:
	var state = fresh()
	check(state.is_defense() and state.defense.units.size() == 7, "New defense roster includes four inactive reserves")
	check(not state.can_engage(0) and state.prepare_battle(0) == null, "An enemy cannot be engaged without simulation contact")
	check(not state.system_objective_complete() and not state.try_chasedown(-3, 0), "Mothership locks FTL and random Chasedown disabled")
	var before: Vector3 = state.defense.units[0].position
	state.navigation.report_movement([0,0,0])
	check(state.defense.units[0].position == before, "Idle freezes enemy movement")
	state.navigation.checkpoint_position(Defense.wire(state.defense.start))
	var next: Vector3 = state.defense.start.move_toward(Vector3.ZERO, 1.0)
	state.begin_free_travel(Defense.wire(next))
	state.navigation.report_movement(Defense.wire(next))
	check(absf(before.distance_to(state.defense.units[0].position) - (1.2 / 7.0)) < 0.00001, "Validated world distance advances enemy by tuned rate")
	before = state.defense.units[0].position
	state.begin_free_travel([2,0,20])
	check(state.defense.units[0].position == before, "Redirect intent adds no strategic distance")
	var saved: Dictionary = Save.encode(state)
	var restored: Resource = Save.new().decode(saved)
	check(restored != null, "Travel save roundtrip")
	check(Save.new().decode(JSON.parse_string(JSON.stringify(saved))) != null, "On-disk JSON numeric conversion preserves versioned defense snapshots")
	if restored != null:
		check(restored.navigation.position == state.navigation.position, "Restore preserves actual position")
		restored.navigation.report_movement([900,0,0])
		check(restored.defense.units[0].position == before, "Restore rebases measurement without movement")
	# Same straight player path, split into 1 or 100 samples.
	var a = fresh()
	var b = fresh()
	a.defense.advance_time(10.0/7.0, Vector3(0,0,20), Vector3(10,0,20))
	for i in range(100): b.defense.advance_time(0.1/7.0, Vector3(i*0.1,0,20), Vector3((i+1)*0.1,0,20))
	check(a.defense.units[0].position.distance_to(b.defense.units[0].position) < 0.0001, "Strategic motion independent of frame partition")
	var c = fresh()
	c.rules.defense_tuning = c.rules.defense_tuning.duplicate(true)
	c.defense.tuning = c.rules.defense_tuning
	c.rules.defense_tuning.enemy_speed = 0.0
	c.defense.units[0].position = Vector3.ZERO
	c.defense.units[1].status = "arrived"
	var contact: Dictionary = c.defense.advance_time(40.0/7.0, Vector3(-20,0,0), Vector3(20,0,0))
	check(contact.contact == 0 and contact.position.x < 0, "Swept contact stops long crossing at first interception")
	var repeated: Dictionary = c.defense.advance_time(40.0/7.0, Vector3(-20,0,0), Vector3(20,0,0))
	check(repeated.contact == -1, "Pending contact cannot repeat interception")
	c = fresh()
	c.defense.units[0].position = c.defense.home
	c.defense.units[1].position = c.defense.home
	var arrivals: Dictionary = c.defense.advance_time(100, Vector3(0,100,0), Vector3(100,100,0))
	check(arrivals.arrivals == 2 and c.defense.integrity == 60, "Both base arrivals apply exactly once during a large step")
	check(c.defense.failed(), "Both arrivals without a neutralization fail the otherwise unreachable objective")
	c.defense.advance_time(100, Vector3(0,100,0), Vector3(100,100,0))
	check(c.defense.integrity == 60, "Arrivals cannot damage twice")
	for emp in [false, true]:
		state = fresh()
		var initial: int = state.salvage
		win(state, 0, emp)
		check(state.defense.revealed and state.defense.reveal_pending and state.defense.neutralized_attackers() == 1, "Destruction or EMP reveals exactly once")
		check(not emp or state.salvage == initial, "EMP awards zero destruction Salvage")
		restored = Save.new().decode(Save.encode(state))
		check(restored != null and restored.defense.revealed, "Post-neutralization restoration")
		state.defense.reveal_pending = false
		state.defense.contact = 2
		var setup = state.prepare_battle(2)
		check(setup.emp_requirement_bonus == 2, "Mothership flat EMP modifier")
		state.active_battle = -1
		win(state, 2, emp)
		check(state.can_jump() and state.defense.complete and state.defense.units[1].status == "secured", "Mothership neutralization secures remaining fleet and unlocks voluntary FTL")
		check(Save.new().decode(Save.encode(state)) != null, "Completed defense save validates")
		var number: int = state.system_number
		var salvage: int = state.salvage
		check(state.generate_system() and state.system_number == number + 1 and not state.defense.revealed and state.defense.integrity == 100 and state.salvage == salvage, "FTL generates fresh defense and preserves resources")
	for seed_value in range(100):
		state = fresh(seed_value + 1)
		var twin = fresh(seed_value + 1)
		check(state.defense.snapshot() == twin.defense.snapshot(), "Deterministic generation")
		check(state.defense.anchors.size() >= 8, "Eight optional sites")
		for encounter in state.encounters:
			if encounter.kind == "poi": check(encounter.poi.resource_path.get_file().get_basename() != "unstable_wormhole", "Defense excludes unstable wormholes")
		var visuals: Dictionary = VisualSystem.generate(seed_value + 1, 1, [], VisualSettings)
		DefenseVisual.layout(visuals, state.defense.snapshot())
		check(visuals.planets.size() >= 2 and visuals.planets[0].type == "terrestrial", "Procedural additional planets and terrestrial homeworld")
		for planet in visuals.planets.slice(1):
			check(planet.position.length() >= 4.999, "Planet clears the sun")
			for anchor in state.defense.anchors.values(): check(planet.position.distance_to(anchor) >= 4, "Planet clears PoI anchors")
		for unit in state.defense.units:
			if unit.status == "reserve": continue
			check(Geometry3D.get_closest_point_to_segment(Vector3.ZERO, unit.position, state.defense.home).length() > 3, "Direct approach clears sun geometry")
			for anchor in state.defense.anchors.values(): check(unit.position.distance_to(anchor) > 5.5, "Hostile deployment clears all PoIs")
			check(unit.position.length() <= 22.001 and unit.position.dot(state.defense.home) < 0, "Hostile inside bounds and opposite homeworld")
		for anchor in state.defense.anchors.values():
			check(anchor.distance_to(state.defense.home) > 4, "PoIs clear homeworld")
	state = fresh()
	state.defense.units[0].position = state.defense.home
	state.defense.units[1].position = state.defense.home
	state.navigation.checkpoint_position([0,100,0])
	state.begin_free_travel([1,100,0])
	state.navigation.report_movement([1,100,0])
	check(state.run_ended and state.defense.integrity == 60 and not state.navigation.leg_active, "Missing both attackers ends the otherwise unwinnable objective")
	state = fresh()
	state.rules.defense_tuning = state.rules.defense_tuning.duplicate(true)
	state.rules.defense_tuning.base_attack_damage = 60
	state.defense.tuning = state.rules.defense_tuning
	state.defense.units[0].position = state.defense.home
	state.defense.units[1].position = state.defense.home
	state.navigation.checkpoint_position([0,100,0])
	state.begin_free_travel([1,100,0])
	state.navigation.report_movement([1,100,0])
	check(state.run_ended and state.defense.integrity == 0 and not state.can_jump() and state.hull > 0, "Base destruction ends expedition independently of ship Hull")
	var malformed = Save.encode(fresh())
	malformed.defense.units[1].encounter = 0
	check(Save.new().decode(malformed) == null, "Duplicate unit identity rejected")
	var legacy = fresh()
	legacy.game_mode = "exploration"
	legacy.defense = null
	legacy.ftl_access = true
	var data: Dictionary = Save.encode(legacy)
	data.metagame_version = 1
	data.erase("game_mode")
	data.erase("defense")
	restored = Save.new().decode(data)
	check(restored != null and not restored.is_defense(), "Version 1 saves retain exploration; never invent defense state")
	print("Starfront defense: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
