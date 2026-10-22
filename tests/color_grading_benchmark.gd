extends SceneTree
# Wall frame intervals include the whole scene on the measured host, not an
# estimate of Android GPU cost. Alternating ABBA blocks reduce order bias.
const BOARD = preload("res://scenes/board_3d.tscn")
const NAMES = ["off", "on"]
func _initialize() -> void: call_deferred("run")
func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		await RenderingServer.frame_post_draw
func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Benchmark requires rendering; use Mobile or Compatibility with a display")
		quit(1)
		return
	root.size = Vector2i(1280,720)
	var board = BOARD.instantiate()
	board.setup_settings = {"modifier":2}
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	board.process_mode = Node.PROCESS_MODE_DISABLED
	var grade = board.get_node("BattleView")
	grade.preset = grade.preset.duplicate(true)
	var results: Array = []
	# Warm both material paths before collecting any samples.
	for enabled in [false,true,false,true]:
		grade.preset.enabled = enabled
		await frames(24)
	for block in [0,1,1,0,0,1,1,0]:
		grade.preset.enabled = block == 1
		await frames(6)
		var start := Time.get_ticks_usec()
		await frames(24)
		var frame_ms := (Time.get_ticks_usec()-start)/24000.0
		results.append({"grading":NAMES[block],"mean_frame_ms":frame_ms})
	var info := {"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"viewport":Vector2i(1280,720),"battle_viewport":board.get_node("BattleView/Viewport").size,"scaling_3d":board.get_node("BattleView/Viewport").scaling_3d_scale,"frames_per_block":24,"blocks":results}
	print("GRADE_BENCHMARK "+JSON.stringify(info))
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	var file := FileAccess.open("res://.godot/testlogs/grade-benchmark-"+RenderingServer.get_current_rendering_method()+".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(info,"\t"))
	board.free()
	quit()
