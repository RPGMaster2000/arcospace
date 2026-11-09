extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Regions = preload("res://scripts/expedition/asteroid_regions.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Screen = preload("res://scripts/ui/expedition_screen.gd")
const VisualSystem = preload("res://scripts/presentation/star_system/visual_system.gd")
var failures := 0
var checks := 0

# Phase 1 system transition, retained as an independent RNG/content comparison.
class PhaseOneState extends "res://scripts/expedition_state.gd":
	func generate_system() -> bool:
		if not pending_choice.is_empty() or active_battle >= 0 or hull <= 0: return false
		if system_number > 0 and not can_jump(): return false
		_recorded_results.clear()
		environmental_instances.clear()
		SystemGenerator.generate(self)
		navigation.reset_system()
		if is_defense(): navigation.checkpoint_position(Defense.wire(defense.start))
		chasedown_roll_policy.reset_leg()
		progress_committed.emit()
		return true

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for mode in ["exploration", "defense"]:
		for seed_value in [0, 17, 1042, 65537]:
			var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
			rules.game_mode = mode
			rules.log_rolls = false
			var state = State.new()
			var baseline = PhaseOneState.new()
			state.start(0, rules, seed_value)
			# Zero requests randomization, not a literal deterministic seed. Replay
			# the resolved seed so both architectures receive identical inputs.
			baseline.start(0, rules, state.seed_used)
			var context: String = "%s requested=%d resolved=%d" % [mode, seed_value, state.seed_used]
			check(state.seed_used == baseline.seed_used, "Same resolved run seed: " + context)
			for stream in ["rng", "station_rng", "chasedown_rng"]:
				var actual_rng: RandomNumberGenerator = state.get(stream)
				var baseline_rng: RandomNumberGenerator = baseline.get(stream)
				check(actual_rng.seed == baseline_rng.seed and actual_rng.state == baseline_rng.state,
					"Phase 1 RNG seed/state unchanged (%s): %s" % [stream, context])
			var current: Dictionary = Save.encode(state)
			var expected: Dictionary = Save.encode(baseline)
			for data in [current, expected]:
				data.erase("environmental_instances")
				data.erase("encounter_positions")
			check(current == expected, "Phase 1 gameplay generation, all RNG streams, encounters, difficulty and objectives unchanged: " + context)
			check(EnvironmentData.valid_instances(state.environmental_instances), "Generated records are valid save data")
			var encoded: Dictionary = Save.encode(state)
			var restored = Save.new().decode(JSON.parse_string(JSON.stringify(encoded)), rules)
			check(restored != null and restored.environmental_instances == state.environmental_instances and restored.encounter_positions == state.encounter_positions, "Save round trip preserves exact definitions and coordinates")
			if mode == "exploration":
				var entries: Array = Screen.map_entries(state, func(key): return key)
				var layout_seed: int = state.seed_used if state.seed_used != 0 else hash("%d:%d:sky" % [state.seed_used, state.system_number])
				var layout: Dictionary = VisualSystem.generate(layout_seed, state.system_number, entries, preload("res://resources/presentation/star_system_settings.tres"), state.system_profile)
				for entry in entries:
					if entry.get("profile") == null: continue
					var at: Array = state.battle_location(entry.index)
					var original: Vector3 = layout.anchors[entry.index]
					check(Vector3(at[0],at[1],at[2]) == original,
						"Committed battle position exactly matches original visible anchor %d: %s" % [entry.index, context])
					var original_wire: Array = JSON.parse_string(JSON.stringify([original.x, original.y, original.z]))
					check(at == original_wire,
						"Committed coordinates exactly match original anchor at save precision %d: %s" % [entry.index, context])
					check(entry.world_position == at, "Map receives committed coordinates even for grid entry")
			else:
				var unit: Dictionary = state.defense.unit_for(0)
				check(state.battle_location(0) == state.Defense.wire(unit.position), "Defense uses the actual moving hostile center")
				unit.position += Vector3(1,0,0)
				check(state.battle_location(0) == state.Defense.wire(unit.position), "Defense coordinate follows authoritative simulation")
			var item: Dictionary = Regions.generate(11, 1, [])[0]
			item.region = {"shape": "belt", "inner": 8.0, "outer": 12.0, "ratio": 1.0, "angle": 0.0, "half_height": 1.0}
			item.position = [0.0, 0.0, 0.0]
			item.id = "b"
			var other: Dictionary = item.duplicate(true)
			other.id = "a"
			var inside: Dictionary = EnvironmentData.evaluate(state, [10,0,0], [item, other], 0)
			check(inside.instance_id == "a" and inside == EnvironmentData.evaluate(state, [10,0,0], [other, item], 0), "Stable lexical ID precedence independent of array order")
			check(EnvironmentData.modifier_id(inside) == 1 and inside.legacy_modifier == 0, "Physical ASTEROID_FIELD maps to existing modifier 1 exactly once")
			check(EnvironmentData.valid_snapshot(inside) and inside.configuration.region.is_read_only(), "Frozen valid geometry/configuration snapshot")
			for location in [[], [0,0,0], [50,0,0]]:
				var neutral: Dictionary = EnvironmentData.evaluate(state, location, [item], 0)
				check(EnvironmentData.modifier_id(neutral) == 0 and neutral.type == EnvironmentData.NONE, "Outside and unknown locations stay neutral")
			for legacy in range(1,8):
				var snapshot: Dictionary = EnvironmentData.evaluate(state, [10,0,0], [item], 0, legacy)
				check(snapshot.type == EnvironmentData.NONE and EnvironmentData.modifier_id(snapshot) == legacy, "Explicit legacy effect takes precedence without stacking")
			var invalid: Dictionary = encoded.duplicate(true)
			invalid.environmental_instances[0].region.half_height = -1.0
			check(Save.new().decode(invalid, rules) == null, "Invalid region geometry rejected at save boundary")
			var phase_two: Dictionary = encoded.duplicate(true)
			var old_belt: Dictionary = item.duplicate(true)
			old_belt.generation.version = 1
			old_belt.visual.erase("arc_fraction")
			var old_cluster: Dictionary = old_belt.duplicate(true)
			old_cluster.id = "legacy-cluster"
			old_cluster.position = [5.0,0.0,6.0]
			old_cluster.region = {"shape":"pockets", "angle":0.0, "half_height":1.0,
				"pockets":[{"offset":[0.0,0.0], "axes":[2.0,1.0], "angle":0.0}]}
			phase_two.environmental_instances = [old_belt,old_cluster]
			phase_two = JSON.parse_string(JSON.stringify(phase_two))
			var phase_two_state = Save.new().decode(phase_two, rules)
			check(phase_two_state != null and phase_two_state.environmental_instances == phase_two.environmental_instances, "Existing version-1 multiple formations restore unchanged without arc coverage")
			var old: Dictionary = encoded.duplicate(true)
			old.erase("environmental_instances")
			old.erase("encounter_positions")
			var old_state = Save.new().decode(old, rules)
			check(old_state != null and old_state.environmental_instances.is_empty() and old_state.encounter_positions.is_empty(), "Old v3 saves never regenerate fields or unknown anchors")
	print("Asteroid battle integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
