extends SceneTree
## Production modifier scenes, camera-pose clearance, HUD bounds and real beam pixels.
const Board = preload("res://scenes/board_3d.tscn")
const VFX = preload("res://scripts/effects/imported_combat_vfx.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const PROFILES = [
	preload("res://ships/enemy/scrap_skiff.tres"),
	preload("res://ships/enemy/siege_monitor.tres"),
	preload("res://ships/enemy/axiom_command_nexus.tres")
]
var checks := 0
var failures := 0
var previous_skip := false
var hand_layouts: Dictionary = {}


func _initialize() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	previous_skip = Preferences.skip_cinematics()
	Preferences.set_skip_cinematics(true)
	call_deferred("run")


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func settle() -> void:
	for i in range(4):
		await process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/modifier-environments")
	root.get_texture().get_image().save_webp(
		(
			"res://.godot/testlogs/modifier-environments/%s-%s.webp"
			% [RenderingServer.get_current_rendering_method(), label]
		)
	)


func frame(board: Node) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return board.get_node("BattleView/Viewport").get_texture().get_image()


func changed(a: Image, b: Image, center: Vector2) -> int:
	var count := 0
	var rect := Rect2i(Vector2i(center) - Vector2i(12, 12), Vector2i(24, 24)).intersection(
		Rect2i(Vector2i.ZERO, a.get_size())
	)
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var d := a.get_pixel(x, y) - b.get_pixel(x, y)
			if absf(d.r) + absf(d.g) + absf(d.b) > 0.12:
				count += 1
	return count


func scenery_clear(field: Node3D, point: Vector3) -> bool:
	var nodes := field.get_node("EnvironmentGeometry").find_children(
		"*", "GeometryInstance3D", true, false
	)
	if field.has_node("Asteroids"):
		nodes.append_array(
			field.get_node("Asteroids").find_children("*", "GeometryInstance3D", true, false)
		)
	for node in nodes:
		if node is MeshInstance3D:
			if node.get_aabb().grow(0.15).has_point(node.to_local(point)):
				print("SCENERY_BLOCK ", node.name, " at ", point, " origin ", node.global_position)
				return false
		elif node is MultiMeshInstance3D:
			var transforms: Array = node.get_meta("scenery_transforms")
			for authored in transforms:
				var transform: Transform3D = node.global_transform * authored
				if node.multimesh.mesh.get_aabb().grow(0.3).has_point(
					transform.affine_inverse() * point
				):
					print("SCENERY_BLOCK ", node.name, " at ", point, " origin ", transform.origin)
					return false
	return true


func geometry_checks(board: Node, label: String) -> void:
	var field: Node3D = board.get_node("BattleView/Viewport/Battlefield")
	var geometry: Node3D = field.get_node("EnvironmentGeometry")
	check(
		geometry.find_children("*", "CollisionObject3D", true, false).is_empty(),
		"Scenery has no colliders " + label
	)
	check(
		geometry.find_children("*", "Light3D", true, false).is_empty(),
		"Scenery adds no lights " + label
	)
	check(
		geometry.find_children("*", "GeometryInstance3D", true, false).size() <= 14,
		"Bounded scenery draw nodes " + label
	)
	for node in geometry.find_children("*", "GeometryInstance3D", true, false):
		check(
			node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"Scenery does not cast shadows " + label
		)
	check(
		board.backdrop.mesh is SphereMesh and board.backdrop.get_meta("infinite_panorama", false),
		"Direction-aware enclosing sky " + label
	)
	check(
		(
			board.backdrop.material_override.shader.resource_path
			== "res://shaders/battle_space_sky.gdshader"
		),
		"Existing depth-correct sky shader " + label
	)
	var director = board.cinematic_director
	director._begin("clearance-audit", false)
	for ship in [director.player, director.enemy]:
		check(scenery_clear(field, ship.global_position), "Clear combatants " + label)
		for offset in [
			director.settings.establishing_from,
			director.settings.establishing_to,
			director.settings.flyby_from,
			director.settings.flyby_to,
			director.settings.confrontation_offset,
			director.settings.attacker_offset,
			director.settings.victim_offset,
			director.settings.orbit_offset
		]:
			check(
				scenery_clear(field, director._pose(ship, offset).origin),
				"Clear cinematic camera pose " + label
			)
	for step in range(17):
		var at: Vector3 = (
			director.player.global_position
			+ (
				director.player.global_basis.x.normalized()
				* director.settings.boost_distance
				* step
				/ 16.0
			)
		)
		check(scenery_clear(field, at), "Clear victory departure corridor " + label)
	director.cancel()


