extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const BattleResult = preload("res://scripts/combat/battle_result.gd")
var failures: int = 0
var checks: int = 0
var escapes: int = 0
var surveys: int = 0
var ranks: Dictionary = {}
var compositions: Dictionary = {}

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 20: push_error(message)

func settle_choice(run: Resource) -> void:
	match run.pending_choice:
		"card": check(run.choose_card(0), "Card reward can be selected")
		"upgrade":
			while run.pending_choice == "upgrade":
				check(run.choose_upgrade(run.upgrade_candidates()[0].identity_key()), "Distinct combat/PoI upgrade can be selected")
		"resource": check(run.choose_attribute("energy"), "Resource choice resolves")
		"production": check(run.choose_attribute("reactor"), "Production choice resolves")

func _initialize() -> void:
	var config = Rules.duplicate(true)
	config.log_rolls = false
	for seed_value in range(1, 2001):
		# Half shipping composition; half broadened while reserving ordinary objective slots.
		config.minimum_battles = 1
		config.maximum_battles = 3 if seed_value % 2 == 0 else 6
		config.minimum_ordinary = 4 if seed_value % 2 == 0 else 1
		config.maximum_ordinary = 6 if seed_value % 2 == 0 else 8
		config.minimum_hazardous = 0
		config.maximum_hazardous = 3 if seed_value % 2 == 0 else 7
		var run = State.new()
		run.start(seed_value % preload("res://scripts/ships/ship_library.gd").PLAYERS.size(), config, seed_value)
		var poi_count: int = 0
		var hazards: int = 0
		var routes: int = 0
		for encounter in run.encounters:
			if encounter.kind == "poi":
				poi_count += 1
				if encounter.poi.hazardous: hazards += 1
			else: ranks[run.enemy_profile(encounter).enemy_rank] = true
			if encounter.get("objective_role", "") == "access": routes += 1
		compositions["%d/%d/%d" % [poi_count - hazards, hazards, run.encounters.size() - poi_count]] = true
		check(run.encounters.size() == 9, "Exactly nine encounters")
		check(routes >= 1 and routes <= 2 and not run.ftl_access, "One or two viable objective routes; initially locked")
		check(not run.generate_system(), "Cannot jump before access")
		run.hull = 1 if seed_value % 3 == 0 else run.ship().hull_capacity
		run.salvage = seed_value % 16
		var order: Array = range(run.encounters.size())
		while not order.is_empty():
			# A locked access objective waits for its single prerequisite, never disappears.
			var index: int = order.pop_at(run.rng.randi_range(0, order.size() - 1))
			if run.objective_locked(index):
				order.append(index)
				continue
			var before: int = run.pressure
			var encounter: Dictionary = run.encounters[index]
			if encounter.kind == "battle":
				var result = BattleResult.new()
				result.winner = "player"
				result.battles_won = 1
				result.player_hull = run.hull
				result.salvage = run.salvage
				result.escaped_by_ftl = seed_value % 4 != 0
				result.earned_tactical = false
				result.earned_strategic = false
				run.active_battle = index
				var loot: int = run.victory_salvage(result)
				var profile: Resource = run.enemy_profile(encounter)
				var multiplier: int = Rules.elite_salvage_multiplier if profile.enemy_rank == 1 else 1
				check(loot == (0 if result.escaped_by_ftl else profile.destruction_salvage_reward * multiplier), "Existing Salvage unchanged by access/pressure")
				result.salvage += loot
				result.encounter_index = index
				result.system_number = run.system_number
				run.record_battle(result)
				check(run.pressure == before + 1, "Regular battle completion adds one pressure")
				run.record_battle(result)
				check(run.pressure == before + 1, "Repeated result cannot add pressure or rewards")
				if result.escaped_by_ftl: escapes += 1
				run.active_battle = -1
			else:
				var choices: Array[int] = []
				for slot in range(encounter.poi.approaches.size()):
					var approach: Resource = encounter.poi.approaches[slot]
					if not run.locked_reason(approach).is_empty(): continue
					var worst: int = approach.success.hull
					if approach.success_chance < 1: worst = mini(worst, approach.failure.hull)
					if run.hull + worst > 0: choices.append(slot)
				if choices.is_empty():
					check(run.survey(index), "Blocked ordinary PoI has safe survey")
					surveys += 1
				else:
					check(run.resolve_approach(index, choices[run.rng.randi_range(0, choices.size() - 1)]), "Survivable approach resolves")
				settle_choice(run)
				check(run.pressure == before + 1, "PoI completion adds one pressure")
				check(not run.resolve_approach(index, 0) and not run.survey(index) and run.pressure == before + 1, "PoI completion is single-use")
			settle_choice(run)
			check(run.hull > 0, "Low-Hull safe route survives")
			check(run.can_jump() == run.ftl_access, "Access permits immediate departure independent of remaining encounters")
		check(run.can_jump() and run.pressure == 9, "Every completed system permits departure")
		check(run.generate_system() and not run.ftl_access and run.pressure == 0, "New system resets access and pressure")
	check(ranks.size() == 3 and compositions.size() >= 15 and escapes > 1000 and surveys > 0, "Varied strength/composition/escape/survey coverage")
	print("FTL objectives: 2000 systems, %d checks, %d escapes, %d surveys, %d compositions, %d ranks, %d failures" % [checks, escapes, surveys, compositions.size(), ranks.size(), failures])
	quit(1 if failures else 0)
