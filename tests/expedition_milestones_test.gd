extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Progression = preload("res://resources/expedition_progression.tres")
const Ships = preload("res://scripts/ship_library.gd")
var checks: int = 0
var failures: int = 0

class Result extends Node:
	var player_hull: int = 30
	var salvage: int = 0
	var battles_won: int = 1
	var winner: String = "player"
	var escaped_by_ftl: bool = false
	var enemy_hull: int = 0
	var earned_tactical: bool = false
	var earned_strategic: bool = false
	const TACTICAL_RESOURCES = 5
	const STRATEGIC_SHIELDS = 10

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 25: push_error(message)

func fresh(seed_value: int = 2041) -> Resource:
	var run = State.new()
	var config: Resource = Rules.duplicate(true)
	config.log_rolls = false
	run.start(0, config, seed_value)
	return run

func milestone(seed_value: int, system: int) -> Resource:
	var run = fresh(seed_value)
	run.system_number = system - 1
	run.ftl_charge = run.required_ftl_charge + 4
	check(run.generate_system(), "Enter milestone from its previous normal system")
	return run

func boss_index(run: Resource) -> int:
	for index in range(run.encounters.size()):
		if run.encounters[index].get("mandatory_boss", false): return index
	return -1

func _initialize() -> void:
	call_deferred("run_tests")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/testlogs/milestone-" + label + ".png")

