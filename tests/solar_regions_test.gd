extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Solar = preload("res://scripts/expedition/solar_regions.gd")
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")

# PR #50's complete system transition: independent comparison of all saved state.
class PhaseTwoState extends "res://scripts/expedition_state.gd":
	func generate_system() -> bool:
		if not pending_choice.is_empty() or active_battle >= 0 or hull <= 0: return false
		if system_number > 0 and not can_jump(): return false
		_recorded_results.clear()
		environmental_instances.clear()
		SystemGenerator.generate(self)
		encounter_positions = {} if is_defense() else preload("res://scripts/presentation/star_system/visual_system.gd").battle_positions(self)
		environmental_instances = Asteroids.generate(seed_used, system_number, encounter_positions.values())
		navigation.reset_system()
		if is_defense(): navigation.checkpoint_position(Defense.wire(defense.start))
		chasedown_roll_policy.reset_leg()
		progress_committed.emit()
		return true

var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var radii := {}
	for seed_value in range(64):
		var item: Dictionary = Solar.generate(seed_value, 3, [3.0,-1.0,4.0], 2.52)
		check(item == Solar.generate(seed_value, 3, [3.0,-1.0,4.0], 2.52), "Dedicated solar stream repeats exactly")
		check(Solar.valid(item) and Solar.valid_visual(item.visual) and EnvironmentData.valid_instances([item]), "Generated solar record is valid wire data")
		check(item.position == [3.0,-1.0,4.0] and item.region.radius >= 8.0 and item.region.radius <= 13.0, "Influence is anchored to physical star, extends into navigation space")
		radii[item.region.radius] = true
	check(radii.size() > 50, "Systems vary solar radius")
	var solar: Dictionary = Solar.generate(1042, 1, [3.0,-1.0,4.0], 2.52, Vector2(10,10))
	for at in [[3,-1,4],[13,-1,4],[-7,-1,4],[3,9,4],[3,-1,14]]:
		check(Solar.contains(solar, at), "Translated sphere includes its center and 3D boundaries")
	for at in [[],[13.001,-1,4],[3,9.001,4],[3,-1,14.001],[NAN,0,0],[0,INF,0]]:
		check(not Solar.contains(solar, at), "Outside/unknown/non-finite points are neutral")
	var scaled: Dictionary = Solar.generate(1042,1,[0,0,0],4.0,Vector2(3,3))
	check(scaled.region.radius > scaled.configuration.star_radius, "Influence never ends inside scaled stellar surface")
	var state = State.new()
	var rules = preload("res://encounters/expedition_rules.tres").duplicate(true)
	rules.log_rolls = false
	rules.game_mode = "exploration"
	state.start(0,rules,1042)
	solar = Solar.generate(1042,1,[0,0,0],2.52,Vector2(10,10))
	var asteroid: Dictionary = Asteroids.generate(7,1,[])[0]
	asteroid.position = [0.0,0.0,0.0]
	asteroid.region = {"shape":"belt","inner":4.0,"outer":15.0,"ratio":1.0,"angle":0.0,"half_height":1.0}
	asteroid.id = "a-asteroids"
	var second: Dictionary = solar.duplicate(true)
	second.id = "a-solar"
	for records in [[asteroid,solar,second],[second,asteroid,solar],[solar,second,asteroid]]:
		var snapshot: Dictionary = EnvironmentData.evaluate(state,[8,0,0],records,0)
		check(snapshot.type == Solar.TYPE and snapshot.instance_id == second.id and EnvironmentData.modifier_id(snapshot) == 3, "Solar beats asteroid, lexical ID breaks same-type ties regardless of ordering")
		check(EnvironmentData.valid_snapshot(snapshot) and snapshot.configuration.region.is_read_only() and snapshot.visual.is_read_only(), "Solar snapshot is validated and recursively frozen")
		check(EnvironmentData.modifier_id(EnvironmentData.evaluate(state,[12,0,0],records,0)) == 1, "Asteroids remain active outside solar influence")
		check(EnvironmentData.modifier_id(EnvironmentData.evaluate(state,[30,0,0],records,0)) == 0, "Outside all regions remains neutral")
		for legacy in range(1,8):
			check(EnvironmentData.modifier_id(EnvironmentData.evaluate(state,[8,0,0],records,0,legacy)) == legacy, "Every explicit legacy ID takes precedence over overlap")
	var frozen: Dictionary = EnvironmentData.evaluate(state,[8,0,0],[solar],0)
	solar.position = [100,0,100]
	solar.visual.activity = 0.0
	check(frozen.configuration.position == [0.0,0.0,0.0] and frozen.visual.activity != solar.visual.activity, "Snapshot has no mutable world aliases")
	check(EnvironmentData.snapshot(JSON.parse_string(JSON.stringify(frozen))) == frozen, "Solar snapshot round trips exactly")
	for path in ["radius", "visual", "star_radius"]:
		var invalid: Dictionary = frozen.duplicate(true)
		if path == "radius": invalid.configuration.region.radius = -1
		elif path == "visual": invalid.visual.pulse_rate = NAN
		else: invalid.configuration.star_radius = 100
		check(not EnvironmentData.valid_snapshot(invalid), "Malformed solar snapshot fails closed")
	var reserved: Dictionary = EnvironmentData.instance("old-reserved",Solar.TYPE,[0,0,0])
	check(EnvironmentData.valid_instances([reserved]) and EnvironmentData.modifier_id(EnvironmentData.evaluate(state,[0,0,0],[reserved],0)) == 0, "Phase-1 reserved solar data remains loadable and neutral")
	for mode in ["exploration","defense"]:
		for seed_value in [17,1042,65537]:
			rules = rules.duplicate(true)
			rules.game_mode = mode
			rules.system_expansion = 0.0
			rules.defense_v2 = false
			state = State.new()
			var baseline = PhaseTwoState.new()
			state.start(0,rules,seed_value)
			baseline.start(0,rules,seed_value)
			for number in range(1,5):
				var actual: Dictionary = Save.encode(state)
				var expected: Dictionary = Save.encode(baseline)
				actual.environmental_instances = actual.environmental_instances.filter(func(item): return item.type not in [Solar.TYPE, EnvironmentData.SPACE_STORM])
				for data in [actual, expected]: data.erase("temporal_rift_schedule")
				check(actual == expected, "Removing the newer phenomena matches PR #50, including asteroid data, encounters, anchors and RNG")
				check(state.environmental_instances.filter(func(item): return item.type != EnvironmentData.SPACE_STORM).size() == 2, "One unchanged asteroid formation plus one solar region per new system")
				var encoded: Dictionary = Save.encode(state)
				var restored = Save.new().decode(JSON.parse_string(JSON.stringify(encoded)),rules)
				check(restored != null and restored.environmental_instances == state.environmental_instances, "Version-3 saves restore exact solar geometry and visuals")
				for key in ["radius","visual"]:
					var invalid: Dictionary = encoded.duplicate(true)
					if key == "radius": invalid.environmental_instances[1].region.radius = -1
					else: invalid.environmental_instances[1].visual.activity = INF
					check(Save.new().decode(invalid,rules) == null, "Malformed solar instance rejected at save boundary")
				var old: Dictionary = encoded.duplicate(true)
				old.environmental_instances = actual.environmental_instances
				var old_state = Save.new().decode(old,rules)
				check(old_state != null and old_state.environmental_instances == actual.environmental_instances, "Loading old asteroid-only system does not add solar regions")
				for run_state in [state,baseline]:
					run_state.ftl_access = true
					for entry in run_state.encounters: entry.completed = true
					if run_state.is_defense(): run_state.defense.complete = true
					check(run_state.generate_system(), "Next completed system generates")
	# Physical selection uses the unchanged modifier scheduler and card behavior.
	var physical = Modifiers.new()
	var legacy = Modifiers.new()
	var card = preload("res://scripts/cards/card_data.gd").new()
	card.family = "energy"
	card.cost = 0
	card.effects = {"damage":6,"shields":9}
	for seed_value in [778899,314159]:
		physical.configure(EnvironmentData.modifier_id(frozen),seed_value)
		legacy.configure(3,seed_value)
		var a := {"hull":10000,"shields":30,"materials":100,"energy":100,"crew":100,"synthesizer":2,"reactor":2,"quarters":2}
		var b: Dictionary = a.duplicate()
		var c: Dictionary = a.duplicate()
		var d: Dictionary = a.duplicate()
		for round_number in range(1,101):
			check(physical.begin_round(round_number) == legacy.begin_round(round_number), "Solar notification and event timing unchanged")
			check(physical.active == legacy.active and physical.next_round == legacy.next_round and physical.ends_round == legacy.ends_round and physical.shields_disabled() == legacy.shields_disabled(), "Duration and both-ship shield suppression match legacy ID 3")
			var stored: Array = [a.shields,b.shields]
			physical.play(card,a,b,0.5)
			legacy.play(card,c,d,0.5)
			physical.play(card,b,a,0.5)
			legacy.play(card,d,c,0.5)
			if physical.active: check(a.shields == stored[0] and b.shields == stored[1], "Active flare preserves stored shields and suppresses shield gain for both ships")
			check(a == c and b == d and physical.rng.state == legacy.rng.state, "Stored shields, restoration, damage and combat RNG remain identical")
	physical.free()
	legacy.free()
	print("Solar regions: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
