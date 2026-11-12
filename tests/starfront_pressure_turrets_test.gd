extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
const Asteroids = preload("res://scripts/expedition/asteroid_regions.gd")
const Solar = preload("res://scripts/expedition/solar_regions.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const SCREENSHOTS = "res://.godot/testlogs/starfront-pressure-turrets"

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> Resource:
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.defense_v2 = false
	rules.defense_tuning = rules.defense_tuning.duplicate(true)
	rules.log_rolls = false
	var state := State.new()
	state.start(0, rules, 1042)
	return state

func roundtrip(state: Resource) -> Resource:
	return Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))), state.rules)

func pressure_checks() -> void:
	var state := fresh()
	var origin: Vector3 = state.defense.start
	var mother: Dictionary = state.defense.unit_for(2)
	var original: Vector3 = mother.position
	check(state.defense.pressure == 0.0, "New defense starts at zero pressure")
	state.navigation.report_movement(State.Defense.wire(origin + Vector3.RIGHT))
	check(state.defense.pressure == 0.0, "Movement report while idle consumes no strategic time")
	var next := origin.move_toward(Vector3.ZERO, 1.0)
	state.navigation.checkpoint_position(State.Defense.wire(origin))
	state.begin_free_travel(State.Defense.wire(next))
	state.navigation.report_movement(State.Defense.wire(next))
	var movement_pressure: float = state.rules.defense_tuning.seconds_per_distance * state.rules.defense_tuning.pressure_per_second
	check(is_equal_approx(state.defense.pressure, movement_pressure), "Movement charges pressure once through the existing clock")
	state.cancel_travel()
	state._commit_activity_time(1.5)
	check(is_equal_approx(state.defense.pressure, movement_pressure + 3.0), "Activity time uses the same pressure clock")
	check(mother.position == original and not state.defense.revealed, "Mothership stays hidden and stationary below maximum")

	var legacy: Dictionary = Save.encode(state)
	for key in ["pressure", "maximum_pressure", "mothership_advancing", "mothership_eta", "construction_sites", "turrets"]:
		legacy.defense.erase(key)
	var migrated: Resource = Save.new().decode(legacy, state.rules)
	check(migrated != null and migrated.defense.pressure == 0 and migrated.defense.turrets.is_empty(), "Old defense saves get neutral defaults")

	state = fresh()
	var split := fresh()
	for run_state in [state, split]:
		run_state.defense.tuning.pressure_maximum = 10.0
		run_state.defense.tuning.enemy_speed = 0.0
		run_state.defense.tuning.maximum_active_attackers = 2
	state._commit_activity_time(5.0)
	check(state.defense.mothership_advancing and state.defense.revealed and not state.defense.reveal_pending,
		"Exact threshold reveals immediately without requiring the first kill")
	check(state.defense.unit_for(2).position == original, "Threshold crossing does not teleport the mothership")
	state._commit_activity_time(2.0)
	for step in range(70): split._commit_activity_time(0.1)
	var moving: Vector3 = state.defense.unit_for(2).position
	check(state.defense.pressure == 10 and split.defense.pressure == 10, "Pressure caps in both time partitions")
	check(moving.distance_to(split.defense.unit_for(2).position) < 0.0001, "Advancement agrees across strategic time partitions")
	check(moving.distance_to(original.move_toward(state.defense.home, 1.3)) < 0.0001, "Only post-threshold time moves the mothership")
	var restored := roundtrip(state)
	check(restored != null and restored.defense.mothership_advancing and restored.defense.pressure == 10
		and moving.distance_to(restored.defense.unit_for(2).position) < 0.0001, "Save roundtrip preserves escalation, pressure and location")
	if restored != null:
		restored.defense.pressure = 0.0
		restored._commit_activity_time(1.0)
		check(restored.defense.mothership_advancing and restored.defense.unit_for(2).position.distance_to(moving) > 0.6,
			"Reducing pressure cannot undo escalation")
		var target: Vector3 = restored.defense.intercept_point(2, restored.defense.start)
		var duration: float = restored.defense.start.distance_to(target) * restored.defense.tuning.seconds_per_distance
		var event: Dictionary = restored.defense.advance_time(duration, restored.defense.start, target)
		check(event.contact == 2 and restored.can_engage(2), "Existing swept contact can engage the advancing mothership")
		check(restored.defense.neutralize(2) and restored.defense.complete and not restored.defense.mothership_advancing,
			"Neutralizing the advancing mothership secures the system")
		for unit in restored.defense.units:
			restored.encounters[unit.encounter].completed = true
		check(roundtrip(restored) != null, "Early-reveal victory restores without an attacker kill")
	var integrity: int = state.defense.integrity
	state._commit_activity_time(100.0)
	check(state.run_ended and state.defense.mothership_arrived() and not state.can_jump(), "Mothership arrival ends the expedition")
	check(state.defense.integrity == integrity, "Terminal mothership arrival is distinct from ordinary base damage")

