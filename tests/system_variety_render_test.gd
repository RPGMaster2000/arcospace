extends SceneTree
## Production expedition scene, real pointer/touch markers and renderer captures.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func settle() -> void:
	for frame in 8:
		await process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/system-variety")
	root.get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/system-variety/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), label]
		)
	)


func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(
			RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0],
			"Requested renderer active"
		)
	var examples := {}
	for seed_value in range(1, 201):
		var state := State.new()
		var rules: Resource = Rules.duplicate(true)
		rules.log_rolls = false
		state.start(0, rules, seed_value)
		var profile: Dictionary = state.system_variation
		if not examples.has(profile.archetype):
			examples[profile.archetype] = seed_value
		if not profile.companion.is_empty() and not examples.has("binary"):
			examples.binary = seed_value
		if (
			profile.background.any(func(layer): return layer.kind == 4)
			and not examples.has("quasar")
		):
			examples.quasar = seed_value
		if (
			state.environmental_instances.any(
				func(item): return item.type == "SOLAR_INTERFERENCE" and item.region.radius > 12
			)
			and not examples.has("large_solar")
		):
			examples.large_solar = seed_value
		if (
			profile.background.any(func(layer): return layer.kind == 0)
			and not examples.has("nebula")
		):
			examples.nebula = seed_value
		if examples.size() == 11:
			break
	check(
		examples.size() == 11,
		"All layouts, binary, quasar, nebula and large solar occur in system one"
	)
	for label in examples:
		root.size = Vector2i(1280, 720)
		root.content_scale_size = Vector2i(960, 540)
		var host = load("res://scenes/expedition.tscn").instantiate()
		host.persistence_enabled = false
		host.play_system_intro = false
		host.rules = Rules.duplicate(true)
		host.rules.debug_seed = examples[label]
		host.rules.log_rolls = false
		root.add_child(host)
		await settle()
		var map = host.star_map
		check(
			map.system_variation == host.state.system_variation,
			"Renderer receives saved profile " + label
		)
		var before := Save.encode(host.state)
		for index in host.state.defense.anchors:
			check(
				(
					map.visual_data.anchors[index].distance_to(host.state.defense.anchors[index])
					< 0.001
				),
				"Visible and authoritative anchors match " + label
			)
		var companion: Node = map.visual_root.get_node_or_null("VisualCompanionStar")
		check(
			(companion != null) == (not host.state.system_variation.companion.is_empty()),
			"Companion matches saved configuration"
		)
		# Godot may assign a numeric suffix when multiple storm roots share a name.
		var storm_count := 0
		for node in map.visual_root.get_children():
			if node.name.begins_with("PhysicalSpaceStorm") or node.has_node("EngagementBoundary"):
				storm_count += 1
		check(
			(
				storm_count
				== (
					host
					. state
					. environmental_instances
					. filter(func(item): return item.type == "SPACE_STORM")
					. size()
				)
			),
			"Every physical storm renders"
		)
		await capture("%s-seed-%d" % [label, examples[label]])
		if label == "binary":
			for dimensions in [Vector2i(1920, 1080), Vector2i(960, 540), Vector2i(1280, 573)]:
				root.size = dimensions
				await settle()
				await capture("binary-%dx%d" % [dimensions.x, dimensions.y])
			check(
				Save.encode(host.state) == before, "Rendering and resizing consume no state or RNG"
			)
			# Real input selects an independently placed PoI without advancing time.
			for touch in [true, false]:
				var index: int = host.state.defense.anchors.keys()[0]
				var visible_indices: Array = host.state.defense.anchors.keys().filter(
					func(key):
						return (
							map.markers[key].visible
							and not map.point_is_reserved(
								map.markers[key].get_global_rect().get_center()
							)
						)
				)
				check(not visible_indices.is_empty(), "An independent destination is selectable")
				if visible_indices.is_empty():
					continue
				index = visible_indices[0]
				var marker: Control = map.markers[index]
				if marker.visible:
					for pressed in [true, false]:
						var event: InputEvent = (
							InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
						)
						if event is InputEventMouseButton:
							event.button_index = MOUSE_BUTTON_LEFT
						else:
							event.index = 0
						event.position = marker.get_global_rect().get_center()
						event.pressed = pressed
						root.push_input(event, true)
						await process_frame
					await settle()
					check(
						(
							map.selected_index == index
							if touch
							else host.state.travel_destination == index
						),
						"Real touch selects / mouse travels to generated destination"
					)
					map.overview()
					await settle()
		if label != "binary":
			check(Save.encode(host.state) == before, "Rendering consumes no state or RNG")
		check(Save.encode(host.state).rng == before.rng, "Pointer input consumes no unrelated RNG")
		if label == "storm_dominated":
			var target_index := -1
			for unit in host.state.defense.units:
				if unit.mothership or unit.status == "reserve":
					continue
				var copy: Resource = Save.new().decode(before, host.state.rules)
				if not preload("res://tests/fixtures/expedition_contact.gd").reach(
					copy, unit.encounter
				):
					continue
				var environment: Dictionary = copy.battle_environment(unit.encounter)
				if (
					environment.type == "SPACE_STORM"
					and (
						maxf(
							environment.configuration.region.axes[0],
							environment.configuration.region.axes[2]
						)
						> 9.0
					)
				):
					target_index = unit.encounter
					break
			check(target_index >= 0, "Production example reaches an extended-size storm battle")
			if target_index >= 0:
				check(
					preload("res://tests/fixtures/expedition_contact.gd").reach(
						host.state, target_index
					),
					"Real movement establishes dominant-storm combat contact"
				)
				var expected: Dictionary = host.state.battle_environment(target_index)
				host.start_battle(target_index, 998877)
				check(
					is_instance_valid(host.battle),
					"Actual battle instantiates after the extended storm checkpoint"
				)
				if is_instance_valid(host.battle):
					host.battle.enemy_timer.stop()
					check(
						host.battle.modifier.kind == State.EnvironmentData.modifier_id(expected),
						"Dominant storm uses its existing combat modifier"
					)
		host.queue_free()
		await settle()
	print("System variety render: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
