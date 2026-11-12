extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Rifts = State.TemporalRift
const EnvironmentData = State.EnvironmentData
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const CAPTURES = "res://.godot/testlogs/temporal-rifts"

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func fresh(seed_value: int, chance: float = 1.0) -> Resource:
	var configuration: Resource = Rules.duplicate(true)
	configuration.game_mode = "defense"
	configuration.defense_v2 = false
	configuration.defense_tuning = Rules.defense_tuning.duplicate(true)
	configuration.defense_tuning.rift_spawn_chance = chance
	configuration.log_rolls = false
	var state := State.new()
	state.start(0, configuration, seed_value)
	return state


func advance(state: Resource, seconds: float) -> void:
	var at: Vector3 = state.defense.start
	state._advance_strategy(seconds, at, at, true)


func live(state: Resource) -> Dictionary:
	return Rifts.active(state.environmental_instances)


func verify_route(state: Resource, record: Dictionary) -> void:
	var unit: Dictionary = state.defense.unit_for(record.generation.encounter)
	var start: Vector3 = unit.position
	var end: Vector3 = state.defense.home
	var center: Vector3 = State.Defense.point(record.position)
	var projected := Geometry3D.get_closest_point_to_segment(center, start, end)
	check(unit.status == "active" and (not unit.mothership or state.defense.mothership_advancing),
		"Recorded route belongs to an active, moving hostile")
	check(projected.distance_to(center) < 0.009 and projected.distance_to(start) > 2.6
		and projected.distance_to(end) > 5.0, "Independent segment projection puts the center ahead on the remaining route")
	check(EnvironmentData.valid_instances(state.environmental_instances), "Live physical record validates")


func scheduling_checks() -> int:
	var example_seed := -1
	var forced := 0
	var natural := 0
	var seeds := range(1, 81) + [186, 318, 569]
	for seed_value in seeds:
		var large := fresh(seed_value)
		var split := fresh(seed_value)
		var default_chance := fresh(seed_value, 0.12)
		advance(large, 12.0)
		for step in range(720): advance(split, 1.0 / 60.0)
		advance(default_chance, 12.0)
		var large_record := live(large).duplicate(true)
		var split_record := live(split).duplicate(true)
		if not large_record.is_empty() and not split_record.is_empty():
			check(is_equal_approx(large_record.simulation.remaining, split_record.simulation.remaining),
				"Rift lifetime agrees after partitioning strategic time")
			large_record.erase("simulation")
			split_record.erase("simulation")
		check(large.rifts.evaluation == split.rifts.evaluation and large.rifts.rng.state == split.rifts.rng.state
			and is_equal_approx(large.rifts.remaining, split.rifts.remaining)
			and large_record == split_record,
			"Tick, RNG and physical record agree after partitioning strategic time for seed %d" % seed_value)
		if not live(default_chance).is_empty(): natural += 1
		if live(large).is_empty(): continue
		verify_route(large, live(large))
		forced += 1
		if example_seed < 0: example_seed = seed_value
	check(forced > 24 and natural > 0 and natural < forced / 3, "Route exclusions allow spawns and default chance keeps them rare")
	if example_seed < 0: return -1

	var state := fresh(example_seed)
	var disabled := fresh(example_seed, 0.0)
	advance(state, 11.75)
	check(live(state).is_empty() and state.rifts.evaluation == 0, "Initial delay uses strategic time")
	advance(state, 0.25)
	advance(disabled, 11.75)
	advance(disabled, 0.25)
	check(state.rng.state == disabled.rng.state and state.station_rng.state == disabled.station_rng.state
		and state.chasedown_rng.state == disabled.chasedown_rng.state and state.defense.snapshot() == disabled.defense.snapshot(),
		"Rifts leave fleet simulation and unrelated RNG streams unchanged")
	var at: Vector3 = state.defense.unit_for(live(state).generation.encounter).position
	var before: Dictionary = state.rifts.snapshot()
	var movement: Dictionary = state.defense.advance_time(30.0, at, at, false,
		state.rifts.advance_span.bind(state.defense, state.environmental_instances))
	check(movement.contact >= 0 and state.rifts.snapshot() == before, "Immediate swept contact consumes no strategic time")
	state.defense.contact = -1
	var first: String = live(state).id
	advance(state, 12.0)
	check(live(state).get("id", "") == first and state.rifts.evaluation == 2, "An occupied evaluation cannot replace the active rift")
	advance(state, 3.0)
	check(live(state).is_empty() and is_equal_approx(state.rifts.remaining, 9.0), "Expiration is exact and does not reset the next evaluation")

	var departed := fresh(example_seed)
	advance(departed, 12.0)
	departed.defense.neutralize(0)
	departed.defense.neutralize(departed.defense.mothership_index())
	check(departed.generate_system() and departed.system_number == 2 and live(departed).is_empty()
		and departed.rifts.evaluation == 0 and departed.rifts.remaining == 12.0,
		"Jumping to a new system resets the active rift and schedule")

	var blocked := fresh(example_seed)
	blocked.defense.tuning.pressure_per_second = 0.0
	blocked.defense.tuning.first_reinforcement_seconds = 120.0
	for index in [0, 1]: blocked.defense.neutralize(index)
	blocked.defense.reveal_pending = false
	advance(blocked, 24.0)
	check(live(blocked).is_empty() and blocked.rifts.evaluation == 2,
		"Stationary revealed mothership and inactive reserves cannot seed a rift")
	route_source_checks()
	return example_seed