func turret_checks() -> void:
	var state := fresh()
	var sites: Array = state.defense.construction_sites.keys()
	check(sites.size() >= 2, "Generated system offers deliberate construction choices")
	if sites.size() < 2: return
	var site: String = sites[0]
	var cost: int = state.defense.tuning.turret_salvage_cost
	state.salvage = cost - 1
	check(not state.deploy_turret(site) and state.salvage == cost - 1, "Insufficient funds leave Salvage untouched")
	state.salvage = 100
	var rng: int = state.rng.state
	check(not state.deploy_turret("empty_space"), "Only explicit sites allow construction")
	check(state.deploy_turret(site) and state.salvage == 100 - cost, "Deployment charges its exact cost")
	check(not state.deploy_turret(site) and state.salvage == 100 - cost, "Repeated deployment cannot spend or duplicate")
	check(state.deploy_turret(sites[1]) and state.defense.turrets.size() == 2, "Second installation respects capacity")
	state.defense.tuning.turret_capacity = 2
	if sites.size() > 2: check(not state.deploy_turret(sites[2]), "Capacity blocks a distinct third site")
	check(state.rng.state == rng and state.defense.pressure == 0, "Construction consumes neither strategic time nor RNG")
	var restored := roundtrip(state)
	check(restored != null and restored.defense.turrets == state.defense.turrets, "Installation locations and configuration persist")

	if restored != null:
		var center: Vector3 = State.Defense.point(restored.defense.turrets[site].position)
		var enemy: Dictionary = restored.defense.unit_for(0)
		enemy.position = center + (center - restored.defense.home).normalized() * 4.0
		var intercept: Dictionary = restored.defense.advance_time(2.0, center, center)
		check(intercept.contact == 0 and not restored.turret_support(0).is_empty(),
			"An enemy moving into the stationary player uses its swept contact position for support")
		check(enemy.status == "active", "Turrets do not damage the strategic fleet")
	var turret: Dictionary = state.defense.turrets[site]
	var position: Vector3 = State.Defense.point(turret.position)
	var hostile: Dictionary = state.defense.unit_for(0)
	hostile.position = position + Vector3.UP * (float(turret.radius) + 0.01)
	check(state.turret_support(0).is_empty(), "Outside engagement radius has no support")
	hostile.position = position + Vector3.UP * float(turret.radius)
	check(not state.turret_support(0).is_empty(), "Engagement radius includes its exact boundary")
	hostile.position = position
	state.encounters[0].modifier = 0
	var field: Dictionary = Asteroids.generate(7, 1, [])[0]
	field.position = turret.position.duplicate()
	field.region = {"shape": "pockets", "angle": 0.0, "half_height": 1.0,
		"pockets": [{"offset": [0.0, 0.0], "axes": [3.0, 2.0], "angle": 0.0}]}
	field.configuration.subtype = "concentration"
	state.environmental_instances = [field]
	var snapshot: Dictionary = state.battle_environment(0)
	check(EnvironmentData.modifier_id(snapshot) == 1 and snapshot.friendly_support.damage == 5, "Asteroid Belt and one turret effect coexist")
	state.environmental_instances.append(Solar.generate(7, 1, turret.position, 2.52))
	var overlap: Dictionary = state.battle_environment(0)
	check(EnvironmentData.modifier_id(overlap) == 3 and overlap.friendly_support == snapshot.friendly_support, "Solar priority is retained with support")
	state.environmental_instances.clear()
	state.defense.tuning.enemy_speed = 0.0
	var travel_from := position + Vector3.UP * 4.0
	state._advance_strategy(1.0, travel_from, position, false)
	check(state.defense.contact == 0 and state.can_engage(0), "Strategic contact authorizes entry within turret coverage")
	var persistence := Persistence.new()
	persistence.enabled = false
	var entry: Dictionary = persistence.checkpoint_battle(state, 0, 987)
	check(entry.saved and entry.environment.friendly_support.damage == 5, "Battle entry freezes support")
	var store := Save.new()
	store.path = "user://starfront_pressure_turrets_test.json"
	check(store.save_data(persistence.battle_checkpoint, persistence.battle_marker)
		and store.load_run().get("battle", {}).get("environment") == entry.environment, "Saved battle marker retains the frozen support")
	store.clear_run()
	var setup = state.prepare_battle(0, null, entry.environment)
	setup.battle_seed = 987
	hostile.position += Vector3.UP * 20.0
	state.defense.turrets.clear()
	check(state.turret_support(0).is_empty() and setup.environment.friendly_support.damage == 5,
		"Active setup ignores later world changes")
	var board = preload("res://scenes/board_3d.tscn").instantiate()
	board.expedition = state
	Adapter.configure(board, setup)
	board.get_node("BattleEffects").enabled = false
	board.get_node("ModifierDisplay").cinematic_enabled = false
	root.add_child(board)
	var random_states: Array = [board.modifier.rng.state, board.hand.rng.state, board.enemy_hand.rng.state, board.enemy_ai.rng.state]
	var player: Dictionary = board.ship_snapshot("player")
	board.enemy_shields = 3
	var hull: int = board.enemy_hull
	board.turn_number = 2
	board._begin_turn("player")
	check(board.enemy_shields == 3 and board.enemy_hull == hull, "No shot before two full rounds")
	board.turn_number = 3
	board._begin_turn("player")
	check(board.enemy_shields == 0 and board.enemy_hull == hull - 2, "First shot deals five shield-first damage")
	board._begin_turn("player")
	check(board.enemy_hull == hull - 2, "Re-entering a round cannot repeat a shot")
	board.turn_number = 4
	board._begin_turn("player")
	check(board.enemy_hull == hull - 2, "No shot between scheduled rounds")
	check(board.player_hull == player.hull and board.player_shields == player.shields, "Turret never damages the player")
	check(random_states == [board.modifier.rng.state, board.hand.rng.state, board.enemy_hand.rng.state, board.enemy_ai.rng.state],
		"Guaranteed shots leave unrelated RNG streams alone")
	board.enemy_hull = 5
	board.turn_number = 5
	board._begin_turn("player")
	check(board.enemy_hull == 0 and board.winner == "player" and board.result_recorded
		and state.defense.unit_for(0).status == "neutralized", "Lethal shot resolves a normal victory")
	board.free()

	restored = fresh()
	restored.salvage = 100
	restored.deploy_turret(restored.defense.construction_sites.keys()[0])
	restored.defense.revealed = true
	restored.defense.mothership_advancing = true
	restored.defense.pressure = 100
	restored.defense.neutralize(2)
	var balance: int = restored.salvage
	check(restored.generate_system() and restored.defense.pressure == 0 and restored.defense.turrets.is_empty()
		and not restored.defense.mothership_advancing and restored.salvage == balance, "FTL clears system-local pressure and installations")

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var renderer := RenderingServer.get_current_rendering_method()
	check(root.get_texture().get_image().save_png(SCREENSHOTS + "/" + name + "-" + renderer + ".png") == OK, "Saved " + name + " screenshot")

