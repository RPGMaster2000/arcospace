extends SceneTree
const Board = preload("res://scenes/board_3d.tscn")
const Settings = preload("res://scripts/presentation/battle_cinematic_settings.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const ARENAS = [
	preload("res://scenes/battlefield_3d.tscn"),
	preload("res://scenes/battlefield_planetary_orbit.tscn")
]
const PROFILES = [
	preload("res://ships/enemy/scrap_skiff.tres"),
	preload("res://ships/enemy/siege_monitor.tres"),
	preload("res://ships/enemy/axiom_command_nexus.tres")
]
var failures := 0
var checks := 0
var previous_skip := false


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _initialize() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	previous_skip = Preferences.skip_cinematics()
	call_deferred("run")


func fresh(arena: PackedScene, profile: Resource) -> Node:
	Preferences.set_skip_cinematics(true)
	var board = Board.instantiate()
	board.normal_battlefield = arena
	board.cinematic_settings = board.cinematic_settings.duplicate(true)
	board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate(true)
	board.get_node("CardMotion").settings.enabled = false
	board.setup_settings = {"player_ship": 0, "enemy_data": profile, "modifier": 0}
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	return board


func capture(board: Node, name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/battlefield-depth")
	root.get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/battlefield-depth/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), name]
		)
	)


func sky_image(board: Node) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return board.get_node("BattleView/Viewport").get_texture().get_image()


func difference(a: Image, b: Image) -> float:
	var total := 0.0
	var samples := 0
	for y in range(3, a.get_height() - 3, 11):
		for x in range(3, a.get_width() - 3, 11):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			samples += 3
	return total / maxi(1, samples)


func visibility_checks(board: Node, label: String) -> void:
	var director = board.cinematic_director
	for ship in [director.player, director.enemy]:
		var light: OmniLight3D = ship.get_node("Body/HullVisibilityLight")
		check(light.visible and not light.shadow_enabled and light.omni_range <= 5.5,
			"Each standard ship has a bounded shadowless fill")
		var other: Node3D = director.enemy if ship == director.player else director.player
		check(light.light_cull_mask & other.get_node("Body/Hull").layers == 0
			and light.light_cull_mask & ship.get_node("Body/Hull").layers != 0,
			"The fill reaches only its own hull layer")
	if DisplayServer.get_name() == "headless":
		return
	var player: Node3D = director.player
	var enemy: Node3D = director.enemy
	player.set_process(false)
	enemy.set_process(false)
	player.get_node("Shield").hide()
	enemy.get_node("Shield").hide()
	var light: OmniLight3D = player.get_node("Body/HullVisibilityLight")
	var other_light: OmniLight3D = enemy.get_node("Body/HullVisibilityLight")
	light.hide()
	other_light.hide()
	var unlit := await sky_image(board)
	light.show()
	other_light.show()
	var lit := await sky_image(board)
	var center: Vector2i = Vector2i(board.battle_camera.unproject_position(player.get_node("Body/Hull").global_position))
	var crop := Rect2i(center - Vector2i(65, 40), Vector2i(130, 80))
	check(difference(unlit.get_region(crop), lit.get_region(crop)) > .005,
		"Ship fill adds measurable shaping to the rendered hull")
	await capture(board, label + "-visibility-light")
	player.get_node("Shield").show()
	enemy.get_node("Shield").show()
	player.set_process(true)
	enemy.set_process(true)


