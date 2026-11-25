extends SceneTree
## Actual map scene and deterministic strategic time in each captured sector.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Host = preload("res://scenes/expedition.tscn")
const Rifts = State.TemporalRift
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if ok: return
	failures += 1
	push_error(message)


func run() -> void:
	var renderer := RenderingServer.get_current_rendering_method()
	var rendered := DisplayServer.get_name() != "headless"
	var args := OS.get_cmdline_user_args()
	if rendered and not args.is_empty(): check(renderer == args[0], "Requested renderer activated")
	var examples := ["conventional", "unstable", "storm_dominated", "chaotic"]
	if renderer == "mobile" and "--capture-all" not in args: examples = ["unstable", "storm_dominated"]
	for environment in examples:
		root.size = Vector2i(960, 540)
		var state := State.new()
		state.start(0, Rules, 214, {"mode":"defense", "stage":5, "rank":-1, "environment":environment,
			"formation":"pincer", "size_class":"Standard", "home_region":"Middle Orbit"})
		var at: Vector3 = state.defense.start
		state._advance_strategy(17.0, at, at, true, false)
		var host := Host.instantiate()
		host.resume_data = {"state":state, "battle":{}}
		host.persistence_enabled = false
		host.play_system_intro = false
		host.rules = Rules
		root.add_child(host)
		for i in 4: await process_frame
		var map = host.star_map
		map.fit_overview()
		check(state.system_variation.archetype == environment, "Forced example selected " + environment)
		var size := 0
		var fronts: Array = state.environmental_instances.filter(func(item): return item.type == State.EnvironmentData.SPACE_STORM)
		for node in map.visual_root.get_children():
			if not node.has_node("EngagementBoundary"): continue
			size += 1
			if not state.system_variation.has("weather"): continue
			check(node.get_child_count() == 2, "One cloud sheet and one exact boundary per front")
			check(node.get_child(0).material_override.get_shader_parameter("front_strength") == 1.0,
				"Front cloud and lightning shader active")
		check(size == fronts.size(), "Every authoritative front draws")
		var live := Rifts.active_all(state.environmental_instances)
		check(live.size() == map.rift_visuals.size(), "All live rifts render simultaneously")
		if environment in ["unstable", "chaotic"]: check(live.size() >= 2, "Opening screenshot shows simultaneous rifts")
		for visual in map.rift_visuals.values(): visual._process(1.0)
		for i in 2: await process_frame
		if rendered:
			await RenderingServer.frame_post_draw
			var directory := "res://.godot/testlogs/extreme-weather"
			DirAccess.make_dir_recursive_absolute(directory)
			var image := root.get_texture().get_image()
			image.save_webp("%s/%s-%s.webp" % [directory, renderer, environment], false, 0.72)
		if live.size() > 1:
			var expired: String = live.front().id
			var survivor: String = live.back().id
			var visual: Node3D = map.rift_visuals[survivor]
			var display: Dictionary = state.defense_map_view()
			display.temporal_rifts.pop_front()
			map.sync_defense(display)
			check(not map.rift_visuals.has(expired) and map.rift_visuals[survivor] == visual,
				"Removing one rift retains other visuals without recreation")
		host.free()
		await process_frame
	print("Extreme weather presentation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