func presentation_checks() -> void:
	var state := fresh()
	state.salvage = 40
	root.size = Vector2i(1280,720)
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state": state, "battle": {}}
	root.add_child(host)
	for frame in range(8): await process_frame
	var map = host.star_map
	var construction = map.defense_effects.construction
	check(construction.button.is_visible_in_tree() and not construction.button.disabled, "Overview exposes construction")
	check(host.screen.overview_hud.metagame.text.contains("PRESSURE 0 / 100"), "Defense HUD displays pressure")
	DirAccess.make_dir_recursive_absolute(SCREENSHOTS)
	await capture("before")
	construction.button.pressed.emit()
	for frame in range(3): await process_frame
	check(construction.popup.visible and construction.preview.visible and not host._map_input_allowed()
		and construction.detail.text.contains("40 Salvage"),
		"Construction shows availability and a range preview")
	await capture("construction")
	var id: String = construction.selected
	construction.build.pressed.emit()
	check(state.defense.turrets.has(id) and construction.rings.has(id) and construction.build.disabled,
		"Build action commits the authoritative installation once")
	construction.popup.hide()
	var ring: MeshInstance3D = construction.rings[id]
	await process_frame
	await process_frame
	var panel: Control = map.defense_effects.home_panel
	var turret_screen: Vector2 = map.camera.unproject_position(ring.global_position + Vector3.UP * 0.45)
	check(not Rect2(panel.position, panel.size).has_point(turret_screen), "The homeworld HUD clears the turret model")
	await capture("deployed")
	var flank: Vector3 = Vector3.UP.cross(ring.global_position).normalized()
	state.defense.unit_for(0).position = ring.global_position + flank * 4.0
	map.sync_defense(state.defense.snapshot())
	check(ring.material_override.albedo_color == construction.COVERED, "Range highlight agrees with enemy coverage")
	check(ring.global_position.distance_to(State.Defense.point(state.defense.turrets[id].position)) < 0.0001, "Visual ring uses the authoritative position")
	await capture("covered")
	state.defense.tuning.pressure_maximum = 1.0
	state._commit_activity_time(1.0)
	host._refresh_defense_hud()
	check(host.screen.overview_hud.metagame.text.contains("MOTHERSHIP ADVANCING") and map.objects[2].visible,
		"Escalation warning and moving mothership are visible")
	await capture("advancing")
	host.free()

func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer is active")
	pressure_checks()
	turret_checks()
	await presentation_checks()
	print("Starfront pressure and turrets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