func route_source_checks() -> void:
	var reinforcement_rifts := 0
	var mothership_rifts := 0
	for seed_value in range(1, 21):
		var reinforced := fresh(seed_value)
		reinforced.defense.tuning.first_reinforcement_seconds = 1.0
		reinforced.defense.tuning.rift_initial_delay = 2.0
		reinforced.rifts.reset(seed_value, 1, 2.0)
		for index in [0, 1]: reinforced.defense.neutralize(index)
		reinforced.defense.reveal_pending = false
		advance(reinforced, 2.0)
		if not live(reinforced).is_empty():
			verify_route(reinforced, live(reinforced))
			var unit: Dictionary = reinforced.defense.unit_for(live(reinforced).generation.encounter)
			check(unit.reinforcement and unit.spawned, "Actual moving reinforcements are eligible")
			reinforcement_rifts += 1
		var escalated := fresh(seed_value)
		escalated.defense.tuning.maximum_reinforcements = 0
		escalated.defense.tuning.pressure_per_second = 100.0
		escalated.rifts.reset(seed_value, 1, 2.0)
		for index in [0, 1]: escalated.defense.neutralize(index)
		escalated.defense.reveal_pending = false
		advance(escalated, 2.0)
		if not live(escalated).is_empty():
			verify_route(escalated, live(escalated))
			check(live(escalated).generation.encounter == escalated.defense.mothership_index(),
				"Mothership can seed a rift after real pressure-driven advancement")
			mothership_rifts += 1
	check(reinforcement_rifts > 0 and mothership_rifts > 0, "Both moving route sources produced real rifts")


func roundtrip(value: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(value))


