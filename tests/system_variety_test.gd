extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Variation = preload("res://scripts/expedition/system_variation.gd")
const Layout = State.SystemLayout
var checks := 0
var failures := 0
var persisted_storm_types: Dictionary = {}
var stats := {
	"archetypes": {},
	"counts": {},
	"formations": {},
	"intensities": {},
	"binary": 0,
	"quasar": 0,
	"systems": 0,
	"dominant_storms": 0,
	"large_solar": 0
}


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func fresh(seed_value: int, enabled: bool = true, mode: String = "defense") -> Resource:
	var rules: Resource = Rules.duplicate(true)
	rules.system_variety = Rules.system_variety.duplicate(true)
	rules.system_variety.enabled = enabled
	# Continue checking the historical profile across later stages. The geometry
	# regression independently verifies the new profile and both modes' RNG parity.
	rules.system_variety.progressive_geometry = false
	rules.log_rolls = false
	rules.game_mode = mode
	rules.warzone_campaign_enabled = false
	var state := State.new()
	state.start(0, rules, seed_value)
	return state


func bump(state: Resource) -> void:
	state.defense.complete = true
	check(state.generate_system(), "Next system generation succeeds")


func increment(bucket: Dictionary, key: Variant) -> void:
	bucket[str(key)] = bucket.get(str(key), 0) + 1


