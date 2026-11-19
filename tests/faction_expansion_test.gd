extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Catalog = preload("res://scripts/expedition/faction_catalog.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Details = preload("res://scripts/ui/system_details.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func fresh(faction: Resource, seed_value: int = 42) -> Resource:
	var config := Rules.duplicate(true)
	config.game_mode = "defense"
	config.warzone_campaign_enabled = false
	config.log_rolls = false
	config.factions.assign([faction])
	var state := State.new()
	state.start(0, config, seed_value)
	return state


func next(state: Resource) -> void:
	state.defense.complete = true
	check(state.generate_system(), "Advance fixture to next system")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var seen := {}
	for faction in Catalog.DEFAULTS:
		for seed_value in range(1, 26):
			var state := fresh(faction, seed_value)
			var twin := fresh(faction, seed_value)
			for system in range(1, 7):
				for unit in state.defense.units:
					var ship: Resource = state.defense.ship_profile(unit)
					check(ship != null, "All deployed and reserve units read the encounter profile")
					if unit.mothership:
						var expected: Resource = (
							faction.mothership
							if system >= faction.mothership_minimum_system
							else state.rules.progression.mandatory_boss_profile()
						)
						if expected == null:
							expected = state.rules.progression.mandatory_boss_profile()
						check(
							ship == expected and ship.enemy_rank == 2,
							"Configured boss gate and fallback"
						)
					else:
						check(
							(
								ship in faction.standard_roster
								and ship.minimum_defense_system <= system
							),
							"Roster and progression eligibility"
						)
						if ship.minimum_defense_system > 1:
							seen[ship.resource_path] = true
					check(
						ship == twin.defense.ship_profile(twin.defense.unit_for(unit.encounter)),
						"Deterministic roster"
					)
				var restored: Resource = Save.new().decode(Save.encode(state), state.rules)
				check(restored != null, "Expanded fleet save valid")
				if restored != null:
					check(Save.encode(restored) == Save.encode(state), "Exact fleet save roundtrip")
					for unit in state.defense.units:
						var loaded: Dictionary = restored.defense.unit_for(unit.encounter)
						check(
							(
								restored.defense._speed(loaded) == state.defense._speed(unit)
								and (
									restored.defense.arrival_damage(loaded)
									== state.defense.arrival_damage(unit)
								)
							),
							"Strategic attributes restored through stable profile path"
						)
				check(state.rng.state == twin.rng.state, "Gameplay stream deterministic")
				if system < 6:
					next(state)
					next(twin)
	check(seen.size() == 8, "All eight new standards appear in seeded systems")
	for faction in Catalog.DEFAULTS:
		for ship in Catalog.roster(faction):
			if ship.minimum_defense_system == 1:
				continue
			var state := fresh(faction)
			state.encounters[0].enemy_data = ship
			var fleet: RefCounted = state.defense
			var unit: Dictionary = fleet.unit_for(0)
			check(
				is_equal_approx(
					fleet._speed(unit), fleet.tuning.enemy_speed * ship.strategic_speed_multiplier
				),
				"Actual per-ship movement speed"
			)
			check(
				fleet.arrival_damage(unit) == (13 if ship.strategic_class == "Light" else 28),
				"Class arrival damage rounding"
			)
			var start: Vector3 = fleet.home + Vector3(10, 0, 0)
			unit.position = start
			unit.route_origin = start
			var player: Vector3 = fleet.home + Vector3(4, 0, 4)
			var intercept: Vector3 = fleet.intercept_point(0, player)
			var duration: float = player.distance_to(intercept) * fleet.tuning.seconds_per_distance
			check(
				(
					start.move_toward(fleet.home, fleet._speed(unit) * duration).distance_to(
						intercept
					)
					< 0.0001
				),
				"Interception predicts the actual class speed"
			)
			fleet.advance_time(1, Vector3(0, 100, 0), Vector3(0, 100, 0), true)
			check(
				is_equal_approx(start.distance_to(unit.position), fleet._speed(unit)),
				"Authoritative simulation moves by class speed"
			)
			# Isolate one arrival without changing other ship/profile statistics.
			for other in fleet.units:
				if other.encounter != 0:
					other.status = "reserve" if not other.mothership else "active"
			unit.position = fleet.home + Vector3(.01, 0, 0)
			var integrity: int = fleet.integrity
			fleet.advance_time(.1, Vector3(0, 100, 0), Vector3(0, 100, 0), true)
			check(
				fleet.integrity == integrity - fleet.arrival_damage(unit),
				"Homeworld receives the ship's actual arrival damage"
			)
	for faction in Catalog.DEFAULTS:
		for emp in [false, true]:
			var battle_state := fresh(faction)
			next(battle_state)
			battle_state.defense.pressure = battle_state.defense.reveal_threshold()
			battle_state.defense.revealed = true
			var boss_index: int = battle_state.defense.mothership_index()
			battle_state.defense.contact = boss_index
			var setup = battle_state.prepare_battle(boss_index)
			check(
				setup != null and setup.emp_requirement_bonus == 2,
				"Faction boss retains existing combat entry and EMP requirements"
			)
			var result := State.BattleResult.new()
			result.result_id = 99
			result.encounter_index = boss_index
			result.system_number = battle_state.system_number
			result.winner = "player"
			result.escaped_by_ftl = emp
			result.player_hull = battle_state.hull
			result.battles_won = battle_state.battles_won + 1
			check(
				battle_state.record_battle(result) and battle_state.defense.mothership_destroyed() and not battle_state.defense.complete,
				"Destruction and EMP defeat the faction mothership without clearing other forces"
			)
			check(not battle_state.record_battle(result), "Faction boss rewards cannot duplicate")
		var arrival_state := fresh(faction)
		next(arrival_state)
		arrival_state.defense.revealed = true
		arrival_state.defense.mothership_advancing = true
		var boss: Dictionary = arrival_state.defense.unit_for(
			arrival_state.defense.mothership_index()
		)
		boss.position = arrival_state.defense.home + Vector3(.01, 0, 0)
		arrival_state.defense.advance_time(.1, Vector3(0, 100, 0), Vector3(0, 100, 0), true)
		check(
			arrival_state.defense.failed(),
			"Every faction mothership arrival still ends the expedition"
		)
	var reinforcement := fresh(Catalog.DEFAULTS[2])
	next(reinforcement)
	next(reinforcement)
	var reserve: Dictionary = {}
	for unit in reinforcement.defense.units:
		if unit.status == "reserve" and reserve.is_empty():
			reserve = unit
		if not unit.mothership and unit.status == "active":
			reinforcement.defense.neutralize(unit.encounter)
	reinforcement.encounters[reserve.encounter].enemy_data = preload(
		"res://ships/enemy/axiom_enforcer.tres"
	)
	reinforcement.defense.reinforcement_remaining = .01
	reinforcement.defense.advance_time(.1, Vector3(0, 100, 0), Vector3(0, 100, 0), true)
	check(
		reserve.status == "active" and reserve.spawned,
		"Expanded reinforcement uses existing spawn lifecycle"
	)
	check(
		is_equal_approx(
			reinforcement.defense._speed(reserve), reinforcement.defense.tuning.enemy_speed * .8
		),
		"Spawned heavy reinforcement uses its actual speed"
	)
	var state := fresh(Catalog.DEFAULTS[2])
	var initial := Details.active_enemies(state)
	check(
		(
			initial.size()
			== (
				state
				. defense
				. units
				. filter(func(unit): return not unit.mothership and unit.status == "active")
				. size()
			)
		),
		"Hidden mothership and reserves absent"
	)
	check(
		not Details.text(state).contains("Sentinel Dreadnought"), "Hidden boss identity not leaked"
	)
	state.defense.neutralize(0)
	check(
		Details.active_enemies(state).size() == initial.size() - 1,
		"Neutralized ships leave active list"
	)
	state.production_upgrades.reactor = 2
	state.poi_effects.grant_production("synthesizer", 1, 3)
	state.add_modifiers({"energy": 6})
	var before := Save.encode(state)
	var text := Details.text(state)
	check(
		text.contains("Reactor +2") and text.contains("3 battles") and text.contains("Next battle"),
		"Persistent upgrades and temporary duration presented"
	)
	check(
		Save.encode(state) == before,
		"Details generation cannot advance time, RNG or environmental snapshots"
	)
	print("Faction expansion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