func persistence_checks(seed_value: int) -> void:
	var state := fresh(seed_value)
	var old := Save.encode(state)
	old.erase("temporal_rift_schedule")
	for unit in old.defense.units: unit.erase("route_origin")
	var legacy: Resource = Save.new().decode(roundtrip(old), state.rules)
	check(legacy != null and legacy.rifts.remaining == 12.0 and live(legacy).is_empty(), "Old saves start with safe local defaults")
	advance(state, 14.25)
	var saved := roundtrip(Save.encode(state))
	var restored: Resource = Save.new().decode(saved, state.rules)
	check(restored != null, "Active-rift save decodes")
	if restored == null: return
	check(restored.rifts.snapshot() == state.rifts.snapshot() and live(restored) == live(state),
		"Lifetime, identity, position, evaluation countdown and RNG survive a save")
	var bad := saved.duplicate(true)
	bad.temporal_rift_schedule.evaluation = 0
	check(Save.new().decode(bad, state.rules) == null, "Live rift must agree with its scheduler")
	bad = saved.duplicate(true)
	bad.environmental_instances.append(live(state).duplicate(true))
	bad.environmental_instances.back().id = "duplicate-rift"
	check(Save.new().decode(bad, state.rules) == null, "Save validation enforces one live rift")
	advance(state, 12.75)
	for step in range(102): advance(restored, 0.125)
	check(restored.rifts.snapshot() == state.rifts.snapshot() and live(restored).is_empty() and live(state).is_empty(),
		"Reloaded scheduler continues through occupied tick and expiration")


func combat_checks(seed_value: int) -> void:
	var state := fresh(seed_value)
	advance(state, 12.0)
	var record := live(state)
	var index := int(record.generation.encounter)
	var unit: Dictionary = state.defense.unit_for(index)
	var center := State.Defense.point(record.position)
	var distance: float = unit.position.distance_to(center)
	advance(state, distance / state.defense.tuning.enemy_speed)
	check(state.preview_modifier(index) == 5, "Enemy naturally travels into the physical region and gains modifier ID 5")
	state.defense.turrets["test"] = {"type": State.Defense.Installations.KINETIC, "owner": "player", "position": record.position,
		"radius": 7.0, "damage": 5, "interval": 2}
	var snapshot: Dictionary = state.battle_environment(index)
	check(snapshot.type == Rifts.TYPE and snapshot.get("friendly_support", {}).get("damage") == 5,
		"Friendly Turret Support remains independently selectable")
	state.defense.turrets.clear()
	var at: Array = state.battle_location(index)
	var solar: Dictionary = EnvironmentData.Solar.generate(1, 1, at, 2.0)
	var storm: Dictionary = EnvironmentData.Storms.generate(1, 1, 1.0, [], [])
	storm.position = at.duplicate()
	var asteroid: Dictionary = EnvironmentData.Asteroids.generate(1, 1, [])[0]
	asteroid.position = at.duplicate()
	asteroid.region = {"shape":"pockets", "angle":0.0, "half_height":1.0,
		"pockets":[{"offset":[0.0, 0.0], "axes":[3.0, 2.0], "angle":0.0}]}
	check(EnvironmentData.evaluate(state, at, [storm, record, asteroid]).type == Rifts.TYPE, "Rift wins over asteroid and storm")
	check(EnvironmentData.evaluate(state, at, [record, solar]).type == EnvironmentData.SOLAR_INTERFERENCE, "Solar retains priority")
	check(EnvironmentData.modifier_id(EnvironmentData.evaluate(state, at, [record, solar], index, 7)) == 7, "Legacy assignments retain priority")
	var persistence := Persistence.new()
	persistence.enabled = false
	state.defense.contact = index
	var entry: Dictionary = persistence.checkpoint_battle(state, index, 9812)
	var store := Save.new()
	store.path = "user://temporal_rift_test_%d.json" % OS.get_process_id()
	check(entry.saved and store.save_data(persistence.battle_checkpoint, persistence.battle_marker), "Battle checkpoint accepts the physical rift")
	var loaded: Dictionary = store.load_run()
	check(loaded.get("battle", {}).get("environment", {}) == entry.environment, "Frozen rift survives battle checkpoint restoration")
	store.clear_run()
	var setup = state.prepare_battle(index, null, entry.environment)
	check(setup != null, "Authoritative contact prepares the battle")
	if setup == null: return
	state.defense.contact = -1
	advance(state, float(record.simulation.remaining))
	check(live(state).is_empty() and setup.modifier == 5 and setup.environment == entry.environment
		and setup.environment.configuration.region.is_read_only(), "Live expiration leaves an already prepared battle frozen")


