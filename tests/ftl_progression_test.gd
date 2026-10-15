extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var failures: int = 0
var checks: int = 0
var escapes: int = 0
var surveys: int = 0
var ranks: Dictionary = {}
var compositions: Dictionary = {}
class BattleResult extends Node:
	var player_hull: int
	var salvage: int
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
		if failures < 20: push_error(message)

func settle_choice(run: Resource) -> void:
	match run.pending_choice:
		"card": check(run.choose_card(0), "Card reward can be selected")
		"upgrade": check(run.choose_upgrade(run.upgrade_candidates()[0].identity_key()), "Upgrade can be selected")
		"resource": check(run.choose_attribute("energy"), "Resource choice resolves")
		"production": check(run.choose_attribute("reactor"), "Production choice resolves")

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var config = Rules.duplicate(true)
	config.log_rolls = false
	for seed_value in range(1, 10001):
		# Half use shipping preferences; half stress every PoI/enemy count from 0/6 to 5/1.
		config.minimum_battles = 1
		config.maximum_battles = 2 if seed_value % 2 == 0 else 6
		config.minimum_ordinary = 3 if seed_value % 2 == 0 else 0
		config.maximum_ordinary = 4 if seed_value % 2 == 0 else 5
		config.minimum_hazardous = 0
		config.maximum_hazardous = 2 if seed_value % 2 == 0 else 5
		var run = State.new()
		run.start(seed_value % 3, config, seed_value)
		var poi_count: int = 0
		var hazards: int = 0
		var total: int = 0
		for index in range(run.encounters.size()):
			var encounter: Dictionary = run.encounters[index]
			if encounter.kind == "poi":
				poi_count += 1
				if encounter.poi.hazardous: hazards += 1
			else: ranks[run.enemy_profile(encounter).enemy_rank] = true
			total += run.encounter_charge(index)
		compositions["%d/%d/%d" % [poi_count - hazards, hazards, 6 - poi_count]] = true
		check(run.encounters.size() == 6, "Exactly six encounters")
		check(run.required_ftl_charge == poi_count + 1, "Requirement is PoIs plus one")
		check(total >= run.required_ftl_charge, "Theoretical capacity meets requirement")
		check(not run.generate_system(), "Cannot jump early")
		var low_hull: bool = seed_value % 3 == 0
		run.hull = 1 if low_hull else run.ship().hull_capacity
		run.salvage = seed_value % 16
		# Shuffle completion order using expedition RNG; includes all-escape runs.
		var order: Array = range(6)
		while not order.is_empty():
			var index: int = order.pop_at(run.rng.randi_range(0, order.size() - 1))
			var before: int = run.ftl_charge
			var encounter: Dictionary = run.encounters[index]
			if encounter.kind == "battle":
				var result = BattleResult.new()
				result.player_hull = run.hull
				result.salvage = run.salvage
				result.escaped_by_ftl = seed_value % 4 != 0
				result.enemy_hull = 20 if result.escaped_by_ftl else 0
				run.active_battle = index
				var loot: int = run.victory_salvage(result)
				check(loot == (0 if result.escaped_by_ftl else run.enemy_profile(encounter).destruction_salvage_reward), "Escape/destruction Salvage independent of FTL")
				result.salvage += loot
				run.record_battle(result)
				check(run.ftl_charge == before + run.encounter_charge(index), "Escape and destruction earn profile charge")
				var after: int = run.ftl_charge
				run.record_battle(result)
				check(run.ftl_charge == after, "Repeated battle result cannot award charge again")
				if result.escaped_by_ftl: escapes += 1
				run.active_battle = -1
				result.free()
			else:
				var choices: Array[int] = []
				for slot in range(encounter.poi.approaches.size()):
					var approach: Resource = encounter.poi.approaches[slot]
					if not run.locked_reason(approach).is_empty(): continue
					var worst: int = approach.success.hull
					if approach.success_chance < 1: worst = mini(worst, approach.failure.hull)
					if run.hull + worst > 0: choices.append(slot)
				if choices.is_empty():
					check(run.survey(index), "Blocked PoI has costly navigation survey")
					surveys += 1
				else:
					var slot: int = choices[run.rng.randi_range(0, choices.size() - 1)]
					check(run.resolve_approach(index, slot), "Survivable approach resolves")
				settle_choice(run)
				var after: int = run.ftl_charge
				check(after >= before + 1, "Every PoI grants base charge")
				check(not run.resolve_approach(index, 0) and not run.survey(index) and run.ftl_charge == after, "PoI reward is single-use")
			check(run.hull > 0, "Low-Hull safe route survives")
			check(run.ftl_charge + run.remaining_ftl_charge() >= run.required_ftl_charge, "Remaining capacity after every decision")
			check(run.can_jump() == (run.ftl_charge >= run.required_ftl_charge), "Can leave immediately at threshold")
		check(run.can_jump(), "Every completed system permits travel, including all escapes")
		check(run.generate_system() and run.ftl_charge == 0, "Jump resets travel charge")
	check(ranks.size() == 3 and compositions.size() >= 15 and escapes > 10000 and surveys > 0, "Varied composition, strength, escapes and survey coverage")
	# Every hazardous branch imposes a real drawback; safe first option works at 1 Hull.
	for poi in Rules.pois:
		if not poi.hazardous: continue
		for approach in poi.approaches:
			for outcome in [approach.success, approach.failure]:
				var drawback: bool = approach.salvage_cost > 0 or outcome.hull < 0 or int(outcome.next_battle.get("emergency_jump_offline", 0)) > 0
				for key in outcome.next_battle: drawback = drawback or outcome.next_battle[key] < 0
				check(drawback, "Hazard always carries drawback")
		var low_run = State.new()
		low_run.start(0, config, 42)
		low_run.hull = 1
		low_run.encounters.assign([{ "kind":"poi", "poi":poi, "completed":false }])
		check(low_run.can_survey(0) or (poi.approaches[0].requirement.is_empty() and poi.approaches[0].salvage_cost == 0 and poi.approaches[0].success.hull >= 0 and poi.approaches[0].failure.hull >= 0), "Unrestricted safe option or survey at 1 Hull")
	print("Progression: 10000 systems, %d checks, %d escapes, %d surveys, %d compositions, %d ranks, %d failures" % [checks, escapes, surveys, compositions.size(), ranks.size(), failures])
	quit(1 if failures else 0)
