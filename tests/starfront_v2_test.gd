extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Visual = preload("res://scripts/presentation/star_system/visual_system.gd")
const DefenseVisual = preload("res://scripts/presentation/star_system/defense_presentation.gd")
const Settings = preload("res://resources/presentation/star_system_settings.tres")
const CAPTURES = "res://.godot/testlogs/starfront-v2"

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh(seed_value: int = 1042, modern: bool = true, reserves: int = -1) -> Resource:
	var rules: Resource = Rules.duplicate(true)
	rules.defense_v2 = modern
	rules.defense_tuning = Rules.defense_tuning.duplicate(true)
	if reserves >= 0: rules.defense_tuning.v2_maximum_reinforcements = reserves
	rules.log_rolls = false
	rules.space_storm_chance = 1.0
	var state := State.new()
	state.start(0, rules, seed_value)
	return state

func advance(state: Resource, seconds: float) -> void:
	var at: Vector3 = state.defense.start
	state._advance_strategy(seconds, at, at, true)

func quiet_attackers(state: Resource) -> void:
	for unit in state.defense.units:
		if unit.mothership or unit.status != "active": continue
		state.defense.neutralize(unit.encounter)
		state.encounters[unit.encounter].completed = true

func layout(state: Resource) -> Dictionary:
	var data := Visual.generate(state.seed_used, state.system_number, [], Settings,
		state.system_profile, state.layout_expansion, state.orbit_clearance)
	var sizes := State.SystemLayout.planetary_radii(state.encounters)
	DefenseVisual.layout(data, state.defense.snapshot(), sizes.keys(), state.layout_expansion, state.orbit_clearance, sizes)
	return data

func generation_checks() -> void:
	var counts := [0, 0]
	var distance_min := INF
	var distance_max := 0.0
	var regions := {}
	for seed_value in range(1, 121):
		var state := fresh(seed_value)
		var fleet: RefCounted = state.defense
		var count: int = fleet.active_attackers()
		check(count >= 2 and count <= 3 and fleet.units.size() == count + 4, "Starting roster has 2–3 attackers, a boss and three reserves")
		counts[count - 2] += 1
		check(fleet.snapshot() == fresh(seed_value).defense.snapshot(), "Fleet generation is deterministic")
		var start := State.Defense.wire(fleet.start)
		var home := State.Defense.wire(fleet.home)
		var directions: Array[Vector3] = []
		for unit in fleet.units:
			if unit.status == "reserve": continue
			var pos: Vector3 = unit.position
			check(pos.distance_to(fleet.start) > fleet.tuning.interception_radius, "Deployment clears player interception radius")
			check(Geometry3D.get_closest_point_to_segment(Vector3.ZERO, pos, fleet.home).length() > 2.52,
				"Approach clears the stellar surface")
			if not unit.mothership:
				directions.append((pos - fleet.home).normalized())
				var ratio: float = pos.length() / (fleet.tuning.hostile_spawn_distance * state.layout_expansion)
				check(ratio >= 0.7499 and ratio <= 1.2001, "Initial attacker fits the widened deployment band")
				distance_min = minf(distance_min, ratio)
				distance_max = maxf(distance_max, ratio)
		check(directions[0].dot(directions[1]) < 0.7, "Attacker approach directions are meaningfully separated")
		check(start.size() == 3 and home.size() == 3, "Defense points remain wire-compatible")
		var visual := layout(state)
		var bands: Array[Vector2] = []
		for planet in visual.planets:
			bands.append(Vector2(planet.distance, Visual.planet_extent(planet)))
		var sizes := State.SystemLayout.planetary_radii(state.encounters)
		check(visual.poi_orbits.size() == sizes.size(), "Each planetary PoI owns exactly one orbit")
		for index in visual.poi_orbits:
			bands.append(Vector2(visual.poi_orbits[index].distance, sizes[index]))
		bands.sort_custom(func(a, b): return a.x < b.x)
		for i in range(1, bands.size()):
			check(bands[i].x - bands[i - 1].x + 0.0001 >= bands[i].y + bands[i - 1].y + state.orbit_clearance,
				"Neighboring orbits clear their visible radii at worst alignment for seed %d" % seed_value)
		for item in state.environmental_instances:
			var intersects := false
			for unit in fleet.units:
				if unit.status == "reserve": continue
				for step in range(257):
					var point: Vector3 = unit.route_origin.lerp(fleet.home, step / 256.0)
					if _contains(item, State.Defense.wire(point)):
						intersects = true
						break
				check(not _contains(item, State.Defense.wire(unit.route_origin)), "Initial fleet deploys outside environment")
			check(intersects, "Independent route samples verify " + item.type)
			regions[item.type] = int(regions.get(item.type, 0)) + 1
	check(absf(counts[0] / 120.0 - 0.4) < 0.12, "Seed sweep follows the 40/60 fleet weighting")
	check(distance_min < 0.85 and distance_max > 1.15, "Seed sweep reaches both ends of the widened deployment band")
	check(regions.size() == 3 and regions.values().min() > 15, "Solar, asteroid and storm coverage remains common")