# Use the same capped process clock as the visual fade, not SceneTreeTimer's
# elapsed clock. The original 0.23 + 0.52 duration and cleanup assertion stay.
func observe_visual_time(seconds: float) -> void:
	var elapsed := 0.0
	var deadline := Time.get_ticks_msec() + 10000
	while elapsed < seconds and Time.get_ticks_msec() < deadline:
		await process_frame
		elapsed += root.get_process_delta_time()
	# process_frame precedes node callbacks and their queued deletion.
	await process_frame
	check(elapsed >= seconds, "Visual process-clock observation completes")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var filename := "%s/%s-%s.png" % [CAPTURES, label, RenderingServer.get_current_rendering_method()]
	check(root.get_texture().get_image().save_png(filename) == OK, "Captured " + label)


func presentation_checks(seed_value: int) -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	var state := fresh(seed_value)
	advance(state, 11.75)
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state": state, "battle": {}}
	root.add_child(host)
	for frame in range(5): await process_frame
	var map = host.star_map
	map.camera.overview(map.settings, true)
	check(not is_instance_valid(map.rift_visual), "No visual before a scheduled spawn")
	advance(state, 0.25)
	var record := live(state)
	var visual: Node3D = map.rift_visual
	check(is_instance_valid(visual) and visual.position == State.Defense.point(record.position)
		and visual.materials.size() == 2, "World-space aperture and boundary appear at the authoritative center")
	if not is_instance_valid(visual):
		host.free()
		return
	var before: Dictionary = state.rifts.snapshot()
	await create_timer(0.85).timeout
	check(visual.opacity > 0.95 and state.rifts.snapshot() == before and visual.caption.text.ends_with("15s"),
		"Presentation fades in without consuming strategic lifetime")
	await capture("route-and-nearby-regions")
	map.camera.frame(visual.position + Vector3(1.5, 11.0, 10.5), visual.position, 0.0, &"rift_capture")
	await capture("oblique-aperture")
	map.camera.overview(map.settings, true)
	var index := int(record.generation.encounter)
	var unit: Dictionary = state.defense.unit_for(index)
	var to_center: float = unit.position.distance_to(visual.position)
	advance(state, to_center / state.defense.tuning.enemy_speed)
	check(map.rift_visual == visual and state.preview_modifier(index) == 5, "Moving through the region updates existing hostile preview")
	var frozen: Dictionary = state.battle_environment(index)
	await capture("hostile-crossing")
	host._inspect_marker(index)
	for frame in range(18): await process_frame
	var details: Button = host.view.find_child("ModifierDetails", true, false)
	check(is_instance_valid(details) and details.visible and details.text.contains("Temporal Rift"),
		"Existing tactical inspection identifies Temporal Rift")
	await capture("affected-encounter")
	host._dismiss_inspection()
	map.camera.overview(map.settings, true)
	advance(state, float(record.simulation.remaining))
	check(live(state).is_empty() and visual.closing and not visual.caption.visible, "Expiration removes mechanics before presentation fades")
	await observe_visual_time(0.23)
	await capture("closing")
	await observe_visual_time(0.52)
	check(not is_instance_valid(visual), "Expired visual cleans itself up")
	state.defense.contact = index
	host.start_battle(index, 9812, frozen)
	check(is_instance_valid(host.battle) and host.battle.modifier.kind == 5,
		"The live board honors a frozen rift after the world visual closes")
	if is_instance_valid(host.battle):
		host.battle.enemy_timer.stop()
		for frame in range(5): await process_frame
		await capture("frozen-battle")
	host.free()


func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer is active")
	var example := scheduling_checks()
	if example >= 0:
		persistence_checks(example)
		combat_checks(example)
		await presentation_checks(example)
	root.get_node("Music").play_track("")
	await create_timer(0.15).timeout
	print("Physical temporal rifts: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