func beam_checks(board: Node, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var director = board.cinematic_director
	var actor: Node3D = director.player
	var target: Node3D = director.enemy
	var midpoint := actor.global_position.lerp(target.global_position, 0.5)
	var camera: Camera3D = board.battle_camera
	var point := camera.unproject_position(midpoint)
	var baseline := await frame(board)
	var beam: Node3D = VFX.beam(actor, target)
	beam.set("pulse_strength", 0.0)
	beam.call("_set_shader_param", "speed_scale", 0.0)
	var with_beam := await frame(board)
	check(
		changed(baseline, with_beam, point) > 8,
		"Actual beam visible over modifier environment " + label
	)
	await capture(label + "-beam")
	var blocker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.4
	blocker.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.03, 0.10, 0.04)
	blocker.material_override = material
	board.get_node("BattleView/Viewport/Battlefield").add_child(blocker)
	blocker.global_position = camera.global_position.lerp(midpoint, 0.5)
	var occluded := await frame(board)
	beam.hide()
	var no_beam := await frame(board)
	check(changed(occluded, no_beam, point) < 3, "Opaque ship proxy still occludes beam " + label)
	blocker.queue_free()
	beam.queue_free()
	await process_frame


func run() -> void:
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await source_data_checks()
	for modifier in range(1, 8):
		var label: String = ["asteroid", "ion", "solar", "nebula", "rift", "metal", "psionic"][
			modifier - 1
		]
		for profile_index in range(3):
			var board = Board.instantiate()
			board.setup_settings = {
				"player_ship": 0, "enemy_data": PROFILES[profile_index], "modifier": modifier
			}
			board.get_node("BattleEffects").enabled = false
			root.add_child(board)
			board.enemy_timer.stop()
			await settle()
			check(
				board.enemy_ship_data == PROFILES[profile_index],
				"Light/heavy/mothership profile is actually bound " + label
			)
			geometry_checks(board, label)
			check(
				(
					board.modifier.kind == modifier
					and board.player_hull == board.player_ship_data.hull_capacity
					and board.enemy_hull == board.enemy_ship_data.hull_capacity
				),
				"Environment leaves battle setup unchanged " + label
			)
			if profile_index == 0:
				await create_timer(1.6).timeout
				ui_checks(board, label)
				await capture(label + "-normal")
				await beam_checks(board, label)
				var director = board.cinematic_director
				director._begin("capture-audit", false)
				for shot in ["establishing", "flyby", "attacker", "victim"]:
					var ship: Node3D = director.player if shot == "attacker" else director.enemy
					var offset: Vector3 = {
						"establishing": director.settings.establishing_from,
						"flyby": director.settings.flyby_from,
						"attacker": director.settings.attacker_offset,
						"victim": director.settings.victim_offset
					}[shot]
					director._set_camera(
						director._pose(ship, offset), director.settings.cinematic_fov
					)
					await settle()
					await capture(label + "-" + shot)
				director.cancel()
				for size in [Vector2i(960, 540), Vector2i(1280, 573)]:
					root.size = size
					await settle()
					ui_checks(board, label)
					await capture(label + "-%dx%d" % [size.x, size.y])
				root.size = Vector2i(1280, 720)
				await sequence_checks(board, label)
			board.queue_free()
			await settle()
	Preferences.set_skip_cinematics(previous_skip)
	print("Modifier environments: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func sequence_checks(board: Node, label: String) -> void:
	var director = board.cinematic_director
	var field: Node3D = board.get_node("BattleView/Viewport/Battlefield")
	var rest: Transform3D = board.battle_camera.global_transform
	var viewport_rect: Rect2 = board.get_node("BattleView").get_rect()
	var before: Dictionary = board._both_states()
	var scenery_rest: Transform3D = field.get_node("EnvironmentGeometry").global_transform
	var rng_states := [
		board.hand.rng.state,
		board.enemy_hand.rng.state,
		board.enemy_ai.rng.state,
		board.modifier.rng.state
	]
	var original: Resource = director.settings
	director.settings = original.duplicate(true)
	# Test-only duration compression: production paths, offsets and settings stay authored.
	director.settings.introduction_seconds = Vector3(0.15, 0.15, 0.15)
	director.settings.attack_seconds = 0.18
	director.settings.orbit_seconds = 0.18
	director.settings.engine_charge_seconds = 0.06
	director.settings.boost_seconds = 0.12
	director.settings.fade_seconds = 0.06
	var stages: Array[String] = []
	var collect := func(stage: String): stages.append(stage)
	director.stage_changed.connect(collect)
	var observe := func():
		if director.active:
			check(
				scenery_clear(field, board.battle_camera.global_position),
				"Camera path remains clear in motion " + label
			)
			if director.kind == "destruction":
				check(
					(
						board.get_node("BattleView").get_rect() == viewport_rect
						and board.get_node(board.card_slots[0]).is_visible_in_tree()
					),
					"Destruction preserves the normal viewport and hand " + label
				)
	process_frame.connect(observe)
	Preferences.set_skip_cinematics(false)
	await director.introduction()
	check(
		(
			stages.find("establishing") >= 0
			and stages.find("flyby") > stages.find("establishing")
			and stages.find("confrontation") > stages.find("flyby")
		),
		"Three introduction shots run in order " + label
	)
	await director.attack(director.player, director.enemy, false, false)
	await director.attack(director.enemy, director.player, true, false)
	check(
		await director.departure(board.victory_transition),
		"Orbit, boost and fade complete " + label
	)
	board.victory_transition.curtain.hide()
	check(
		"victory_orbit" in stages and "engine_boost" in stages and "fade_to_black" in stages,
		"Full departure stages execute " + label
	)
	check(
		board.battle_camera.global_transform.is_equal_approx(rest),
		"Camera restores after sequences " + label
	)
	check(
		(
			board._both_states() == before
			and (
				rng_states
				== [
					board.hand.rng.state,
					board.enemy_hand.rng.state,
					board.enemy_ai.rng.state,
					board.modifier.rng.state
				]
			)
		),
		"Environment/camera animation never changes combat state or RNG " + label
	)
	Preferences.set_skip_cinematics(true)
	await director.introduction()
	check(
		not director.active and board.battle_camera.global_transform.is_equal_approx(rest),
		"Skip preference leaves the battle camera usable " + label
	)
	process_frame.disconnect(observe)
	director.stage_changed.disconnect(collect)
	director.settings = original
	check(
		field.get_node("EnvironmentGeometry").global_transform == scenery_rest,
		"World-space scenery does not follow the cinematic camera " + label
	)
	for ship in [director.player, director.enemy]:
		var light: OmniLight3D = ship.get_node("Body/HullVisibilityLight")
		check(light.visible, "Existing hull visibility fill is active " + label)
		var sequence := board.create_tween()
		ship.animate_destruction(sequence)
		sequence.set_speed_scale(100.0)
		await sequence.finished
		check(
			not light.visible and not ship.get_node("Body").visible,
			"Existing destruction hides its hull light with the fragmented hull " + label
		)


func ui_checks(board: Node, label: String) -> void:
	var rects: Array = []
	for slot in board.card_slots:
		rects.append(board.get_node(slot).get_rect())
	var key := str(root.size)
	if not hand_layouts.has(key):
		hand_layouts[key] = rects
	check(
		rects == hand_layouts[key],
		"All six cards keep identical layout across environments " + label + key
	)


func source_data_checks() -> void:
	for modifier in range(1, 8):
		var scene: PackedScene = preload("res://scripts/board_3d.gd").BATTLEFIELDS[modifier]
		var a: Node3D = scene.instantiate()
		var b: Node3D = scene.instantiate()
		b.get_node("EnvironmentGeometry").reduced_density = true
		seed(99123)
		var expected := randi()
		seed(99123)
		root.add_child(a)
		check(randi() == expected, "Scene construction does not consume global gameplay RNG")
		root.add_child(b)
		var first: Node3D = a.get_node("EnvironmentGeometry")
		var reduced: Node3D = b.get_node("EnvironmentGeometry")
		check(
			first.get_child_count() == reduced.get_child_count(),
			"Android retains every environment landmark"
		)
		for node in first.get_children():
			if node is MultiMeshInstance3D:
				var other: MultiMeshInstance3D = reduced.get_node(NodePath(node.name))
				var transforms: Array = node.get_meta("scenery_transforms")
				check(
					(
						transforms.is_read_only()
						and transforms == other.get_meta("scenery_transforms")
					),
					"Seeded construction data is deterministic and immutable"
				)
				check(
					other.multimesh.visible_instance_count <= node.multimesh.visible_instance_count,
					"Android reduces only distant small-instance counts"
				)
		if modifier == 6:
			check(
				(
					first.has_node("HullPlating")
					and first.has_node("TwistedGirders")
					and first.has_node("BrokenHullFrames")
					and not first.has_node("IonBankLeft")
				),
				"Metal Storm constructs wreckage rather than Ion clouds"
			)
		if modifier == 7:
			check(
				(
					first.has_node("AnomalousRing0")
					and first.has_node("DistantMonolith0")
					and not first.has_node("DistantDischarge0")
				),
				"Psionic Storm constructs geometry rather than lightning"
			)
		a.queue_free()
		b.queue_free()
		await process_frame