func _contains(item: Dictionary, at: Array) -> bool:
	match item.type:
		State.EnvironmentData.ASTEROID_FIELD: return State.EnvironmentData.Asteroids.contains(item, at)
		State.EnvironmentData.SOLAR_INTERFERENCE: return State.EnvironmentData.Solar.contains(item, at)
		State.EnvironmentData.SPACE_STORM: return State.EnvironmentData.Storms.contains(item, at)
	return false

func timing_checks() -> void:
	var state := fresh(1042, true, 0)
	var fleet: RefCounted = state.defense
	var boss: Dictionary = fleet.unit_for(fleet.mothership_index())
	var origin: Vector3 = boss.position
	quiet_attackers(state)
	check(not fleet.revealed and fleet.pressure_rate() == 1.0, "Neutralizing attackers does not reveal the boss and pressure rate is halved")
	advance(state, 49.0)
	check(fleet.pressure == 49.0 and not fleet.revealed, "Boss remains hidden below 50 pressure")
	check(fleet.reinforcements_spawned == 0 and fleet.reinforcement_remaining == 0.0,
		"A v2 roster without reserves retains its original behavior")
	advance(state, 1.0)
	check(fleet.revealed and not fleet.mothership_advancing and boss.position == origin, "Pressure 50 reveals the stationary mothership")
	advance(state, 8.0)
	var id: int = fleet.missiles.active.keys()[0]
	var missile: Dictionary = fleet.missiles.active[id]
	check(missile.origin == boss.position and missile.hull == fleet.tuning.missile_hull, "Missile launches at the actual mothership with independent Hull")
	advance(state, 2.0)
	check(is_equal_approx(fleet.missiles.position(missile, fleet.home).distance_to(origin), fleet.tuning.enemy_speed * 4.0), "Missile moves at twice ordinary attacker speed")
	check(state.prepare_battle(id) == null and not state.can_engage(id), "Missiles cannot open card combat")
	var saved := Save.encode(state)
	var restored := Save.new().decode(JSON.parse_string(JSON.stringify(saved)), state.rules)
	check(restored != null, "Active missile checkpoint loads")
	if restored == null: return
	check(JSON.stringify(restored.defense.missiles.snapshot(restored.defense.home)) == JSON.stringify(fleet.missiles.snapshot(fleet.home)), "Missile positions and launch countdown roundtrip")
	advance(state, 25.0)
	for step in range(100): advance(restored, 0.25)
	check(fleet.integrity == 88 and fleet.integrity == restored.defense.integrity and fleet.pressure == restored.defense.pressure,
		"Missile impacts are step-independent and apply damage once")
	advance(state, 15.0)
	check(fleet.mothership_advancing and fleet.pressure == 100.0, "Pressure 100 starts advancement")
	advance(state, 13.0)
	check(boss.position != origin and fleet.missiles.next_id >= id + 4, "Advancing mothership continues to launch missiles")
	fleet.contact = fleet.mothership_index()
	check(state.prepare_battle(fleet.mothership_index()) != null, "Mothership still enters ordinary boss combat")
	fleet.neutralize(fleet.mothership_index())
	check(fleet.complete and fleet.missiles.active.is_empty() and fleet.missiles.pending == -1, "Boss neutralization secures remaining missiles")

