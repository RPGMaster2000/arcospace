extends SceneTree
# Run headless for assignments/isolation; with a rendering driver also save comparisons.
const Ships = preload("res://scripts/ships/ship_library.gd")
const CAPITALS = [
	preload("res://ships/enemy/marauder_vanguard.tres"),
	preload("res://ships/enemy/sentinel_dreadnought.tres")
]
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	var error: Error = root.get_texture().get_image().save_png("res://.godot/testlogs/" + label + ".png")
	check(error == OK, "Saved " + label)

func check_frame(model: Node3D, viewport: Viewport, camera: Camera3D) -> void:
	var area := Rect2(Vector2.ZERO, Vector2(viewport.get_visible_rect().size))
	for part in model.get_node("Body").find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = part.mesh.get_aabb()
		for corner in range(8):
			var point: Vector3 = part.to_global(bounds.get_endpoint(corner))
			check(not camera.is_position_behind(point) and area.has_point(camera.unproject_position(point)), "Geometry fits camera: " + model.scene_file_path + "/" + str(part.name))

func run() -> void:
	var paths: Dictionary = {}
	var profiles: Array = []
	profiles.append_array(Ships.PLAYERS)
	profiles.append_array(CAPITALS)
	for profile in profiles:
		check(profile.model_scene != null, profile.ship_name + " model assigned")
		var path: String = profile.model_scene.resource_path
		check(not paths.has(path), "Unique scene " + profile.ship_name)
		paths[path] = true
		var first = profile.model_scene.instantiate()
		var second = profile.model_scene.instantiate()
		root.add_child(first)
		root.add_child(second)
		check(first.has_node("Body/Hull") and first.has_node("Body/Engine") and first.has_node("Shield"), "Animation node contract")
		var mesh_a: MeshInstance3D = first.get_node("Body/Hull")
		var mesh_b: MeshInstance3D = second.get_node("Body/Hull")
		check(mesh_a.mesh != mesh_b.mesh, "Geometry isolated between instances")
		var original_size: Vector3 = mesh_b.mesh.get_aabb().size
		# Primitive hull resources remain independently editable, including the interceptor wedge.
		if mesh_a.mesh is BoxMesh or mesh_a.mesh is PrismMesh:
			mesh_a.mesh.size *= 0.5
			check(mesh_b.mesh.get_aabb().size == original_size, "Geometry edit stays local")
		var original_color: Color = second.hull_material.albedo_color
		first.set_hull_color(Color.MAGENTA)
		check(second.hull_material.albedo_color == original_color, "Hull tint stays local")
		second.set_hull_strength(30)
		first.set_hull_strength(3)
		check(second.damage_material.get_shader_parameter("damage") == 0.0, "Damage stays local")
		first.set_shield_strength(0)
		check(not first.shield.visible and second.shield.visible, "Shield stays local")
		var detail_a: MeshInstance3D = first.get_node("Body/Details").get_child(0)
		var detail_b: MeshInstance3D = second.get_node("Body/Details").get_child(0)
		check(detail_a.material_override != detail_b.material_override, "Accent material stays local")
		var tween: Tween = first.create_tween()
		first.animate_hit(tween, true, 0.01)
		first.animate_repair(tween, 0.01)
		first.animate_shield(tween, 0.01, true)
		first.animate_explosions(tween, 0.01)
		await tween.finished
		first.free()
		second.free()
	# Exercise the real preview loader and preserve all six profile tints.
	root.size = Vector2i(1280,720)
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(menu)
	for index in range(6):
		var viewport: SubViewport = menu.get_node("Ships/Ship%d/Preview/Viewport" % index)
		var displayed = viewport.get_child(viewport.get_child_count() - 1)
		check(displayed.scene_file_path == Ships.PLAYERS[index].model_scene.resource_path, "Correct selection model")
		displayed.set_shield_strength(0)
		await process_frame
		check_frame(displayed, viewport, viewport.get_node("Camera"))
	for page in range(2):
		menu._show_ship_page(page)
		await capture("ship-models-selection-page%d" % page)
	menu.free()
	# Real combat loader, mirrored enemy transform, every battlefield, compact and wide views.
	for index in range(8):
		for field in range(6):
			var board = load("res://scenes/board_3d.tscn").instantiate()
			board.setup_settings = {"player_ship":mini(index,5),"modifier":field}
			if index >= 6:
				board.setup_settings["enemy_data"] = CAPITALS[index-6]
			board.get_node("BattleEffects").enabled = false
			root.add_child(board)
			board.enemy_timer.stop()
			var player = board.get_node("BattleView/Viewport/Battlefield/PlayerShip")
			check(player.scene_file_path == Ships.PLAYERS[mini(index,5)].model_scene.resource_path, "Correct combat player model")
			var enemy = board.get_node("BattleView/Viewport/Battlefield/EnemyShip")
			if index >= 6:
				check(enemy.scene_file_path == CAPITALS[index-6].model_scene.resource_path, "Correct capital model")
			for dimensions in [Vector2i(1280,720), Vector2i(960,540)]:
				root.size = dimensions
				await process_frame
				await process_frame
				var viewport: SubViewport = board.get_node("BattleView/Viewport")
				var camera: Camera3D = viewport.get_node("Battlefield/Camera3D")
				check_frame(player, viewport, camera)
				check_frame(enemy, viewport, camera)
			if field == 0:
				player.set_shield_strength(0)
				enemy.set_shield_strength(0)
				await capture("ship-models-combat-%d" % index)
			board.free()
	# Ordinary enemy fallback and custom scenes still instantiate in real combat.
	for index in range(Ships.ENEMIES.size()):
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {"player_ship":0,"enemy_ship":index}
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		var enemy = board.get_node("BattleView/Viewport/Battlefield/EnemyShip")
		check(enemy.has_node("Body/Hull") and enemy.has_node("Shield"), "Ordinary enemy functional")
		board.free()
	print("Ship models: %d failures" % failures)
	quit(1 if failures else 0)