func verify(state: Resource, baseline: Resource) -> void:
	var id := "seed %d/system %d" % [state.seed_used, state.system_number]
	var profile: Dictionary = state.system_variation
	check(Variation.valid(profile), "Valid profile " + id)
	check(state.faction_id == baseline.faction_id, "Faction stream preserved " + id)
	check(
		Save.encode(state).rng == Save.encode(baseline).rng,
		"All gameplay RNG states unchanged " + id
	)
	var ships: Array = state.encounters.filter(func(e): return e.kind == "battle")
	var old_ships: Array = baseline.encounters.filter(func(e): return e.kind == "battle")
	check(ships.size() == old_ships.size(), "Fleet and reserve counts unchanged " + id)
	for i in ships.size():
		check(
			(
				ships[i].enemy_data == old_ships[i].enemy_data
				and ships[i].modifier == old_ships[i].modifier
			),
			"Same ships/scaling/modifier " + id
		)
	var pois: Array = state.encounters.filter(func(e): return e.kind == "poi")
	check(pois.size() == profile.poi_count, "Declared PoI count " + id)
	var fleet: RefCounted = state.defense
	var sizes := Layout.planetary_radii(state.encounters)
	var points: Array = []
	for index in fleet.anchors:
		var at: Vector3 = fleet.anchors[index]
		check(
			Layout.bounds(state.layout_expansion).has_point(Vector2(at.x, at.z)),
			"PoI in navigable bounds " + id
		)
		check(
			at.length() >= 4.15 and at.distance_to(fleet.home) >= 3.0, "PoI clears sun/home " + id
		)
		for other in points:
			check(at.distance_to(other) >= 3.0, "Selectable PoIs separated " + id)
		points.append(at)
	for unit in fleet.units:
		if unit.status == "reserve":
			continue
		check(
			unit.position.distance_to(fleet.start) > fleet.tuning.interception_radius,
			"No player spawn collision " + id
		)
		check(
			(
				(
					Geometry3D
					. get_closest_point_to_segment(Vector3.ZERO, unit.position, fleet.home)
					. length()
				)
				> 2.52
			),
			"No stellar-crossing route " + id
		)
		if not unit.mothership:
			var eta: float = (
				unit.position.distance_to(fleet.home)
				/ (fleet.tuning.enemy_speed * fleet.speed_multiplier(unit))
			)
			check(eta >= profile.minimum_arrival - 0.001, "Actual-speed arrival fairness " + id)
	for a in sizes:
		for b in sizes:
			if a >= b:
				continue
			check(
				(
					absf(fleet.anchors[a].length() - fleet.anchors[b].length())
					>= sizes[a] + sizes[b] + state.orbit_clearance - 0.001
				),
				"Full orbital clearance " + id
			)
	var clearance := preload("res://scripts/expedition/environment_clearance.gd")
	var storm_count := 0
	for item in state.environmental_instances:
		check(
			not clearance.intersects_sphere(
				item, fleet.home, clearance.home_radius(fleet.tuning.environment_visual_margin)
			),
			"Homeworld remains outside physical hazards " + id
		)
		if item.type != "SPACE_STORM":
			continue
		storm_count += 1
		var axes := Vector3(item.region.axes[0], item.region.axes[1], item.region.axes[2])
		var angle: float = item.region.get("angle", 0.0)
		var extents := Vector2(
			absf(cos(angle)) * axes.x + absf(sin(angle)) * axes.z,
			absf(sin(angle)) * axes.x + absf(cos(angle)) * axes.z
		)
		var limit := Layout.bounds(state.layout_expansion).end.x
		check(
			(
				absf(item.position[0]) + extents.x <= limit + 0.001
				and absf(item.position[2]) + extents.y <= limit + 0.001
			),
			"Rotated storm fits map bounds " + id
		)
		var center := Vector3(item.position[0], item.position[1], item.position[2])
		var inside := center + Vector3(axes.x * 0.99, 0, 0).rotated(Vector3.UP, angle)
		var outside := center + Vector3(axes.x * 1.01, 0, 0).rotated(Vector3.UP, angle)
		check(
			(
				State.EnvironmentData.Storms.contains(item, State.Defense.wire(inside))
				and not State.EnvironmentData.Storms.contains(item, State.Defense.wire(outside))
			),
			"Rotated visual and containment geometry agree " + id
		)
	check(storm_count <= 2, "Conservative storm rendering budget " + id)
	var encoded := Save.encode(state)
	check(
		State.EnvironmentData.valid_instances(state.environmental_instances),
		"Valid physical regions " + id
	)
	var restored: Resource = Save.new().decode(
		JSON.parse_string(JSON.stringify(encoded)), state.rules
	)
	check(restored != null, "Save accepted " + id)
	if restored != null:
		check(
			JSON.stringify(Save.encode(restored)) == JSON.stringify(encoded),
			"Exact save/layout/environment/background restore " + id
		)
	for unit in fleet.units:
		if unit.mothership or unit.status == "reserve":
			continue
		var navigation_copy: Resource = Save.new().decode(encoded, state.rules)
		if navigation_copy != null:
			check(
				preload("res://tests/fixtures/expedition_contact.gd").reach(
					navigation_copy, unit.encounter
				),
				"Real movement reaches each selected initial attacker " + id
			)
			var persistence := preload("res://scripts/expedition/expedition_persistence.gd").new()
			persistence.enabled = false
			var checkpoint: Dictionary = persistence.checkpoint_battle(
				navigation_copy, unit.encounter, 998877
			)
			check(
				checkpoint.saved,
				"Every reached encounter accepts its battle environment checkpoint " + id
			)
			if checkpoint.saved:
				var environment: Dictionary = checkpoint.environment
				check(
					Save._valid_environment_marker(
						persistence.battle_marker, persistence.battle_checkpoint
					),
					"Battle marker validates after physical entry " + id
				)
				check(
					State.EnvironmentData.valid_snapshot(
						State.EnvironmentData.snapshot(
							JSON.parse_string(JSON.stringify(environment))
						)
					),
					"Frozen environment remains valid after JSON restore " + id
				)
				if (
					environment.type == "SPACE_STORM"
					and environment.configuration.get("extended", false)
				):
					var subtype: String = environment.configuration.subtype
					if not persisted_storm_types.has(subtype):
						var store := Save.new()
						store.path = "user://variety_extended_storm_checkpoint.json"
						check(
							store.save_data(
								persistence.battle_checkpoint, persistence.battle_marker
							),
							"Extended storm checkpoint writes to disk: " + subtype
						)
						check(
							(
								store.load_run().get("battle", {}).get("environment", {})
								== environment
							),
							"Extended storm checkpoint restores exactly: " + subtype
						)
						store.clear_run()
						persisted_storm_types[subtype] = true
						check_extended_snapshot_contract(environment)
					navigation_copy.environmental_instances.clear()
					var retry: Dictionary = persistence.checkpoint_battle(
						navigation_copy, unit.encounter, 998877, environment
					)
					check(
						retry.saved and retry.environment == environment,
						"Retry preserves frozen extended storm after world changes " + id
					)
	stats.systems += 1
	increment(stats.archetypes, profile.archetype)
	increment(stats.counts, pois.size())
	increment(stats.formations, profile.formation)
	increment(stats.intensities, profile.intensity)
	if not profile.companion.is_empty():
		stats.binary += 1
	if profile.background.any(func(layer): return layer.kind == 4):
		stats.quasar += 1
	for region in state.environmental_instances:
		if region.type == "SPACE_STORM" and maxf(region.region.axes[0], region.region.axes[2]) > 11:
			stats.dominant_storms += 1
		if region.type == "SOLAR_INTERFERENCE" and region.region.radius > 12:
			stats.large_solar += 1


