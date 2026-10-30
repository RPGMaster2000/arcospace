extends SceneTree
# Run headless for isolation/integration checks; rendering also checks shaders and writes screenshots.
const Board = preload("res://scenes/board_3d.tscn")
const Planet = preload("res://scenes/battlefield_planetary_orbit.tscn")
var checks: int = 0
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(8): await process_frame
func run() -> void:
	var paths: Array = preload("res://scripts/board_3d.gd").BATTLEFIELDS
	# Inspect scene-local Resources in isolation, including duplicate instances of one scene.
	for scene in paths + [Planet]:
		var a = scene.instantiate()
		var b = scene.instantiate()
		root.add_child(a)
		root.add_child(b)
		var material: ShaderMaterial = a.get_node("MeshInstance3D").material_override
		check(material != b.get_node("MeshInstance3D").material_override, "Backdrop material isolated: " + scene.resource_path)
		check(a.get_node("WorldEnvironment").environment != b.get_node("WorldEnvironment").environment, "Environment isolated")
		var old: Variant = b.get_node("MeshInstance3D").material_override.get_shader_parameter("space_color")
		material.set_shader_parameter("space_color", Color.RED)
		check(b.get_node("MeshInstance3D").material_override.get_shader_parameter("space_color") == old, "Editing one instance cannot recolor another")
		check(not a.get_node("Sun").shadow_enabled and not a.get_node("RimLight").shadow_enabled, "Decorative lighting casts no shadows")
		if a.has_node("Asteroids"):
			var rocks = a.get_node("Asteroids")
			check(rocks.get_child_count() == 8 and rocks.asteroid_count == 6, "Eight editable rocks, six initially visible")
			var first: Node3D = rocks.get_child(0)
			var original: Transform3D = first.transform
			rocks.set_process(false)
			rocks._process(2)
			check(not first.transform.is_equal_approx(original), "Rocks drift and rotate")
			rocks._process(100000)
			check(absf(first.position.x) <= rocks.wrap_width / 2 and absf(first.position.y) <= rocks.wrap_height / 2, "Rock movement wraps instead of spawning")
			rocks.asteroid_count = 0
			check(not first.visible, "Inspector count can hide rocks")
			rocks.asteroid_count = 8
			check(rocks.get_child(7).visible, "Inspector count can reveal authored rocks")
			check(not first is CollisionObject3D and first.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Decoration only; no shadow/collision")
			var camera: Camera3D = a.get_node("Camera3D")
			check(camera.to_local(first.global_position).z < camera.to_local(a.get_node("PlayerShip").global_position).z - 5, "Rocks are behind combat geometry")
		if scene == Planet:
			check(not a.has_node("BackgroundObjects/Planet"), "Planetary skybox contains the planet without a duplicate mesh")
		a.queue_free(); b.queue_free()
		await process_frame
	var ui_snapshot: Dictionary = {}
	for dimensions in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(960,540)]:
		root.size = dimensions
		for selection in range(7):
			var board = Board.instantiate()
			board.setup_settings = {"player_ship":0,"enemy_ship":0,"modifier":mini(selection,5)}
			board.get_node("CardHand").rng.seed = 777
			if selection == 6:
				board.setup_settings.modifier = 0
				board.normal_battlefield = Planet
			root.add_child(board)
			await settle()
			if board.battle_effects.busy: await board.battle_effects.finished
			var field: Node3D = board.get_node("BattleView/Viewport/Battlefield")
			check(field.scene_file_path in ([paths[0].resource_path, Planet.resource_path] if selection == 0 else [Planet.resource_path if selection == 6 else paths[selection].resource_path]), "Normal battles randomize deep space/planet; modifier and explicit arenas remain correct")
			check(board.modifier.kind == (0 if selection == 6 else selection), "Visual variant never introduces a modifier")
			check(board.player_hull == board.player_ship_data.hull_capacity and board.enemy_hull == board.enemy_ship_data.hull_capacity, "Lighting does not change ship stats")
			for slot in board.card_slots:
				var card: Control = board.get_node(slot)
				var key: String = str(dimensions) + str(slot)
				if selection == 0: ui_snapshot[key] = card.get_rect()
				check(card.get_rect() == ui_snapshot[key], "Environment does not move/resize combat cards")
			if DisplayServer.get_name() != "headless":
				# Let the initial modifier announcement finish before checking the battlefield capture.
				await create_timer(1.3).timeout
				await RenderingServer.frame_post_draw
				DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
				root.get_texture().get_image().save_png("res://.godot/testlogs/environment-%d-%d.png" % [selection,dimensions.x])
			board.queue_free()
			await process_frame
	# A normal override must not change an active modifier's presentation selection.
	var board = Board.instantiate()
	board.setup_settings = {"modifier":2}
	board.normal_battlefield = Planet
	root.add_child(board)
	await settle()
	check(board.get_node("BattleView/Viewport/Battlefield").scene_file_path == paths[2].resource_path, "Normal override ignored for modifiers")
	board.queue_free()
	await process_frame
	print("Battlefield environments: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
