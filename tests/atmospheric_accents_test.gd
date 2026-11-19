extends SceneTree
## Cosmetic isolation, exact pre-change save signatures and compact reconstruction.
const Accents = preload("res://scripts/presentation/star_system/atmospheric_accents.gd")
const Settings = preload("res://scripts/presentation/star_system/atmospheric_settings.gd")
const MapSettings = preload("res://scripts/presentation/star_system/map_settings.gd")
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func run() -> void:
	var settings := Settings.new()
	var calibration := MapSettings.new()
	var data := Accents.Visual.generate(412, 1, [], calibration)
	var original := var_to_str(data)
	var counts := {}
	var busy_counts := {}
	var samples := {}
	seed(98423)
	var expected := randi()
	seed(98423)
	for index in 4000:
		var plan := Accents.recipe(index, 1, data, {}, settings, 0.0)
		check(
			plan == Accents.recipe(index, 1, data, {}, settings, 0.0),
			"Deterministic recipe %d" % index
		)
		counts[plan.kind] = counts.get(plan.kind, 0) + 1
		var busy := Accents.recipe(
			index, 1, data, {"intensity": 2, "companion": {"present": true}}, settings, 0.0
		)
		busy_counts[busy.kind] = busy_counts.get(busy.kind, 0) + 1
		check(
			(
				(
					int(not plan.sky.is_empty())
					+ int(not plan.rocks.is_empty())
					+ int(not plan.moon.is_empty())
				)
				<= 1
			),
			"At most one accent, never crowded combinations"
		)
		var crowded := Accents.recipe(
			index, 1, data, {"background": [{"kind": 0}, {"kind": 1}]}, settings, 0.0
		)
		check(crowded.sky.is_empty(), "Multiple existing sky features suppress new sky accents")
		var quasar := Accents.recipe(index, 1, data, {"background": [{"kind": 4}]}, settings, 0.0)
		check(quasar.sky.is_empty(), "Existing quasar never competes with another sky accent")
		samples[plan.kind] = plan
	check(randi() == expected, "Cosmetic generation never consumes global RNG")
	check(var_to_str(data) == original, "Authoritative layout data is never changed")
	check(counts.size() == 5, "Every accent and quiet systems are reachable from system one")
	check(
		counts.get("quiet", 0) > 900 and counts.get("quiet", 0) < 1600,
		"Quiet systems remain common"
	)
	check(
		counts.get("panorama", 0) > 1000 and counts.get("panorama", 0) < 1400,
		"Subtle panorama frequency 25–35 percent"
	)
	check(
		counts.get("rocks", 0) > 600 and counts.get("rocks", 0) < 1000,
		"Rock frequency 15–25 percent"
	)
	check(
		counts.get("moon", 0) > 400 and counts.get("moon", 0) < 800, "Moon frequency 10–20 percent"
	)
	check(
		counts.get("anomaly", 0) > 120 and counts.get("anomaly", 0) < 280,
		"Rare anomaly frequency 3–7 percent"
	)
	check(
		busy_counts.get("quiet", 0) > counts.get("quiet", 0) * 2,
		"Busy systems keep substantially more negative space"
	)
	print(
		"Atmospheric distribution / 4000 quiet-context systems: ", counts, "; busy: ", busy_counts
	)
	for index in 100:
		var blocked := Accents.recipe(
			index,
			1,
			data,
			{},
			settings,
			0.0,
			[],
			[{"position": Vector3(1, 2, 3), "radius": 10000.0}]
		)
		check(
			blocked.rocks.is_empty() and blocked.moon.is_empty(),
			"World decorations reject obstructed candidates instead of moving gameplay objects"
		)
	settings.enabled = false
	check(
		Accents.recipe(1, 1, data, {}, settings, 0.0).kind == "quiet",
		"Inspector disable switch leaves the original presentation"
	)
	settings.enabled = true
	# Native mesh reuse, shared resources remain untouched, mobile keeps same transforms.
	var parent := Node3D.new()
	root.add_child(parent)
	var planets := {}
	for planet in data.planets:
		var body := Node3D.new()
		body.position = planet.position
		body.scale = Vector3.ONE * 1.5
		parent.add_child(body)
		planets[planet.index] = body
	var desktop := Accents.build_world(samples.rocks, parent, planets, settings, calibration, false)
	var mobile := Accents.build_world(samples.rocks, parent, planets, settings, calibration, true)
	check(
		desktop[0].multimesh.instance_count == settings.rock_count,
		"Single instanced low-poly rock draw"
	)
	check(
		mobile[0].multimesh.visible_instance_count < desktop[0].multimesh.visible_instance_count,
		"Android reduces visible instances"
	)
	check(
		desktop[0].get_meta("scenery_transforms") == mobile[0].get_meta("scenery_transforms"),
		"Android changes count, never placement"
	)
	for transform in samples.rocks.rocks:
		check(
			not Accents.Layout.bounds(0.0).has_point(
				Vector2(transform.origin.x, transform.origin.z)
			),
			"Decorative rocks lie beyond navigable bounds"
		)
	var moon := Accents.build_world(samples.moon, parent, planets, settings, calibration, false)[0]
	check(
		moon.get_parent() == planets[samples.moon.moon.planet],
		"Moon follows an unassigned planet automatically"
	)
	check(
		moon.mesh.radial_segments == 16 and moon.get_node_or_null("CollisionShape3D") == null,
		"Moon is lightweight noninteractive geometry"
	)
	check(
		(
			parent.find_children("*", "CollisionObject3D", true, false).is_empty()
			and parent.find_children("*", "Light3D", true, false).is_empty()
		),
		"No decorative colliders or lights"
	)
	parent.free()
	var baseline_path := OS.get_environment("ARCOSPACE_ATMOSPHERE_BASELINE")
	var baseline := {}
	if not baseline_path.is_empty():
		baseline = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		check(
			baseline.size() == 600,
			"Unmodified-main reference contains 600 complete save signatures"
		)
	var actual_counts := {}
	for seed_value in range(1, 101):
		var rules: Resource = Rules.duplicate(true)
		rules.warzone_campaign_enabled = false
		rules.log_rolls = false
		var state := State.new()
		state.start(0, rules, seed_value)
		for number in range(1, 7):
			var encoded := Save.encode(state)
			var signature := JSON.stringify(encoded)
			if not baseline.is_empty():
				var historical := encoded.duplicate()
				historical.erase("warzone_campaign_enabled")
				historical.erase("homeworld_outcome")
				check(
					JSON.stringify(historical).sha256_text() == baseline["%d:%d" % [seed_value, number]],
					"Exact main gameplay/save signature seed %d system %d" % [seed_value, number]
				)
			var visual := Accents.Visual.generate(seed_value, number, [], calibration)
			var plan := Accents.recipe(
				seed_value,
				number,
				visual,
				state.system_variation,
				settings,
				state.layout_expansion,
				state.environmental_instances
			)
			actual_counts[plan.kind] = actual_counts.get(plan.kind, 0) + 1
			check(
				JSON.stringify(Save.encode(state)) == signature,
				"Cosmetic recipe preserves all state and gameplay RNG"
			)
			if seed_value <= 5:
				var restored: Resource = Save.new().decode(JSON.parse_string(signature), rules)
				check(restored != null, "Save restores with no new fields")
				if restored != null:
					check(
						(
							plan
							== Accents.recipe(
								restored.seed_used,
								restored.system_number,
								visual,
								restored.system_variation,
								settings,
								restored.layout_expansion,
								restored.environmental_instances
							)
						),
						"Save restores identical cosmetic recipe"
					)
			if number < 6:
				state.defense.complete = true
				check(state.generate_system(), "Next system remains playable")
	print("Atmospheric distribution / 600 actual Defense systems: ", actual_counts)
	# Legacy/exploration records have no dependency on new persistent fields.
	for mode in ["exploration", "defense"]:
		var rules: Resource = Rules.duplicate(true)
		rules.log_rolls = false
		rules.game_mode = mode
		rules.system_variety = rules.system_variety.duplicate(true)
		rules.system_variety.enabled = false
		var state := State.new()
		state.start(0, rules, 915)
		var record := Save.encode(state)
		var restored: Resource = Save.new().decode(record, rules)
		check(
			restored != null and restored.system_variation.is_empty(),
			"Historical %s schema remains accepted" % mode
		)
		check(
			(
				Accents.recipe(state.seed_used, 1, data, {}, settings, 0.0)
				== Accents.recipe(restored.seed_used, 1, data, {}, settings, 0.0)
			),
			"Historical %s cosmetics stable" % mode
		)
	print("Atmospheric accents: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
