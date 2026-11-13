extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/weekend")
	root.get_texture().get_image().save_png("res://.godot/testlogs/weekend/"+label+"-"+RenderingServer.get_current_rendering_method()+".png")
func run() -> void:
	for outcome in ["hull","systems_failure","emp","mothership","mothership_emp"]:
		root.size = Vector2i(960,540) if outcome == "emp" else Vector2i(1280,720)
		var rules: Resource = Rules.duplicate(true)
		rules.game_mode = "defense"
		rules.log_rolls = false
		var state := State.new()
		state.start(0,rules,31025)
		var boss: bool = outcome.begins_with("mothership")
		if boss: state.defense.revealed = true
		var index: int = state.defense.mothership_index() if boss else 0
		state.defense.contact = index
		var balance: int = state.salvage
		var board = preload("res://scenes/board_3d.tscn").instantiate()
		board.expedition = state
		Adapter.configure(board,state.prepare_battle(index))
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		board.enemy_timer.stop()
		if outcome.ends_with("emp"):
			board.ftl.charge = board.ftl.charge_target
			board._warp_out()
		elif outcome == "systems_failure":
			board.enemy_reactor = 0
			board.enemy_quarters = 0
			board._sync_systems_failure()
			board.systems_failure.remaining.enemy = 0
		else: board.enemy_hull = 0
		board._check_winner()
		board.refresh_display()
		var result: Control = board.get_node("MatchResult")
		var deadline := Time.get_ticks_msec()+6000
		while not result.started and Time.get_ticks_msec() < deadline: await process_frame
		check(result.started,"Committed result starts presentation")
		if not result.started:
			board.queue_free()
			await process_frame
			continue
		result.skip()
		var heading := "SYSTEM SECURED" if boss else ("VESSEL DISABLED" if outcome == "emp" else "VICTORY")
		check(result.banner.text == heading,"Correct heading for "+outcome)
		check(result.summary.earned == state.salvage-balance and result.summary.balance == state.salvage,"Summary uses committed earned reward and balance")
		if outcome == "systems_failure": check(result.subtitle.text == "Enemy Systems Disabled","Systems Failure does not imply hull destruction")
		if outcome == "emp": check(result.subtitle.text.contains("neutralized") and result.summary.upgrades == 0,"EMP describes recovery without inventing upgrade rewards")
		var committed: int = state.salvage
		result.skip()
		board._record_result()
		board.refresh_display()
		check(state.salvage == committed,"Repeated skip and refresh never duplicate rewards")
		check(not result.get_node("Panel/Continue").disabled,"Skip immediately enables existing continuation action")
		for dimensions in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(960,540),Vector2i(900,600)]:
			root.size = dimensions
			for frame in range(3): await process_frame
			result.fit()
			var next: Control = result.get_node("Panel/Continue")
			check(not next.get_global_rect().intersects(result.details_button.get_global_rect()),"Essential actions remain separate after resize")
			check(result.get_global_rect().encloses(result.rewards.get_global_rect()),"Rewards fit without essential scrolling")
		root.size = Vector2i(960,540) if outcome == "emp" else Vector2i(1280,720)
		for frame in range(4): await process_frame
		await capture("result-"+outcome)
		board.queue_free()
		for frame in range(4): await process_frame
	print("Weekend results: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
