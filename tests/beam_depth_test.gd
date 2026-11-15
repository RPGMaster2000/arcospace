extends SceneTree
## Compare real transparent beam pixels against sky and an opaque foreground hull proxy.
const Board = preload("res://scenes/board_3d.tscn")
const VFX = preload("res://scripts/effects/imported_combat_vfx.gd")
const ARENAS = [
	preload("res://scenes/battlefield_3d.tscn"),
	preload("res://scenes/battlefield_planetary_orbit.tscn")
]
var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _initialize() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "0")
	call_deferred("run")


func frame(board: Node) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return board.get_node("BattleView/Viewport").get_texture().get_image()


func changed(a: Image, b: Image, center: Vector2) -> int:
	var count := 0
	var rect := Rect2i(Vector2i(center) - Vector2i(14, 14), Vector2i(28, 28)).intersection(
		Rect2i(Vector2i.ZERO, a.get_size())
	)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var d := a.get_pixel(x, y) - b.get_pixel(x, y)
			if absf(d.r) + absf(d.g) + absf(d.b) > .12:
				count += 1
	return count


func capture(board: Node, label: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/beam-depth")
	get_root().get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/beam-depth/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), label]
		)
	)


func run() -> void:
	var shader: String = FileAccess.get_file_as_string("res://shaders/battle_space_sky.gdshader")
	check(
		"depth_draw_opaque" in shader and not "depth_test_disabled" in shader,
		"Sky participates in normal opaque depth rather than bypassing foreground depth tests"
	)
	if DisplayServer.get_name() == "headless":
		print(
			(
				"Beam depth: %d checks, %d failures; pixel checks require a renderer"
				% [checks, failures]
			)
		)
		quit(1 if failures else 0)
		return
	root.size = Vector2i(960, 540)
	for arena in ARENAS:
		var board = Board.instantiate()
		board.setup_settings = {"player_ship": 0, "enemy_ship": 0, "modifier": 0}
		board.normal_battlefield = arena
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		await process_frame
		var field: Node3D = board.battle_camera.get_parent()
		var player: Node3D = field.get_node("PlayerShip")
		var enemy: Node3D = field.get_node("EnemyShip")
		for ship in [player, enemy]:
			ship.set_process(false)
			ship.get_node("Body").hide()
			ship.get_node("Shield").hide()
		field.get_node("BackgroundObjects").hide()
		var camera: Camera3D = board.battle_camera
		var rest := camera.global_transform
		var original_fov := camera.fov
		var director = board.cinematic_director
		director._bounds = {player: director._measure(player), enemy: director._measure(enemy)}
		for side in ["player", "enemy"]:
			var actor: Node3D = player if side == "player" else enemy
			var target: Node3D = enemy if side == "player" else player
			var midpoint: Vector3 = (
				(
					actor.get_node("Body/Hull").global_position
					+ target.get_node("Body/Hull").global_position
				)
				* .5
			)
			for angle in range(3):
				var pose: Transform3D = (
					rest
					if angle == 0
					else director._pose(
						actor if angle == 1 else target,
						(
							director.settings.attacker_offset
							if angle == 1
							else director.settings.victim_offset
						)
					)
				)
				if angle != 0:
					pose = pose.looking_at(midpoint, Vector3.UP)
				director._set_camera(
					pose, original_fov if angle == 0 else director.settings.cinematic_fov
				)
				var point := camera.unproject_position(midpoint)
				var baseline := await frame(board)
				var beam: Node3D = VFX.beam(actor, target)
				beam.set("pulse_strength", 0.0)
				beam.call("_set_shader_param", "speed_scale", 0.0)
				var image := await frame(board)
				var with_sky := changed(baseline, image, point)
				board.backdrop.hide()
				beam.hide()
				baseline = await frame(board)
				beam.show()
				image = await frame(board)
				var without_sky := changed(baseline, image, point)
				check(without_sky > 8, "Actual beam crosses the sampled camera ray")
				check(
					with_sky > 8 and with_sky >= without_sky * .45,
					"Distant panorama cannot overwrite the transparent beam"
				)
				board.backdrop.show()
				var blocker := MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3.ONE * 1.4
				blocker.mesh = box
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(.03, .10, .04)
				blocker.material_override = material
				field.add_child(blocker)
				blocker.global_position = camera.global_position.lerp(midpoint, .5)
				var occluded := await frame(board)
				beam.hide()
				var no_beam := await frame(board)
				check(
					changed(occluded, no_beam, point) < 3,
					"Opaque foreground hull geometry still occludes the beam"
				)
				blocker.queue_free()
				await process_frame
				beam.show()
				for ship in [player, enemy]:
					ship.get_node("Body").show()
				if angle == 0 or side == "player":
					await capture(
						board,
						(
							arena.resource_path.get_file().get_basename()
							+ "-"
							+ side
							+ "-angle"
							+ str(angle)
						)
					)
				for ship in [player, enemy]:
					ship.get_node("Body").hide()
				beam.queue_free()
				await process_frame
		board.queue_free()
		await process_frame
	print("Beam depth: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