func run_tests() -> void:
	for surplus in [0,1,2,4,100]:
		var run = fresh()
		run.ftl_charge = run.required_ftl_charge + surplus
		check(run.generate_system() and run.ftl_charge == mini(2,surplus), "Carryover formula at every surplus")
		run.start(1, run.rules, 2041)
		check(run.system_number == 1 and run.ftl_charge == 0, "New expeditions discard all old charge")
	var cap = Progression.duplicate()
	cap.ftl_carryover_cap = 1
	check(cap.carryover(9,5) == 1 and cap.carryover(3,5) == 0, "Inspector cap and negative surplus")
	cap.ftl_carryover_cap = 99
	check(cap.carryover(100,5) == 2, "Hard maximum remains two")
	for system in [1,2,3,4,6,7,9,10,12,13,18,24,99]:
		var steps: int = int((system-1)/3)
		check(Progression.difficulty_level(system) == steps+1, "Difficulty follows systems, not battles")
		for base in Rules.enemy_ships:
			var before: Array = [base.hull_capacity,base.shields,base.materials,base.energy,base.crew,base.synthesizer,base.reactor,base.quarters]
			var scaled: Resource = Progression.scaled_enemy(base,system)
			check(scaled.hull_capacity == base.hull_capacity + steps*2 and scaled.shields == base.shields + steps, "Hull and Shields additive scaling")
			for key in State.RESOURCES: check(scaled.get(key) == base.get(key)+steps, "Starting resources scaling")
			for key in State.PRODUCTION: check(scaled.get(key) == base.get(key)+floori(steps*0.25), "Production scales conservatively")
			check(before == [base.hull_capacity,base.shields,base.materials,base.energy,base.crew,base.synthesizer,base.reactor,base.quarters], "Shared ShipData never mutated")
			check(scaled.interstellar_ftl_reward == base.interstellar_ftl_reward and scaled.destruction_salvage_reward == base.destruction_salvage_reward and scaled.card_effect_weights == base.card_effect_weights, "Rewards and enemy preferences unmodified")
	var last_probability: float = 0
	for system in range(1,101):
		var probability: float = Progression.elite_probability(Rules.enemy_ships,system)
		check(probability >= last_probability and probability <= Progression.maximum_elite_probability, "Elite probability grows and caps")
		last_probability = probability
	var frequencies: Array[int] = []
	for system in [1,4,7,40]:
		var run = fresh()
		run.system_number = system
		run.rng.seed = 64011
		var elite_count: int = 0
		var seen: Dictionary = {}
		for sample in range(10000):
			var profile: Resource = Rules.enemy_ships[run._enemy_index(Rules.enemy_ships)]
			seen[profile.ship_name] = true
			if profile.enemy_rank == 1: elite_count += 1
		var expected: float = Progression.elite_probability(Rules.enemy_ships,system)
		check(absf(elite_count/10000.0-expected) < 0.025 and seen.size() == Rules.enemy_ships.size(), "Seeded Elite odds retain all existing archetypes")
		frequencies.append(elite_count)
		print("System %d Elite draws / 10000: %d" % [system,elite_count])
	check(frequencies[1] > frequencies[0] and frequencies[2] > frequencies[1] and frequencies[3] > frequencies[2], "Observed Elite progression")
	for system in [6,12,18,24]:
		for seed_value in range(1,101):
			var run = milestone(seed_value,system)
			var count: int = 0
			var pois: int = 0
			for entry in run.encounters:
				if entry.get("mandatory_boss",false): count += 1
				if entry.kind == "poi": pois += 1
			check(count == 1 and run.encounters.size() == 6 and run.required_ftl_charge == pois+1, "Exactly one mandatory Boss replaces a battle, requirement unchanged")
			var index: int = boss_index(run)
			check(index >= 0 and run.enemy_profile(run.encounters[index]).enemy_rank == 2, "Mandatory encounter uses existing Boss")
			check(run.ftl_charge == 2, "Carryover applied on milestone arrival")
			run.ftl_charge = 100
			var rng_before: int = run.rng.state
			check(not run.can_jump() and not run.generate_system() and run.system_number == system and run.ftl_charge == 100 and run.rng.state == rng_before, "Boss gate blocks surplus jumps without consuming anything")
		for outcome in ["defeated","resource","escaped","loss"]:
			var run = milestone(3000,system)
			var index: int = boss_index(run)
			run.ftl_charge = run.required_ftl_charge
			var result = Result.new()
			result.escaped_by_ftl = outcome == "escaped"
			result.enemy_hull = 0 if outcome == "defeated" else 20
			result.winner = "enemy" if outcome == "loss" else "player"
			result.player_hull = 0 if outcome == "loss" else run.hull
			run.active_battle = index
			var reward: int = run.victory_salvage(result) if result.winner == "player" else 0
			check(reward == (30 if outcome == "defeated" else (6 if outcome == "resource" else 0)), "Boss defeat/resource/escape rewards remain distinct")
			result.salvage = reward
			var charge_before: int = run.ftl_charge
			run.record_battle(result)
			var after: int = run.ftl_charge
			run.record_battle(result)
			check(run.system_number == system and run.ftl_charge == after, "Boss result awards once and never transitions systems")
			run.active_battle = -1
			if outcome == "loss":
				check(run.mandatory_boss_pending() and not run.can_jump(), "Defeat never resolves mandatory Boss")
			else:
				check(run.encounters[index].resolution == ("escaped" if outcome == "escaped" else "defeated"), "Resolution explicitly distinguishes escape and defeat")
				check(after == charge_before+3 and not run.mandatory_boss_pending() and run.can_jump(), "Both wins and Emergency Jump unlock normal progression and profile FTL")
				check(run.generate_system() and run.system_number == system+1 and run.ftl_charge == 2, "Exactly one normal transition with capped carryover")
			result.free()
	var malformed = milestone(18,6)
	malformed.encounters.erase(malformed.encounters[boss_index(malformed)])
	malformed.ftl_charge = 100
	check(not malformed.can_jump(), "Missing mandatory encounter fails closed")
	var tuned = fresh()
	tuned.rules.progression.boss_interval = 4
	tuned.system_number = 3
	tuned.ftl_charge = tuned.required_ftl_charge
	check(tuned.generate_system() and tuned.mandatory_boss_pending(), "Inspector Boss interval applies")
	var invalid = fresh()
	invalid.rules.minimum_battles = 0
	invalid.rules.maximum_battles = 0
	invalid.system_number = 5
	invalid.ftl_charge = invalid.required_ftl_charge
	check(invalid.generate_system() and invalid.encounters.size() == 6 and boss_index(invalid) >= 0, "Invalid composition cannot omit milestone")
	# Live scene checks: carried counter, blocked button, scaled battle and real Emergency Jump.
	for dimensions in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(800,450)]:
		root.size = dimensions
		var host = load("res://scenes/expedition.tscn").instantiate()
		root.add_child(host)
		host.state = milestone(2024,6)
		host.state.ftl_charge = host.state.required_ftl_charge
		host.show_system()
		for n in range(5): await process_frame
		check(host.jump_button.disabled and host.jump_button.text.contains("Resolve Boss"), "UI explains mandatory lock despite sufficient charge")
		await capture("system-" + str(dimensions.x))
		var index: int = boss_index(host.state)
		var scaled: Resource = host.state.enemy_profile(host.state.encounters[index])
		host.start_battle(index)
		var battle = host.battle
		battle.get_node("BattleEffects").enabled = false
		if battle.battle_effects.busy: await battle.battle_effects.finished
		check(battle.enemy_hull_capacity == scaled.hull_capacity and battle.enemy_hull == scaled.hull_capacity and battle.enemy_energy == scaled.energy, "Battle uses the effective scaled profile")
		await capture("battle-" + str(dimensions.x))
		battle.ftl.charge = battle.ftl.charge_target
		battle.ftl.disabled_turns = 0
		battle._warp_out()
		check(battle.escaped_by_ftl and host.state.system_number == 6 and host.state.encounters[index].completed and battle.salvage == 0, "Real Boss Emergency Jump resolves without a system jump or defeat loot")
		host._battle_finished()
		check(not host.jump_button.disabled, "Returning from escaped Boss unlocks system navigation")
		host._jump()
		check(host.state.system_number == 7 and host.state.ftl_charge == 2 and host.jump_button.text.contains("2/"), "Next system displays carried FTL")
		host.free()
		await process_frame
	print("Expedition milestones: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
