extends SceneTree
const Ships = preload("res://scripts/ships/ship_library.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.size = Vector2i(1280,720)
	for index in range(3,6):
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {"player_ship":0,"enemy_ship":index}
		board.get_node("BattleEffects").enabled = false
		board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
		board.get_node("CardMotion").settings.enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		board.enemy_shields = 0 # Unobstructed silhouette reference, no resource edits.
		board.refresh_display()
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/enemy-model-%d.png" % index)
		root.size = Vector2i(960,540)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/enemy-model-%d-960.png" % index)
		root.size = Vector2i(1280,720)
		board.queue_free()
		await process_frame
	print("Three enemy combat model captures complete")
	quit()
