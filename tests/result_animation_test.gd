extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
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
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/victory-results")
	root.get_texture().get_image().save_png("res://.godot/testlogs/victory-results/"+label+"-"+RenderingServer.get_current_rendering_method()+".png")
func run() -> void:
	var vfx_before := Preferences.battle_vfx()
	var skip_before := Preferences.skip_cinematics()
	var last_summary: Dictionary = {}
	Preferences.set_battle_vfx(false)
	Preferences.set_skip_cinematics(false)
	for outcome in ["hull","systems_failure","emp","mothership","mothership_emp","defeat","draw","maxed"]:
		root.size = Vector2i(960,540) if outcome == "emp" else Vector2i(1280,720)
		var rules: Resource = Rules.duplicate(true)
		rules.game_mode = "defense"
		rules.log_rolls = false
		var state := State.new()
		state.start(0,rules,31025)
		if outcome == "maxed":
			for level in range(2):
				state.start_upgrade_event(1000)
				while state.pending_choice == "upgrade":
					state.choose_upgrade(state.upgrade_candidates()[0].identity_key())
		var boss: bool = outcome.begins_with("mothership")
		if boss: state.defense.revealed = true
		var index: int = state.defense.mothership_index() if boss else 0
		state.defense.contact = index
		var board = preload("res://scenes/board_3d.tscn").instantiate()
		board.expedition = state
		Adapter.configure(board,state.prepare_battle(index))
		root.add_child(board)
		board.enemy_timer.stop()
		if board.battle_effects.busy: await board.battle_effects.finished
		if outcome.ends_with("emp"):
			board.ftl.charge = board.ftl.charge_target
			board._warp_out()
		elif outcome == "systems_failure":
			board.enemy_reactor = 0
			board.enemy_quarters = 0
			board._sync_systems_failure()
			board.systems_failure.remaining.enemy = 0
		elif outcome == "defeat": board.player_hull = 0
		elif outcome == "draw":
			board.player_hull = 0
			board.enemy_hull = 0
		else: board.enemy_hull = 0
		board._check_winner()
		board.refresh_display()
		var result = board.get_node("MatchResult")
		while not result.started: await process_frame
		last_summary = result.summary.duplicate(true)
		var saved := Save.encode(state)
		check(result.running,"Battle VFX disabled retains basic result UI animation")
		check(result.banner.modulate.a < 1.0 or result.banner.scale != Vector2.ONE,"Title begins in a visibly distinct state")
		var heading: String = "SYSTEM SECURED" if boss else ({"emp":"VESSEL DISABLED","defeat":"DEFEAT","draw":"DRAW"}.get(outcome,"VICTORY"))
		check(result.banner.text == heading,"Correct actual outcome heading: "+outcome)
		check(result.burst.electronic == outcome.ends_with("emp"),"EMP uses electronic arcs, never destruction rays")
		if outcome == "systems_failure": check(result.subtitle.text == "Enemy Systems Disabled","Systems Failure keeps correct identity")
		var reveal: Tween = result.animation
		result.play()
		board.refresh_display()
		check(result.animation == reveal,"Repeated play/refresh cannot restart reveal")
		if outcome == "hull":
			await capture("00-initial")
			await create_timer(0.16).timeout
			check(result.banner.modulate.a > 0 and result.title_progress > 0,"Title genuinely changes opacity and position over time")
			await capture("01-heading")
			await create_timer(0.48).timeout
			var value := int(result.values[0].node.text)
			check(value > 0 and value < result.values[0].target,"Committed Salvage visibly counts through intermediate values")
			check(result.values[0].column.modulate.a > 0 and result.values[0].icon.visible,"Reward icon actually reveals")
			await capture("02-counting")
			while result.running: await process_frame
			await capture("03-complete")
		elif outcome == "mothership":
			while result.running: await process_frame
		else:
			# Exercise Skip in different title/counter/action phases, including
			# immediate skip and repeated skip on the same frame.
			var delay: float = {"systems_failure":0.15,"emp":0.5,"mothership_emp":1.3,"defeat":0.0,"draw":0.9,"maxed":0.0}[outcome]
			if delay > 0: await create_timer(delay).timeout
			result.skip()
			result.skip()
		check(not result.running,"Normal completion and Skip finish the sequence")
		for node in result.animated:
			check(is_equal_approx(node.modulate.a,1.0) and node.scale.is_equal_approx(Vector2.ONE),"Every reveal restores opacity and scale")
			check(not node.has_meta("visual_reveal"),"No helper tween survives completion or skip")
		for item in result.values: check(int(item.node.text) == item.target,"Every counter reaches exact final committed value")
		for button in result.disabled_states: check(not button.disabled,"Existing actions are enabled after reveal")
		check(not result.skip_button.visible,"Skip cannot obscure completed actions")
		check(Save.encode(state) == saved,"Animation, Skip and refresh never mutate authoritative state")
		check(result.summary.upgrades == 0 if outcome.ends_with("emp") else true,"EMP invents no upgrade availability")
		if outcome == "maxed":
			check(result.summary.upgrades == 0 and state.pending_choice.is_empty(),"Exhausted upgrade pool creates no nonexistent reward")
			check(result.get_node("Panel/Continue").text == "Star System","Primary action does not advertise unavailable upgrades")
		await capture("final-"+outcome)
		board.queue_free()
		for frame in range(4): await process_frame
	# Existing accessibility preference gives a complete instant summary.
	Preferences.set_skip_cinematics(true)
	var reduced = preload("res://scenes/board_3d.tscn").instantiate()
	root.add_child(reduced)
	reduced.enemy_timer.stop()
	if reduced.battle_effects.busy: await reduced.battle_effects.finished
	reduced.enemy_hull = 0
	reduced._check_winner()
	reduced.refresh_display()
	var summary = reduced.get_node("MatchResult")
	var deadline := Time.get_ticks_msec()+6000
	while not summary.started and Time.get_ticks_msec() < deadline: await process_frame
	for frame in range(2): await process_frame
	check(summary.started and not summary.running and summary.banner.modulate.a == 1,"Skip Cinematics preserves a fully visible accessible summary")
	check(not summary.get_node("Panel/Continue").disabled,"Reduced presentation is immediately interactive")
	reduced.queue_free()
	for frame in range(4): await process_frame
	# The controller may continue/exit synchronously after scheduling play.
	# remove_child happens before queue_free, leaving a valid detached object
	# whose deferred call must do no work and must never grab focus.
	var detached = preload("res://scenes/match_result.tscn").instantiate()
	root.add_child(detached)
	detached.show()
	detached.summary = last_summary
	detached.play.call_deferred()
	root.remove_child(detached)
	await process_frame
	check(not detached.started and not detached.running,"Deferred reveal ignores a detached result scene")
	check(detached.animation == null and detached.get_child_count() == 2,"Detached reveal creates no controls or tweens")
	detached.free()
	var next_action := Button.new()
	next_action.text = "Next screen action"
	root.add_child(next_action)
	next_action.grab_focus()
	var exiting_parent := Control.new()
	root.add_child(exiting_parent)
	var queued = preload("res://scenes/match_result.tscn").instantiate()
	exiting_parent.add_child(queued)
	queued.show()
	queued.summary = last_summary
	queued.play.call_deferred()
	exiting_parent.queue_free()
	for frame in range(2): await process_frame
	check(root.gui_get_focus_owner() == next_action,"Queued ancestor cannot steal focus from the next screen")
	check(not is_instance_valid(exiting_parent),"Queued presentation is released without orphaned callbacks")
	next_action.free()
	Preferences.set_battle_vfx(vfx_before)
	Preferences.set_skip_cinematics(skip_before)
	print("Result animation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
