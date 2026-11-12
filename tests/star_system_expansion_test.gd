extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Settings = preload("res://resources/presentation/star_system_settings.tres")
const Visual = preload("res://scripts/presentation/star_system/visual_system.gd")
const Layout = State.SystemLayout
const Screen = preload("res://scripts/ui/expedition_screen.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Solar = State.EnvironmentData.Solar
const CAPTURES = "res://.godot/testlogs/system-expansion"

var checks := 0
var failures := 0
var pacing := Vector3.ZERO
var expanded_pacing := Vector3.ZERO

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh(mode: String, seed_value: int, factor: float = 1.2) -> Resource:
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = mode
	rules.defense_v2 = false
	rules.system_expansion = factor
	rules.log_rolls = false
	rules.space_storm_chance = 1.0
	var state := State.new()
	state.start(0, rules, seed_value)
	return state

func entries(state: Resource) -> Array:
	return Screen.map_entries(state, func(key): return key)

func visual(state: Resource) -> Dictionary:
	var source := [] if state.is_defense() and state.layout_expansion > 0.0 else entries(state)
	var result := Visual.generate(state.seed_used, state.system_number, source, Settings,
		state.system_profile, state.layout_expansion)
	if state.is_defense():
		preload("res://scripts/presentation/star_system/defense_presentation.gd").layout(result,
			state.defense.snapshot(), Layout.planetary_indices(state.encounters), state.layout_expansion)
	return result

func verify_orbits(state: Resource, data: Dictionary) -> void:
	var orbital_bands: Array[Vector2] = []
	var assigned := {}
	for p in data.planets:
		orbital_bands.append(Vector2(p.distance, p.distance * p.eccentricity))
		var area := Layout.bounds(state.layout_expansion).grow(-float(p.radius))
		check(area.has_point(Vector2(p.position.x, p.position.z)), "Planet surface fits within the navigation bounds")
	for entry in entries(state):
		var at: Vector3 = data.anchors[entry.index]
		check(at.length() > 3.0 and Layout.bounds(state.layout_expansion).has_point(Vector2(at.x, at.z)),
			"Destination is reachable inside the navigation bounds")
		if not Visual.is_planetary(entry): continue
		check(data.assignments.has(entry.index) != data.poi_orbits.has(entry.index), "Every planetary destination has one ring")
		if data.assignments.has(entry.index):
			var ring: int = data.assignments[entry.index]
			check(not assigned.has(ring), "No other planetary destination shares the assigned ring")
			assigned[ring] = true
			continue
		var radius: float = data.poi_orbits[entry.index].distance
		check(orbital_bands.all(func(band): return absf(radius - band.x) > band.y + 0.65),
			"Planetary destination has a separate orbital path")
		orbital_bands.append(Vector2(radius, 0.0))

func verify_regions(state: Resource) -> void:
	var bounds := Layout.bounds(state.layout_expansion)
	check(State.EnvironmentData.valid_instances(state.environmental_instances), "All generated environment records validate")
	for item in state.environmental_instances:
		var center := State.Defense.point(item.position)
		if item.type == State.EnvironmentData.SPACE_STORM:
			check(absf(center.x) + item.region.axes[0] <= bounds.end.x
				and absf(center.z) + item.region.axes[2] <= bounds.end.y, "Storm stays within the expanded system")
		elif item.type == State.EnvironmentData.ASTEROID_FIELD:
			var rng := RandomNumberGenerator.new()
			rng.seed = 42
			for sample in range(32):
				var point := State.EnvironmentData.Asteroids.sample(item, rng)
				check(bounds.has_point(Vector2(point.x, point.z)), "Asteroid position lies within the map")

func verify_save(state: Resource) -> void:
	var saved := Save.encode(state)
	var configuration: Resource = state.rules.duplicate(true)
	configuration.system_expansion = 1.2
	var restored := Save.new().decode(JSON.parse_string(JSON.stringify(saved)), configuration)
	check(restored != null, "Saved layout decodes")
	if restored == null: return
	check(visual(restored) == visual(state) and restored.environmental_instances == state.environmental_instances,
		"Save restores planetary positions, encounter anchors, colors and environment geometry")
	check(restored.layout_expansion == state.layout_expansion, "Save retains its own layout factor")
	if restored.is_defense() and restored.layout_expansion == 0.0:
		restored.defense.neutralize(0)
		restored.defense.neutralize(2)
		check(restored.generate_system() and restored.layout_expansion == 1.2, "The next system from a legacy save uses the new layout")

func generation_checks() -> void:
	for mode in ["defense", "exploration"]:
		for seed_value in [1, 17, 44, 215, 1042, 65537]:
			var before := fresh(mode, seed_value, 0.0)
			var after := fresh(mode, seed_value)
			var old_layout := visual(before)
			var new_layout := visual(after)
			check(before.encounters == after.encounters and before.service == after.service, "Encounter identities and counts are preserved")
			check(before.rng.state == after.rng.state and before.station_rng.state == after.station_rng.state
				and before.chasedown_rng.state == after.chasedown_rng.state, "Expansion consumes no gameplay RNG")
			check(new_layout == visual(after), "Same seed and factor reproduce the complete layout")
			for i in mini(old_layout.planets.size(), new_layout.planets.size()):
				check(old_layout.planets[i].radius == new_layout.planets[i].radius, "Planet radius does not scale")
				if mode == "exploration":
					check(is_equal_approx(new_layout.planets[i].distance, old_layout.planets[i].distance * 1.2),
						"Planet semimajor axis expands by 20 percent")
			var old_solar: Dictionary = before.environmental_instances[1]
			var new_solar: Dictionary = after.environmental_instances[1]
			check(is_equal_approx(new_solar.region.radius, old_solar.region.radius * 0.8)
				and new_solar.configuration.star_radius == old_solar.configuration.star_radius,
				"Solar influence shrinks by 20 percent while the stellar core is unchanged")
			var edge := float(new_solar.region.radius)
			check(State.EnvironmentData.modifier_id(State.EnvironmentData.evaluate(after, [edge - 0.01, 0, 0], [new_solar])) == 3
				and State.EnvironmentData.modifier_id(State.EnvironmentData.evaluate(after, [edge + 0.01, 0, 0], [new_solar])) == 0,
				"Existing Solar Flare modifier follows the smaller boundary")
			verify_orbits(after, new_layout)
			verify_regions(after)
			verify_save(before)
			verify_save(after)
			if mode == "defense": verify_defense(before, after)

func verify_defense(before: Resource, after: Resource) -> void:
	var old_fleet: RefCounted = before.defense
	var fleet: RefCounted = after.defense
	check(fleet.home.is_equal_approx(old_fleet.home * 1.2) and fleet.start.is_equal_approx(old_fleet.start * 1.2), "Homeworld and player start expand proportionally")
	for index in [0, 1, 2]:
		var old_unit: Dictionary = old_fleet.unit_for(index)
		var unit: Dictionary = fleet.unit_for(index)
		check(unit.position.is_equal_approx(old_unit.position * 1.2)
			and is_equal_approx(unit.position.distance_to(fleet.home), old_unit.position.distance_to(old_fleet.home) * 1.2),
			"Enemy deployment and approach distance expand proportionally")
	for key in ["player_speed", "enemy_speed", "mothership_speed", "seconds_per_distance",
		"pressure_per_second", "first_reinforcement_seconds", "reinforcement_interval_seconds", "turret_radius"]:
		check(old_fleet.tuning.get(key) == fleet.tuning.get(key), "Unchanged defense tuning " + key)
	var deploy_at: Variant = fleet.spawn_position(fleet.start)
	check(deploy_at is Vector3 and Layout.bounds(after.layout_expansion).has_point(Vector2(deploy_at.x, deploy_at.z)),
		"Reinforcement spawn is reachable and within expanded bounds")
	check(not fleet.construction_sites.is_empty(), "Expanded map retains turret construction sites")
	pacing += strategic_times(old_fleet)
	expanded_pacing += strategic_times(fleet)
	# Resolve legal swept interceptions and neutralize each resulting opponent.
	# Battles themselves are already covered by the defense and combat suites.
	var player: Vector3 = fleet.start
	for attempt in range(6):
		if fleet.complete or fleet.failed(): break
		var target := -1
		var distance := INF
		for unit in fleet.units:
			if not fleet.available(unit): continue
			var candidate: Vector3 = fleet.intercept_point(unit.encounter, player)
			if candidate.distance_to(player) >= distance: continue
			distance = candidate.distance_to(player)
			target = int(unit.encounter)
		if target < 0: break
		var at: Vector3 = fleet.intercept_point(target, player)
		var flight: Dictionary = fleet.advance_time(maxf(0.01, distance / fleet.tuning.player_speed), player, at)
		player = flight.position
		if flight.contact >= 0:
			fleet.neutralize(flight.contact)
			fleet.reveal_pending = false
	check(fleet.complete and fleet.integrity > 0, "A legal interception sequence completes the expanded system")

func strategic_times(fleet: RefCounted) -> Vector3:
	var slots: Array = fleet.anchors.values()
	var travel := 0.0
	var legs := 0
	for a in slots.size():
		for b in range(a + 1, slots.size()):
			travel += slots[a].distance_to(slots[b]) * fleet.tuning.seconds_per_distance
			legs += 1
	var attacker: Vector3 = fleet.unit_for(0).position
	var mothership: Vector3 = fleet.unit_for(2).position
	return Vector3(travel / legs, attacker.distance_to(fleet.home) / fleet.tuning.enemy_speed,
		mothership.distance_to(fleet.home) / fleet.tuning.mothership_speed)

func color_checks() -> void:
	var counts := {"yellow": 0, "orange": 0, "blue": 0, "red": 0, "unusual": 0}
	var expected := {"yellow": 0.45, "orange": 0.30, "blue": 0.12, "red": 0.08, "unusual": 0.05}
	for seed_value in range(1000):
		var star := Visual.weighted_star(Visual.random_for(seed_value, 1, "star"))
		counts[star.family] += 1
	for family in expected:
		check(absf(counts[family] / 1000.0 - expected[family]) < 0.045, "Weighted " + family + " star distribution")

func overflow_orbit_checks() -> void:
	var destinations: Array = []
	for index in range(12):
		destinations.append({"index": index, "model_kind": "gas_giant"})
	for seed_value in [17, 44, 215]:
		var data := Visual.generate(seed_value, 1, destinations, Settings, "industrial", 1.2)
		var rings: Array = data.planets.map(func(p): return p.distance)
		for entry in destinations:
			if data.assignments.has(entry.index): continue
			var radius: float = data.poi_orbits[entry.index].distance
			check(radius > 0.0 and rings.all(func(other): return absf(other - radius) > 0.65),
				"Overflow destinations receive additional distinct rings")
			rings.append(radius)
		check(data.anchors.size() == destinations.size(), "Overflow leaves every planetary destination selectable")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var filename := "%s/%s-%s.png" % [CAPTURES, label, RenderingServer.get_current_rendering_method()]
	check(root.get_texture().get_image().save_png(filename) == OK, "Captured " + label)

func mount(state: Resource) -> Node:
	var host := preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state": state, "battle": {}}
	root.add_child(host)
	for frame in range(5): await process_frame
	return host

func presentation_checks() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(CAPTURES)
	var scales := []
	for factor in [0.0, 1.2]:
		var label := "before" if factor == 0.0 else "expanded"
		var state := fresh("defense", 1042, factor)
		var host := await mount(state)
		var map = host.star_map
		var influence: MeshInstance3D = map.visual_root.get_node("SolarInterference/InfluenceBoundary")
		if factor == 0.0: influence.material_override.set_shader_parameter("fill_strength", 0.0)
		check(is_equal_approx(influence.mesh.size.x / 2.08, state.environmental_instances[1].region.radius),
			"Solar ring and fill use the authoritative radius")
		scales.append([map.ship.scale, map.objects[0].scale, map.objects[-100].scale, map.planet_nodes[0].scale])
		check(map.objects[-100].material_override.get_shader_parameter("sun_color") == map.visual_data.star_color,
			"Selected color reaches the star material")
		await capture(label + "-normal")
		map.fit_overview()
		await capture(label + "-overview")
		map.camera.frame(Vector3(0.0, 28.0, 27.0), Vector3.ZERO, 0.0, &"solar_capture")
		await capture(label + "-solar")
		map.fit_overview()
		state.salvage = 40
		var site: String = "home" if state.defense.construction_sites.has("home") else state.defense.construction_sites.keys()[0]
		check(state.deploy_turret(site), "Turret deploys normally in both layouts")
		var player: Vector3 = state.defense.start
		for span in range(3):
			state._advance_strategy(2.0, player, player, true)
			await process_frame
		host._refresh_defense_hud()
		await capture(label + "-approach")
		host.free()
		await process_frame
	check(scales[0] == scales[1], "Expansion preserves planet, ship, enemy and stellar render scales")

	if DisplayServer.get_name() == "headless": return
	var seen := {}
	for seed_value in range(1, 90):
		var state := fresh("exploration", seed_value)
		var data := visual(state)
		if data.star_family not in ["yellow", "orange", "unusual"] or seen.has(data.star_family): continue
		var host := await mount(state)
		await capture("star-" + data.star_family)
		host.free()
		await process_frame
		seen[data.star_family] = true
		if seen.size() == 3: break
	check(seen.size() == 3, "Captured yellow, orange and unusual stars")

func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer is active")
	generation_checks()
	check(expanded_pacing.x > pacing.x and is_equal_approx(expanded_pacing.y, pacing.y * 1.2)
		and is_equal_approx(expanded_pacing.z, pacing.z * 1.2), "Measured strategic travel takes longer")
	print("Mean strategic seconds (PoI leg, attacker approach, advancing mothership): ", pacing / 6.0, " → ", expanded_pacing / 6.0)
	var mid_flight := fresh("defense", 1042)
	var planets: Array = visual(mid_flight).planets
	var at: Vector3 = mid_flight.defense.start
	mid_flight._advance_strategy(6.0, at, at, true)
	check(planets == visual(mid_flight).planets, "Fleet movement leaves expanded scenery in place")
	verify_save(mid_flight)
	color_checks()
	overflow_orbit_checks()
	await presentation_checks()
	root.get_node("Music").play_track("")
	await create_timer(0.15).timeout
	print("Star system expansion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