func defense_checks() -> void:
	var state := fresh(1042, true, 0)
	quiet_attackers(state)
	var fleet: RefCounted = state.defense
	advance(state, 58.0)
	var id: int = fleet.missiles.active.keys()[0]
	var missile: Dictionary = fleet.missiles.active[id]
	var at: Vector3 = fleet.missiles.position(missile, fleet.home)
	var gun: Vector3 = at.lerp(fleet.home, 0.4)
	fleet.turrets["fixture"] = {"position": State.Defense.wire(gun), "radius": 4.0}
	var flight: Dictionary = fleet.advance_time(14.0, fleet.start, fleet.start, true)
	check(flight.missile_shots.size() == 2 and not fleet.missiles.active.has(id)
		and fleet.integrity == 100, "Two swept turret shots destroy a missile before impact")
	fleet.turrets.clear()

	var original := fresh(81, false)
	original.defense.neutralize(0)
	original.encounters[0].completed = true
	var restored := Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(original))))
	check(restored != null and not restored.defense.v2 and restored.defense.reveal_pending and restored.defense.missiles.active.is_empty(),
		"Legacy saves keep their revealed fleet and launch no invented missiles")

func reinforcement_checks() -> void:
	var state := fresh()
	quiet_attackers(state)
	advance(state, 29.75)
	check(state.defense.reinforcements_spawned == 0 and state.defense.reinforcement_remaining == 0.25,
		"The first reserve waits 30 strategic seconds")
	advance(state, 0.25)
	check(state.defense.reinforcements_spawned == 1 and not state.defense.revealed,
		"Regular reinforcements can arrive before mothership reveal")
	var first: Dictionary = state.defense.units[-3]
	check(first.status == "active" and first.spawned and first.route_origin.distance_to(state.defense.start) > 3.5
		and Geometry3D.get_closest_point_to_segment(Vector3.ZERO, first.route_origin, state.defense.home).length() >= 3.5,
		"The reserve deploys on a clear approach outside player contact")
	advance(state, 4.75)
	var restored := Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))), state.rules)
	check(restored != null and restored.defense.reinforcement_remaining == 25.25,
		"An unrevealed system restores its partly elapsed reserve countdown")
	if restored == null: return
	advance(state, 25.25)
	for step in range(101): advance(restored, 0.25)
	check(state.defense.reinforcements_spawned == 2 and restored.defense.reinforcements_spawned == 2
		and state.defense.reinforcement_remaining == restored.defense.reinforcement_remaining,
		"Save/load and timestep subdivision preserve the second deployment")
	check(state.defense.missiles.next_id == restored.defense.missiles.next_id
		and state.defense.missiles.active.size() == 1 and state.defense.active_attackers() == 2,
		"Missile launch at 58 coexists with regular deployment at 60")
	for current in [state, restored]:
		quiet_attackers(current)
		advance(current, 30.0)
		check(current.defense.reinforcements_spawned == 3, "Third reserve deploys at 90")
		quiet_attackers(current)
		advance(current, 30.0)
		check(current.defense.reinforcements_spawned == 3, "A system deploys at most three reserves")

	var capped := fresh()
	capped.defense.tuning.enemy_speed = 0.0
	advance(capped, 35.0)
	check(capped.defense.reinforcements_spawned == 0, "A due reserve waits while at least two attackers are active")
	for unit in capped.defense.units:
		if capped.defense.active_attackers() < 2: break
		if not unit.mothership and unit.status == "active": capped.defense.neutralize(unit.encounter)
	advance(capped, 0.25)
	check(capped.defense.reinforcements_spawned == 1 and capped.defense.active_attackers() == 2,
		"The waiting reserve deploys when room opens under the cap")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var path := "%s/%s-%s.png" % [CAPTURES, label, RenderingServer.get_current_rendering_method()]
	check(root.get_texture().get_image().save_png(path) == OK, "Captured " + label)

