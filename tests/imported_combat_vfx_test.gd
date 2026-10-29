extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func inspect_library(path: String) -> void:
	for name in DirAccess.get_directories_at(path): inspect_library(path.path_join(name))
	for name in DirAccess.get_files_at(path):
		if not name.ends_with(".tscn"): continue
		var scene = load(path.path_join(name))
		check(scene is PackedScene, "Imported scene loads: " + name)
		if scene is PackedScene:
			var instance = scene.instantiate()
			check(instance != null, "Imported scene instantiates: " + name)
			instance.free()
func run() -> void:
	inspect_library("res://third_party/combat_vfx/binbun")
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer is active")
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	# This presentation test does not exercise music; release its playback before exit.
	root.get_node("Music").player.stop()
	root.get_node("Music").player.stream = null
	for frame in range(8): await process_frame
	var effects = board.battle_effects
	var ship = board.get_node("BattleView/Viewport/Battlefield/PlayerShip")
	var state: Dictionary = board._both_states()
	effects._hit(ship, true, false, "player")
	var flash = ship.get_node_or_null("ImportedHullHit")
	check(flash != null, "Hull damage spawns imported hit")
	if flash != null:
		for light in flash.find_children("*", "Light3D", true, false): check(not light.visible, "Imported dynamic lights disabled")
		for sound in flash.find_children("*", "AudioStreamPlayer3D", true, false): check(sound.stream == null, "No duplicate effect audio")
		for particles in flash.find_children("*", "GPUParticles3D", true, false): check(particles.amount <= 8 and particles.one_shot, "Particle count and lifetime bounded")
	await create_timer(effects.hit_seconds * 0.3).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
		root.get_texture().get_image().save_png("res://.godot/testlogs/imported-hit-" + RenderingServer.get_current_rendering_method() + ".png")
	await create_timer(effects.hit_seconds + 0.1).timeout
	check(not is_instance_valid(flash), "Imported effect freed at existing hit duration")
	check(effects.temporary_nodes.is_empty(), "No temporary-node accumulation")
	check(board._both_states() == state, "VFX does not change combat state")
	effects.imported_hits_enabled = false
	effects._hit(ship, true, false, "player")
	check(ship.get_node_or_null("ImportedHullHit") == null, "Comparison toggle preserves original feedback")
	await create_timer(effects.hit_seconds + 0.1).timeout
	effects.imported_hits_enabled = true
	effects._hit(ship, false, true, "player")
	check(ship.get_node_or_null("ImportedHullHit") == null, "Shield-only hits retain shield effects")
	await create_timer(effects.hit_seconds + 0.2).timeout
	effects._hit(ship, true, false, "player")
	flash = ship.get_node_or_null("ImportedHullHit")
	board.free()
	await process_frame
	check(not is_instance_valid(flash), "Leaving combat cancels live effect")
	print("Imported combat VFX: %d failures" % failures)
	quit(1 if failures else 0)