func run() -> void:
	for seed_value in range(1, 101):
		var state := fresh(seed_value)
		var baseline := fresh(seed_value, false)
		for number in range(1, 7):
			verify(state, baseline)
			check(
				(
					state.system_variation
					== Variation.generate(seed_value, number, state.rules.system_variety)
				),
				"Profile is exactly reproducible"
			)
			if number < 6:
				bump(state)
				bump(baseline)
	check(persisted_storm_types.size() == 3, "All extended storm subtypes pass disk checkpoints")
	check(
		stats.archetypes.size() == 7 and stats.formations.size() == 6,
		"All archetypes and formations reached"
	)
	check(stats.counts.size() == 10, "All PoI counts from three to twelve reached")
	check(
		stats.binary > 40 and stats.binary < 110 and stats.quasar > 10,
		"Binary/quasar frequencies reasonable"
	)
	check(stats.dominant_storms > 10 and stats.large_solar > 2, "Dominant physical regions occur")
	var system_one := {}
	for seed_value in range(1, 101):
		system_one[Variation.generate(seed_value, 1, Rules.system_variety).archetype] = true
	check(system_one.size() == 7, "Every layout, including chaotic, occurs from system one")
	var old := fresh(1042, false)
	var old_data := Save.encode(old)
	check(not old_data.has("system_variation"), "Legacy saves omit profile")
	var old_restored: Resource = Save.new().decode(old_data, old.rules)
	check(
		old_restored != null and old_restored.system_variation.is_empty(),
		"Historical layout has no retroactive variation"
	)
	var exploration := fresh(1042, true, "exploration")
	check(
		Save.encode(exploration) == Save.encode(fresh(1042, false, "exploration")),
		"Exploration state/RNG/layout unchanged"
	)
	var invalid := Save.encode(fresh(1))
	invalid.system_variation.poi_count = 100
	check(Save.new().decode(invalid) == null, "Invalid profile rejected")
	print("VARIETY_STATISTICS " + JSON.stringify(stats))
	print("System variety: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check_extended_snapshot_contract(environment: Dictionary) -> void:
	var missing: Dictionary = environment.duplicate(true)
	missing.configuration.erase("extended")
	missing.configuration.region.axes = [17.0, 3.0, 12.0]
	check(
		not State.EnvironmentData.valid_snapshot(missing),
		"Large snapshots still require explicit extended-size permission"
	)
	var oversized: Dictionary = environment.duplicate(true)
	oversized.configuration.region.axes = [18.1, 3.0, 12.0]
	check(
		not State.EnvironmentData.valid_snapshot(oversized),
		"Extended snapshots still reject axes above eighteen"
	)
	var invalid_flag: Dictionary = environment.duplicate(true)
	invalid_flag.configuration.extended = "true"
	check(
		not State.EnvironmentData.valid_snapshot(invalid_flag),
		"Extended snapshot permission must be a boolean"
	)
	missing.configuration.region.axes = [8.0, 3.0, 6.0]
	check(
		State.EnvironmentData.valid_snapshot(missing),
		"Legacy bounded snapshots remain valid without a new flag"
	)
