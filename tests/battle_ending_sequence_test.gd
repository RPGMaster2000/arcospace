extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(12): await process_frame
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/ending-" + name + ".png")
func run() -> void:
	var state = preload("res://scripts/expedition_state.gd").new()
	state.start(0, preload("res://encounters/expedition_rules.tres"), 1042)
	state.start_upgrade_event(2)
	state.finish_upgrades()
	check(state.pending_choice == "upgrade" and state.upgrades_remaining == 2, "Unspent upgrades cannot be skipped")
	while state.pending_choice == "upgrade":
		state.choose_upgrade(state.upgrade_candidates()[0].identity_key())
	check(state.upgrades_remaining == 0, "Spending all eligible upgrades releases navigation")
	for outcome in ["emp", "victory", "defeat"]:
		root.size = Vector2i(960, 540) if outcome == "defeat" else Vector2i(1280, 720)
		var board = preload("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {"player_ship":0, "enemy_ship":0, "modifier":0}
		root.add_child(board)
		board.enemy_timer.stop()
		await create_timer(1.0).timeout
		await settle()
		if outcome == "emp":
			board.winner = "player"
			board.escaped_by_ftl = true
			board._record_result()
		else:
			if outcome == "victory": board.enemy_hull = 0
			else: board.player_hull = 0
			board._check_winner()
		board.refresh_display()
		if outcome != "emp":
			check(board.destruction_pending and not board.get_node("MatchResult").visible, "Destruction precedes result overlay")
			await create_timer(0.5).timeout
			await capture(outcome + "-explosions")
			await create_timer(0.75).timeout
			var bursting_ship: Node3D = board.get_node("BattleView/Viewport/Battlefield/" + ("EnemyShip" if outcome == "victory" else "PlayerShip"))
			check(bursting_ship.get_node("Body").visible and board.destruction_pending, "Explosion phase continues through the added second")
			await create_timer(0.7).timeout
			await capture(outcome + "-debris")
			await create_timer(0.95).timeout
			var ship: Node3D = board.get_node("BattleView/Viewport/Battlefield/" + ("EnemyShip" if outcome == "victory" else "PlayerShip"))
			check(not ship.get_node("Body").visible, "Destroyed ship breaks apart and stays absent")
		await settle()
		var result = board.get_node("MatchResult")
		check(result.visible and result.started, "Result sequence begins after effects")
		var reveal: Tween = result.animation
		board.refresh_display()
		board.refresh_display()
		check(result.animation == reveal, "HUD refresh cannot restart terminal reveal")
		if result.get_node("Panel/Continue").visible:
			check(result.get_node("Panel/Continue").disabled, "Unrevealed controls block keyboard activation")
		if outcome != "defeat":
			check(root.get_node("Music").current_track == "victory_normal", "EMP and destruction wins both play victory music")
		await create_timer(0.6).timeout
		await capture(outcome + "-title")
		await create_timer(3.5).timeout
		check(not result.running and result.lines.get_child_count() > 0, "Line reveal completes and releases controls")
		check(result.banner.position.y < result.size.y * 0.4, "Title moves into upper half")
		await capture(outcome + "-results")
		board.queue_free()
		await settle()
	print("Battle ending sequence: %d failures" % failures)
	quit(failures)
