extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
const Screen = preload("res://scripts/ui/expedition_screen.gd")
var failures := 0
var checks := 0

# The generator is unchanged. This override reproduces main's old assignment hook,
# including its exact range and draw count, independently of the new neutral hook.
class HistoricalState extends "res://scripts/expedition_state.gd":
	func _roll_battle_modifier() -> int:
		return Modifiers.roll_encounter(rng)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for mode in ["exploration", "defense"]:
		for seed_value in [17, 1042, 65537]:
			for ship_index in range(6):
				var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
				rules.game_mode = mode
				rules.log_rolls = false
				var current = State.new()
				var historical = HistoricalState.new()
				current.start(ship_index, rules, seed_value)
				historical.start(ship_index, rules, seed_value)
				for number in range(1, 13):
					var expected: Dictionary = Save.encode(historical)
					for entry in expected.encounters:
						if entry.kind == "battle": entry.modifier = 0
					check(Save.encode(current) == expected, "Only assigned modifier differs from main, including RNG/enemies/pressure/defense/reserves/objectives")
					check(current.environmental_instances.is_empty(), "Phase 1 generates no phenomena")
					for index in current.encounters.size():
						if current.encounters[index].kind != "battle": continue
						check(current.encounters[index].modifier == 0, "Every generated enemy, boss and reserve is neutral")
						var before: Dictionary = Save.encode(current)
						var snapshot: Dictionary = current.battle_environment(index)
						check(EnvironmentData.valid_snapshot(snapshot) and snapshot.type == EnvironmentData.NONE and snapshot.legacy_modifier == 0, "Valid NONE snapshot")
						check(snapshot == current.battle_environment(index) and Save.encode(current) == before, "Evaluation repeats deterministically without gameplay RNG/state changes")
					# Exercise consecutive systems including boss milestones, without combat randomness.
					for state in [current, historical]:
						state.ftl_access = true
						for entry in state.encounters: entry.completed = true
						if state.is_defense(): state.defense.complete = true
						check(state.generate_system(), "Completed system advances")

	var state = State.new()
	var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
	rules.game_mode = "exploration"
	rules.log_rolls = false
	state.start(0, rules, 1042)
	var index := -1
	for i in state.encounters.size():
		if state.encounters[i].kind == "battle": index = i; break
	state.navigation.checkpoint_position([1, 0, 2])
	var item: Dictionary = EnvironmentData.instance("reserved-one", EnvironmentData.SPACE_STORM, [1, 0, 2])
	item.visual = {"palette": [1, 2, 3]}
	item.generation = {"seed": "123", "version": 1}
	state.environmental_instances.append(item)
	check(EnvironmentData.valid_instances(state.environmental_instances), "Shared model accepts planned phenomenon data without implementing it")
	var view: Array = state.environment_view()
	var snapshot: Dictionary = state.battle_environment(index)
	check(view.is_read_only() and view[0].visual.palette.is_read_only(), "Map view recursively read-only")
	check(snapshot.is_read_only() and snapshot.visual.is_read_only() and snapshot.location.is_read_only(), "Snapshot recursively read-only")
	state.navigation.checkpoint_position([5, 0, 6])
	item.visual.palette[0] = 99
	check(view[0].visual.palette[0] == 1 and snapshot.location == [1, 0, 2], "World mutations cannot change detached map/battle snapshots")
	check(snapshot.type == EnvironmentData.NONE, "No spatial/overlap behavior implemented")
	var data: Dictionary = Save.encode(state)
	var restored = Save.new().decode(JSON.parse_string(JSON.stringify(data)), rules)
	check(restored != null and restored.environmental_instances == state.environmental_instances, "Optional instance records survive JSON")
	if restored != null:
		restored.environmental_instances[0].visual.palette[0] = 88
		check(state.environmental_instances[0].visual.palette[0] == 99, "Restored mutable world has no aliases")
	var invalid: Dictionary = data.duplicate(true)
	invalid.environmental_instances.append(invalid.environmental_instances[0].duplicate(true))
	check(Save.new().decode(invalid, rules) == null, "Duplicate instance IDs rejected")
	invalid = data.duplicate(true)
	invalid.environmental_instances[0].intensity = NAN
	check(Save.new().decode(invalid, rules) == null, "Non-finite optional data rejected")
	var legacy: Dictionary = data.duplicate(true)
	legacy.erase("environmental_instances")
	for kind in range(8):
		legacy.encounters[index].modifier = kind
		var old = Save.new().decode(legacy, rules)
		check(old != null and old.environmental_instances.is_empty(), "Old version-3 save defaults to empty physical environment")
		if old != null:
			var setup = old.prepare_battle(index)
			check(setup.modifier == kind and setup.environment.legacy_modifier == kind, "Every legacy modifier still reaches combat setup")
	var before_rng: int = state.rng.state
	var setup = state.prepare_battle(index, null, snapshot)
	check(state.rng.state == before_rng and setup.environment == snapshot and setup.modifier == 0, "Battle setup consumes no gameplay RNG and uses supplied snapshot")
	var modifier = Modifiers.new()
	modifier.configure(0, 123)
	for round_number in range(1, 50):
		check(modifier.begin_round(round_number).is_empty() and not modifier.active and not modifier.shields_disabled(), "Neutral scheduler has no events or effects")
	check(modifier.status_text(1).is_empty(), "Neutral scheduler has no label")
	var card: Resource = state.player_pool()[0]
	check(modifier.preview(card) == card and not modifier.affects_card(card), "Neutral does not scale cards")
	modifier.free()
	var entries: Array = Screen.map_entries(state, func(key: String): return key)
	for entry in entries:
		if entry.index == index:
			check(not entry.tooltip.contains("None"), "Neutral map has no modifier label")
	print("Environmental foundation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
