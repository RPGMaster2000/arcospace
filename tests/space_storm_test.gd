extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Storms = preload("res://scripts/expedition/storm_regions.gd")
const StormVisual = preload("res://scripts/presentation/star_system/space_storm.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
const Solar = preload("res://scripts/expedition/solar_regions.gd")
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const CAPTURES = "res://.godot/testlogs/space-storms"

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh(mode: String, chance: float = 0.0, seed_value: int = 1042) -> Resource:
	var configuration: Resource = Rules.duplicate(true)
	configuration.game_mode = mode
	configuration.space_storm_chance = chance
	configuration.log_rolls = false
	var state := State.new()
	state.start(0, configuration, seed_value)
	return state

func generation_checks() -> Dictionary:
	var examples := {}
	var generated := 0
	for seed_value in range(160):
		var storm := Storms.generate(seed_value, 1, 0.32, [], [])
		check(storm == Storms.generate(seed_value, 1, 0.32, [], []), "Identical input reproduces the same instance")
		if storm.is_empty(): continue
		generated += 1
		examples[storm.configuration.subtype] = storm
		check(EnvironmentData.valid_instances([storm]), "Generated geometry and metadata are valid")
		check(absf(storm.position[0]) + storm.region.axes[0] <= 28.0
			and absf(storm.position[2]) + storm.region.axes[2] <= 28.0, "Storm fits inside the navigable map")
	check(generated > 30 and generated < 75, "Default distribution leaves many systems clear")
	check(examples.size() == 3, "All three subtypes can be generated")
	var target := [17.0, 0.0, 0.0]
	var anchored := Storms.generate(7, 1, 1.0, [target], [])
	check(anchored.position == target, "Eligible hostile position is preferred")
	for mode in ["exploration", "defense"]:
		for seed_value in [7, 17, 1042]:
			var enabled := fresh(mode, 1.0, seed_value)
			var disabled := fresh(mode, 0.0, seed_value)
			var records: Array = enabled.environmental_instances.filter(func(item): return item.type == Storms.TYPE)
			check(records.size() == 1, "Enabled systems generate exactly one major storm")
			check(disabled.environmental_instances.all(func(item): return item.type != Storms.TYPE), "Zero chance disables generation")
			var data := Save.encode(enabled)
			data.environmental_instances = data.environmental_instances.filter(func(item): return item.type != Storms.TYPE)
			check(data == Save.encode(disabled), "Storm generation leaves all existing save data and RNG streams unchanged")
	return examples

func environment_checks(examples: Dictionary) -> void:
	var state := fresh("defense")
	state.salvage = 100
	var sites: Array = state.defense.construction_sites.keys()
	check(not sites.is_empty() and state.deploy_turret(sites[0]), "Fixture deploys an authoritative friendly turret")
	if state.defense.turrets.is_empty(): return
	var center: Array = state.defense.turrets[sites[0]].position
	state.defense.unit_for(0).position = State.Defense.point(center)
	state.defense.contact = 0
	var index := 0
	var expected := {"ion": 2, "metal": 6, "psionic": 7}
	for subtype in Storms.SUBTYPES:
		var storm: Dictionary = examples[subtype].duplicate(true)
		storm.position = center.duplicate()
		state.environmental_instances = [storm]
		var selection: int = expected[subtype]
		check(storm.visual.color == Modifiers.storm_color(selection).to_html(false), "Map palette matches combat " + subtype)
		check(Storms.contains(storm, center), "Center is inside")
		for axis in range(3):
			var edge := center.duplicate()
			edge[axis] += float(storm.region.axes[axis]) * 0.999
			check(Storms.contains(storm, edge), "Point just inside the axis is covered")
			edge[axis] += 0.05
			check(not Storms.contains(storm, edge), "Point outside the axis is clear")
		var snapshot: Dictionary = state.battle_environment(index)
		check(EnvironmentData.valid_snapshot(snapshot) and EnvironmentData.modifier_id(snapshot) == selection
			and state.preview_modifier(index) == selection, "Authoritative location selects the existing modifier")
		check(snapshot.friendly_support.damage == 5 and snapshot.friendly_support.interval == 2, "Friendly turret support remains independent")
		var persistence := Persistence.new()
		persistence.enabled = false
		var entry: Dictionary = persistence.checkpoint_battle(state, index, 9812)
		var store := Save.new()
		store.path = "user://space_storm_test.json"
		check(entry.saved and store.save_data(persistence.battle_checkpoint, persistence.battle_marker), "Frozen storm saves through the battle checkpoint")
		var loaded: Dictionary = store.load_run()
		check(loaded.get("battle", {}).get("environment", {}) == snapshot, "Battle entry survives disk restoration")
		store.clear_run()
		var encoded := Save.encode(state)
		var restored: Resource = Save.new().decode(JSON.parse_string(JSON.stringify(encoded)), state.rules)
		check(restored != null and restored.environmental_instances == JSON.parse_string(JSON.stringify([storm])), "World storm restores exactly")
		var invalid := encoded.duplicate(true)
		invalid.environmental_instances[0].region.axes[1] = 0.0
		check(Save.new().decode(invalid, state.rules) == null, "Invalid geometry fails save validation")
		invalid = encoded.duplicate(true)
		invalid.environmental_instances[0].visual.color = "ffffff"
		check(Save.new().decode(invalid, state.rules) == null, "Invalid palette fails save validation")
		state.environmental_instances.clear()
		check(snapshot.is_read_only() and snapshot.configuration.region.axes.is_read_only()
			and snapshot == entry.environment and state.preview_modifier(index) == 0, "Live changes cannot affect a frozen snapshot")
		var setup = state.prepare_battle(index, null, entry.environment)
		check(setup.modifier == selection and setup.environment == snapshot, "Battle setup consumes the frozen physical selection")
		state.active_battle = -1
		var actual = Modifiers.new()
		var legacy = Modifiers.new()
		actual.configure(setup.modifier, entry.seed)
		legacy.configure(selection, entry.seed)
		for round_number in range(1, 65):
			check(actual.begin_round(round_number) == legacy.begin_round(round_number)
				and actual.forecast_context() == legacy.forecast_context()
				and actual.rng.state == legacy.rng.state, "Physical entry preserves legacy scheduling, scaling and RNG")
		actual.free()
		legacy.free()
		var asteroid: Dictionary = Asteroids.generate(7, 1, [])[0]
		asteroid.position = center.duplicate()
		asteroid.region = {"shape":"pockets", "angle":0.0, "half_height":1.0,
			"pockets":[{"offset":[0.0, 0.0], "axes":[3.0, 2.0], "angle":0.0}]}
		asteroid.configuration.subtype = "concentration"
		var solar := Solar.generate(7, 1, center, 2.52)
		state.environmental_instances = [storm, asteroid]
		check(state.preview_modifier(index) == 1, "Asteroid field retains priority over a storm")
		state.environmental_instances.append(solar)
		check(state.preview_modifier(index) == 3, "Solar interference retains priority")
		state.encounters[index].modifier = 5
		check(state.preview_modifier(index) == 5, "Explicit legacy assignments retain priority")
		state.encounters[index].modifier = 0
	var old := Save.encode(state)
	old.erase("environmental_instances")
	var restored_old: Resource = Save.new().decode(old, state.rules)
	check(restored_old != null and restored_old.environmental_instances.is_empty(), "Older saves never backfill a storm")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var filename := "%s/%s-%s.png" % [CAPTURES, label, RenderingServer.get_current_rendering_method()]
	check(root.get_texture().get_image().save_png(filename) == OK, "Captured " + label)

func presentation_checks(examples: Dictionary) -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	for subtype in Storms.SUBTYPES:
		var state := fresh("defense")
		var storm: Dictionary = examples[subtype].duplicate(true)
		storm.position = state.battle_location(0)
		state.environmental_instances = [storm]
		var host = preload("res://scenes/expedition.tscn").instantiate()
		host.persistence_enabled = false
		host.play_system_intro = false
		host.resume_data = {"state":state, "battle":{}}
		root.add_child(host)
		for frame in range(5): await process_frame
		var map = host.star_map
		map.camera.overview(map.settings, true)
		for frame in range(3): await process_frame
		var visual: Node3D = map.visual_root.get_node("PhysicalSpaceStorm")
		check(visual.position == State.Defense.point(storm.position) and visual.get_child_count() == 4, "World proxy uses saved origin and four draws")
		var axes: Vector3 = State.Defense.point(storm.region.axes)
		for i in range(StormVisual.SLICES.size()):
			var sheet: MeshInstance3D = visual.get_child(i)
			var height: float = StormVisual.SLICES[i]
			check(is_equal_approx(sheet.position.y, axes.y * height)
				and is_equal_approx(sheet.scale.x, axes.x * sqrt(1.0 - height * height))
				and is_equal_approx(sheet.scale.z, axes.z * sqrt(1.0 - height * height)), "Sheet fits its authoritative ellipsoid section")
		var control: Control = map.storm_legend
		var button: Button = control.get_child(0).get_child(0)
		var family: String = Modifiers.storm_family(Storms.modifier_id(subtype)).capitalize()
		check(control.visible and button.text.contains(family)
			and map.point_is_reserved(button.get_global_rect().get_center()), "Storm legend identifies the family and owns its input")
		var before: Array = state.navigation.position.duplicate()
		button.pressed.emit()
		check(control.get_child(0).get_child(1).visible and state.navigation.position == before, "Touch-accessible legend expands without navigating")
		await process_frame
		check(root.get_visible_rect().encloses(control.get_global_rect()), "Expanded legend fits in the viewport")
		await capture(subtype)
		host._inspect_marker(0)
		for frame in range(18): await process_frame
		var details: Button = host.view.find_child("ModifierDetails", true, false)
		check(details != null and details.visible and details.text.to_lower().contains(subtype), "Hostile briefing identifies the selected storm")
		if subtype == "ion":
			await capture("ion-hostile-inspection")
			host._dismiss_inspection()
			state.defense.contact = 0
			host.show_system()
			host.start_battle(0, 9812)
			check(is_instance_valid(host.battle), "Contact inside the storm opens the existing battle")
			if is_instance_valid(host.battle):
				host.battle.enemy_timer.stop()
				check(host.battle.modifier.kind == 2 and host.battle.battle_environment.type == Storms.TYPE,
					"Live board uses the frozen Ion modifier")
				for frame in range(5): await process_frame
				await capture("ion-battle")
		host.free()
		await process_frame

func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer is active")
	var examples := generation_checks()
	if examples.size() == 3:
		environment_checks(examples)
		await presentation_checks(examples)
	print("Physical space storms: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