func sky_checks(board: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var field: Node3D = board.get_node("BattleView/Viewport/Battlefield")
	var camera: Camera3D = board.battle_camera
	var hidden: Array = []
	for node in field.get_children():
		if node is Node3D and node != camera and node != board.backdrop and node.visible:
			node.hide()
			hidden.append(node)
	var original := camera.global_transform
	var first := await sky_image(board)
	camera.global_position += Vector3(7, 2, 3)
	var translated := await sky_image(board)
	check(
		difference(first, translated) < .001,
		"Infinite sky has no translation-following texture drift"
	)
	camera.global_transform = original
	camera.global_basis = original.basis.rotated(Vector3.UP, .5)
	var rotated := await sky_image(board)
	check(difference(first, rotated) > .005, "Actual sky pixels respond to world camera rotation")
	camera.global_basis = original.basis.rotated(Vector3.UP, TAU)
	var wrapped := await sky_image(board)
	check(difference(first, wrapped) < .001, "Full rotation returns identical panorama orientation")
	camera.global_basis = original.basis.rotated(Vector3.UP, PI - .001)
	var left := await sky_image(board)
	camera.global_basis = original.basis.rotated(Vector3.UP, PI + .001)
	var right := await sky_image(board)
	check(difference(left, right) < .01, "Longitude wrap has no abrupt panorama transition")
	camera.global_transform = original
	for node in hidden:
		node.show()


func timing_checks(board: Node) -> void:
	Preferences.set_skip_cinematics(false)
	var director = board.cinematic_director
	var original: Transform3D = director.camera.global_transform
	var sky_rest: Transform3D = board.backdrop.transform
	var resources: Dictionary = board._both_states()
	var draw_rng: int = board.hand.rng.state
	var seen: Array = []
	director.stage_changed.connect(func(label): seen.append(label))
	director.introduction()
	for pair in [["establishing", 1.15 / .75], ["flyby", 1.05 / .75], ["confrontation", 1.25 / .75]]:
		check(director.stage == pair[0], "Introduction shot order remains unchanged")
		var tween: Tween = director.motion
		tween.pause()
		tween.custom_step(pair[1] * .5)
		check(
			director.active and director.stage == pair[0],
			"Half the new duration cannot finish the shot"
		)
		tween.custom_step(pair[1] * .5 + .001)
	check(
		not director.active and director.camera.global_transform == original,
		"Faster introduction restores the original camera"
	)
	check(
		board.backdrop.transform == sky_rest,
		"World-direction sky never follows the cinematic camera"
	)
	check(
		board._both_states() == resources and board.hand.rng.state == draw_rng,
		"Camera pacing changes neither combat values nor draw RNG"
	)


func ready_for_action(board: Node) -> bool:
	return (
		not board.resolving_card
		and not board.battle_effects.busy
		and not board._presentation_locked()
		and not board.destruction_pending
	)


func wait_ready(board: Node) -> void:
	var deadline := Time.get_ticks_msec() + 40000
	while not ready_for_action(board) and Time.get_ticks_msec() < deadline:
		await process_frame
	check(ready_for_action(board), "Combat VFX and cinematic camera release their busy states")


func stage_capture(board: Node, label: String) -> void:
	await process_frame
	if is_instance_valid(board) and board.cinematic_director.active:
		await capture(board, label)


func combat_depth_checks(board: Node, label: String) -> void:
	await wait_ready(board)
	board.battle_effects.enabled = true
	board.cinematic_settings.attack_seconds = .1
	board.cinematic_settings.orbit_seconds = .4
	board.cinematic_settings.boost_seconds = .4
	board.cinematic_settings.fade_seconds = .04
	var director = board.cinematic_director
	var stages: Array = []
	var departure_state: Array = [{}, 0]
	director.stage_changed.connect(
		func(stage):
			stages.append(stage)
			if stage == "victory_orbit":
				departure_state[0] = board._both_states()
				departure_state[1] = board.turn_number
			stage_capture(board, label + "-" + stage)
	)
	for side in ["player", "enemy"]:
		var target := "enemy" if side == "player" else "player"
		var card = load("res://cards/27_missile_barrage.tres")
		var hand = board.hand if side == "player" else board.enemy_hand
		hand.cards[0] = card
		board.set(side + "_crew", 99)
		board.set(target + "_hull", 100)
		board.set(target + "_shields", 0)
		await board._resolve_after_activation(side, 0, false, card)
		check(
			board.get(target + "_hull") == 84 and director.kind == "heavy_beam",
			"Both attacker directions retain actual beam damage and camera selection"
		)
		await board._wait_action_presentation()
		await wait_ready(board)
	board.hand.cards[0] = load("res://cards/27_missile_barrage.tres")
	board.player_crew = 99
	board.enemy_shields = 0
	board.enemy_hull = 3
	var victim_light: OmniLight3D = director.enemy.get_node("Body/HullVisibilityLight")
	var body: Node3D = director.enemy.get_node("Body")
	var shed_light := [false]
	body.visibility_changed.connect(func():
		if not body.visible:
			shed_light[0] = not victim_light.visible and director.player.get_node("Body/HullVisibilityLight").visible
			stage_capture(board, label + "-fragments-unlit"))
	board._act("player", 0, false)
	await process_frame
	await wait_ready(board)
	check(
		(
			board.result_recorded
			and board.winner == "player"
			and "impact_hold" in stages
			and "victory_orbit" in stages
		),
		"Real lethal resolution finishes destruction before automatic victory departure"
	)
	check(
		board.victory_ready and board.get_node("MatchResult").visible,
		"Victory result follows departure in each standard arena"
	)
	check(shed_light[0], "The destroyed hull switches off its fill at fragmentation")
	check(
		board._both_states() == departure_state[0] and board.turn_number == departure_state[1],
		"Orbit/boost/fade cannot advance combat state or turns"
	)
	check(
		not director.active and board.backdrop.position == Vector3.ZERO,
		"Victory presentation restores camera ownership without moving the infinite sky"
	)


func run() -> void:
	var settings := Settings.new()
	check(settings.playback_speed == .75, "Default cinematic speed is 50 percent faster than the previous .5")
	check(
		settings.introduction_seconds == Vector3(1.15, 1.05, 1.25),
		"Authored shot durations remain independently editable"
	)
	check(
		is_equal_approx(
			settings.duration(
				(
					settings.introduction_seconds.x
					+ settings.introduction_seconds.y
					+ settings.introduction_seconds.z
				)
			),
			4.6
		),
		"Three-shot introduction now totals 4.6 seconds"
	)
	check(
		(
			is_equal_approx(settings.duration(settings.attack_seconds), 1.25 / .75)
			and settings.duration(settings.orbit_seconds) == 3.0
			and is_equal_approx(settings.duration(settings.boost_seconds), .38 / .75)
		),
		"Attack, orbit and faster boost retain the playback multiplier"
	)
	settings.playback_speed = 1
	check(
		settings.duration(1.25) == 1.25 and Engine.time_scale == 1,
		"Playback scale remains local to cinematics"
	)
	for arena in ARENAS:
		for profile in PROFILES:
			root.size = Vector2i(1280, 720)
			var board := fresh(arena, profile)
			await process_frame
			var field: Node3D = board.get_node("BattleView/Viewport/Battlefield")
			var scenery: Node3D = field.get_node("BackgroundObjects")
			var debris: MultiMeshInstance3D = scenery.get_node("Debris")
			check(
				(
					board.backdrop.get_meta("infinite_panorama", false)
					and board.backdrop.mesh is SphereMesh
				),
				"Only standard arenas use enclosing direction-sampled skies"
			)
			check(
				debris.multimesh.instance_count == (5 if arena == ARENAS[1] else 8),
				"Sparse scenery uses one instanced draw"
			)
			check(
				board.enemy_ship_data == profile,
				"Requested light/heavy/mothership profile is actually bound"
			)
			await visibility_checks(board, arena.resource_path.get_file().get_basename() + "-" + profile.resource_path.get_file().get_basename())
			var positions: Array = scenery.ORBIT_ROCKS if arena == ARENAS[1] else scenery.DEEP_ROCKS
			var visible_rocks := 0
			var low := INF
			var high := 0.0
			for i in debris.multimesh.instance_count:
				var point: Vector3 = positions[i]
				if DisplayServer.get_name() != "headless":
					check(
						debris.multimesh.get_instance_transform(i).origin.is_equal_approx(point),
						"Rendered instance matches its static authored transform"
					)
				var area := Rect2(Vector2.ZERO, Vector2(board.get_node("BattleView/Viewport").size))
				if (
					not board.battle_camera.is_position_behind(point)
					and area.has_point(board.battle_camera.unproject_position(point))
				):
					visible_rocks += 1
				low = minf(low, point.length())
				high = maxf(high, point.length())
			check(
				visible_rocks >= 2,
				"At least two depth objects are visible in normal gameplay framing"
			)
			check(
				low > 60 and high - low > 25,
				"Debris layers keep a clear central camera/ship envelope"
			)
			check(
				(
					not scenery.is_processing()
					and debris.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				),
				"Scenery is static with no shadow pass"
			)
			var point: Vector3 = positions[0]
			var before: Vector2 = board.battle_camera.unproject_position(point)
			board.battle_camera.position.x += 4
			check(
				board.battle_camera.unproject_position(point).distance_to(before) > 2,
				"Nearby scenery has real translational parallax"
			)
			board.battle_camera.position.x -= 4
			await sky_checks(board)
			timing_checks(board)
			var director = board.cinematic_director
			var token: int = director._begin("framing audit", true)
			for offset in [
				director.settings.establishing_from,
				director.settings.flyby_from,
				director.settings.flyby_to
			]:
				var pose: Transform3D = director._pose(director.enemy, offset)
				director._set_camera(pose, director.settings.cinematic_fov)
				for i in debris.multimesh.instance_count:
					check(
						pose.origin.distance_to(positions[i]) > 10,
						"Cinematic framing cannot clip nearby debris"
					)
				if arena == ARENAS[1]:
					check(
						pose.origin.distance_to(scenery.get_node("Planet").global_position) > 30,
						"Camera stays outside the real planet"
					)
			await capture(
				board,
				(
					arena.resource_path.get_file().get_basename()
					+ "-"
					+ profile.resource_path.get_file().get_basename()
					+ "-flyby"
				)
			)
			director.skip()
			for size in [Vector2i(960, 540), Vector2i(1280, 720), Vector2i(1280, 573)]:
				root.size = size
				await process_frame
				await capture(
					board,
					(
						arena.resource_path.get_file().get_basename()
						+ "-gameplay-"
						+ str(size.x)
						+ "x"
						+ str(size.y)
					)
				)
			if profile == PROFILES[2]:
				await combat_depth_checks(board, arena.resource_path.get_file().get_basename())
			board.free()
			await process_frame
	# Legacy modifier scenes retain their exact quad shader, material and camera-following behavior.
	for index in range(1, 8):
		var board = Board.instantiate()
		Preferences.set_skip_cinematics(true)
		board.setup_settings = {"modifier": index}
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		check(
			(
				not board.backdrop.get_meta("infinite_panorama", false)
				and (
					board.backdrop.material_override.shader.resource_path
					== (
						"res://shaders/space_background.gdshader"
						if index == 1
						else (
							"res://shaders/solar_background.gdshader"
							if index == 3
							else "res://shaders/battle_panorama.gdshader"
						)
					)
				)
			),
			"Modifier environment retains its existing UV shader"
		)
		var rest: Transform3D = board.backdrop.transform
		board.cinematic_director._set_camera(board.battle_camera.global_transform, 42)
		check(board.backdrop.transform != rest, "Legacy modifier quad projection remains supported")
		board.free()
		await process_frame
	Preferences.set_skip_cinematics(previous_skip)
	print("Battlefield depth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