func presentation_checks() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	var state := fresh(44, true, 0)
	for seed_value in range(1, 50):
		var candidate := fresh(seed_value, true, 0)
		if candidate.defense.active_attackers() == 3 and candidate.environmental_instances.size() == 3:
			state = candidate
			break
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state": state, "battle": {}}
	root.add_child(host)
	for frame in range(5): await process_frame
	var map = host.star_map
	map.fit_overview()
	check(host.jump_button.text.contains("FTL") and (not is_instance_valid(map.storm_legend) or map.storm_legend.position.x < 250.0),
		"FTL status stays visible with storm information away from its panel")
	for i in range(3):
		advance(state, 2.0)
		await process_frame
	host._refresh_defense_hud()
	await capture("fleet-and-orbits")
	var construction = map.defense_effects.construction
	var before: Transform3D = map.camera.transform
	state.salvage = 40
	host.resource_bar.exploration(state)
	construction.button.pressed.emit()
	check(construction.transition and construction.build.disabled, "Construction locks confirmation during camera focus")
	await create_timer(0.48).timeout
	var first: String = construction.selected
	check(map.camera.viewing == &"construction" and not construction.transition, "Construction focuses on a site")
	for arrow in construction.arrows:
		check(arrow.size.x >= 64.0 and root.get_visible_rect().encloses(arrow.get_global_rect()),
			"Construction arrow is fully visible and sized for touch")
	await capture("construction-first")
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	construction._unhandled_input(right)
	var second: String = construction.selected
	construction.arrows[1].pressed.emit()
	check(first != second and construction.selected == second and construction.build.disabled, "Arrow cannot stack a camera transition")
	await create_timer(0.48).timeout
	await capture("construction-next")
	construction.popup.hide()
	check(map.camera.transform.is_equal_approx(before), "Closing construction restores the prior camera")
	quiet_attackers(state)
	advance(state, 44.0)
	host._refresh_defense_hud()
	await capture("reveal")
	advance(state, 11.0)
	host._refresh_defense_hud()
	var id: int = state.defense.missiles.active.keys()[0]
	check(map.objects.has(id) and map.markers.has(id), "Missile is a selectable world object")
	await capture("missile-flight")
	var at: Vector3 = state.defense.missiles.position(state.defense.missiles.active[id], state.defense.home)
	host.phase = host.Phase.TRAVELING
	state._advance_strategy(0.25, at + Vector3(0, 0, 1), at, false)
	check(state.defense.missiles.pending == id and host.view_kind == "poi" and not is_instance_valid(host.battle), "Swept contact opens the PoI-style missile screen")
	var checkpoint := Save.encode(state)
	var restored := Save.new().decode(JSON.parse_string(JSON.stringify(checkpoint)), state.rules)
	check(restored != null and restored.defense.missiles.pending == id, "Pending missile interaction survives save/load")
	await create_timer(0.95).timeout
	await capture("interception")
	host._resolve_missile(id, "direct")
	check(not state.has_missile(id) and not state.resolve_missile(id, "direct") and state.salvage == 40, "Resolution removes the missile exactly once with no salvage")
	map.camera.overview(map.settings, true)
	await process_frame
	advance(state, 15.0)
	var fleet: RefCounted = state.defense
	var tracked: int = fleet.missiles.active.keys()[0]
	var missile: Dictionary = fleet.missiles.active[tracked]
	var origin: Vector3 = missile.origin
	for site in fleet.construction_sites:
		var center := State.Defense.point(fleet.construction_sites[site].position)
		var closest := Geometry3D.get_closest_point_to_segment(center, origin, fleet.home)
		if center.distance_to(closest) > fleet.tuning.turret_radius - 1.5: continue
		if state.deploy_turret(site): break
	check(not fleet.turrets.is_empty(), "A real construction site covers the incoming missile route")
	if not fleet.turrets.is_empty():
		var turret: Dictionary = fleet.turrets.values()[0]
		var center := State.Defense.point(turret.position)
		map.camera.frame(center + Vector3(1.0, 23.0, 24.0), center, 0.0, &"interception_capture")
		for step in range(40):
			if not fleet.missiles.active.has(tracked): break
			advance(state, 0.5)
		check(not fleet.missiles.active.has(tracked) and fleet.integrity == 100,
			"Installed turret destroys the missile before homeworld impact")
		host._refresh_defense_hud()
		await capture("turret-interception")
	host.free()

func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer is active")
	generation_checks()
	timing_checks()
	defense_checks()
	reinforcement_checks()
	await presentation_checks()
	root.get_node("Music").play_track("")
	await create_timer(0.15).timeout
	print("Starfront Defense v2: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
