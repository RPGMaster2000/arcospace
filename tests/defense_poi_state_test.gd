extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var failures := 0
var checks := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func fresh() -> Resource:
	var state := State.new()
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	state.start(0,rules,1042)
	state.defense.tuning = state.defense.tuning.duplicate(true)
	state.defense.tuning.enemy_speed = 0
	return state
func _initialize() -> void:
	var state := fresh()
	var original: int = state.production("synthesizer")
	state.poi_effects.grant_production("synthesizer",1,3)
	check(state.production("synthesizer") == original, "Temporary production never qualifies permanent upgrade gates")
	var enemy: Dictionary = state.defense.unit_for(0)
	state.defense.contact = 0
	var setup = state.prepare_battle(0)
	check(setup.player_state.synthesizer == original + 1, "Battle receives temporary production")
	check(state.poi_effects.production.synthesizer.battles == 3, "Entry does not consume a completed-battle charge")
	state.active_battle = -1
	state.defense.contact = -1
	state.poi_effects.pause = 15
	state.poi_effects.reduction = 30
	state.poi_effects.fuel = 21
	var wire: Dictionary = Save.encode(state)
	var restored: Resource = Save.new().decode(JSON.parse_string(JSON.stringify(wire)),state.rules)
	check(restored != null, "Effect ledger restores through actual save codec")
	if restored != null:
		check(restored.poi_effects.snapshot() == state.poi_effects.snapshot(), "All durations and amounts survive JSON")
		check(restored.defense.poi_effects == restored.poi_effects, "Restored simulation borrows the authoritative ledger")
	wire.erase("defense_poi_effects")
	var legacy: Resource = Save.new().decode(wire,state.rules)
	check(legacy != null and legacy.poi_effects.production.is_empty(), "Legacy save does not acquire new effects")
	wire.defense_poi_effects = state.poi_effects.snapshot()
	wire.defense_poi_effects.fuel = -1
	check(Save.new().decode(wire,state.rules) == null, "Codec rejects invalid durations")
	var split := fresh()
	for owner in [state,split]:
		owner.poi_effects.pause = 15
		owner.poi_effects.reduction = 30
		owner.defense.tuning.enemy_speed = 0
		owner.defense.tuning.pressure_maximum = 100
		owner.defense.tuning.mothership_reveal_pressure = 99
	state.defense.advance_time(35,state.defense.start,state.defense.start,true)
	for step in range(350): split.defense.advance_time(0.1,split.defense.start,split.defense.start,true)
	# v2 effective rate is one per strategic second: 15 paused, 15 at half, 5 normal.
	check(is_equal_approx(state.defense.pressure,12.5), "Pressure modifiers apply to the effective v2 rate and expire mid-span")
	check(absf(state.defense.pressure-split.defense.pressure) < 0.00001, "Pressure result is independent of update partition")
	check(state.poi_effects.pause == 0 and state.poi_effects.reduction == 0, "Simulation consumes strategic durations")
	var advancing := fresh()
	advancing.defense.revealed = true
	advancing.defense.mothership_advancing = true
	advancing.defense.missiles.countdown = 0.5
	advancing.defense.tuning.enemy_speed = 1.2
	advancing.poi_effects.pause = 15
	var attacker_before: Vector3 = advancing.defense.unit_for(0).position
	var mother_before: Vector3 = advancing.defense.unit_for(advancing.defense.mothership_index()).position
	advancing.defense.advance_time(1,advancing.defense.start,advancing.defense.start,true)
	check(advancing.defense.pressure == 0, "Pause does not add Pressure")
	check(advancing.defense.unit_for(0).position.distance_to(attacker_before) > 1.0, "Enemies continue moving while Pressure pauses")
	check(advancing.defense.unit_for(advancing.defense.mothership_index()).position.distance_to(mother_before) > 0.6, "Pressure pause never reverses advancing mothership")
	check(not advancing.defense.missiles.active.is_empty(), "Missile scheduler runs during Pressure pause")
	var charge_state := fresh()
	charge_state.poi_effects.grant_production("reactor",1,3)
	charge_state.active_battle = 0
	charge_state.defense.contact = 0
	var result := State.BattleResult.new()
	result.system_number = charge_state.system_number
	result.encounter_index = 0
	result.winner = "player"
	result.player_hull = charge_state.hull
	charge_state.record_battle(result)
	check(charge_state.poi_effects.production.reactor.battles == 2, "Completed card battle consumes exactly one charge")
	charge_state.record_battle(result)
	check(charge_state.poi_effects.production.reactor.battles == 2, "Repeated result cannot consume another charge")
	var installation := fresh()
	installation.salvage = 100
	var mining := -1
	for index in installation.encounters.size():
		if installation.encounters[index].kind == "poi" and installation.defense.anchors.has(index):
			mining = index
			break
	check(mining >= 0, "Mining fixture has an authoritative PoI anchor")
	if mining >= 0:
		installation.encounters[mining].poi = preload("res://encounters/mining_operation.tres")
		var location: Vector3 = installation.defense.anchors[mining]
		var before_salvage: int = installation.salvage
		check(installation.deploy_poi_turret(mining), "Free installation uses an actual Mining Operation")
		var free_id: String = State.Defense.Installations.FREE_PREFIX + str(mining)
		check(installation.salvage == before_salvage, "Free deployment never charges Salvage")
		check(State.Defense.point(installation.defense.turrets[free_id].position) == location, "Free turret stays exactly at the PoI")
		check(not installation.deploy_poi_turret(mining), "Free turret cannot be deployed twice")
		var sites: Array = installation.defense.construction_sites.keys()
		check(sites.size() >= 2, "Fixture retains purchased construction sites")
		if sites.size() >= 2:
			check(installation.deploy_turret(sites[0]) and installation.deploy_turret(sites[1]), "Free installation does not consume either purchased slot")
			check(installation.defense.turrets.size() == 3, "Combined cap is three installations")
		installation.defense.unit_for(0).position = location
		check(not installation.turret_support(0).is_empty(), "PoI installation reuses normal battle support")
		installation.encounters[mining].completed = true
		var saved := Save.encode(installation)
		var loaded: Resource = Save.new().decode(JSON.parse_string(JSON.stringify(saved)),installation.rules)
		check(loaded != null, "Free and purchased installations survive actual save restoration")
		if loaded != null:
			check(loaded.defense.turrets == installation.defense.turrets, "Restored turret geometry and weapons remain identical")
			check(not loaded.can_deploy_poi_turret(mining), "Restore cannot reopen free deployment")
		# Place a missile on a trajectory crossing the real installation, not vice versa.
		installation.defense.tuning.enemy_speed = 1.2
		var fleet: RefCounted = installation.defense
		fleet.revealed = true
		fleet.missiles.countdown = 100
		var origin: Vector3 = location + (location-fleet.home).normalized()
		var missile_id: int = fleet.missiles.next_id
		fleet.missiles.next_id += 1
		fleet.missiles.active[missile_id] = {"origin":origin,"remaining":origin.distance_to(fleet.home),"hull":8}
		var flight: Dictionary = fleet.advance_time(1.0,fleet.start,fleet.start,true)
		check(flight.missile_shots.size() >= 2 and not fleet.missiles.active.has(missile_id), "Free PoI installation destroys a covered missile through the existing scheduler")
		saved.defense.turrets[free_id].position[0] += 1
		check(Save.new().decode(saved,installation.rules) == null, "Shifted free turret save is rejected")
	print("Defense PoI state integration: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
