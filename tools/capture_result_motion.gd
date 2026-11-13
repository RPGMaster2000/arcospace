extends SceneTree
## Record the real result transition with Godot --write-movie at fixed FPS.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var preferences = preload("res://scripts/ui/menu_preferences.gd")
	var skip_before: bool = preferences.skip_cinematics()
	var vfx_before: bool = preferences.battle_vfx()
	preferences.set_skip_cinematics(false)
	# Demonstrate that the UI remains animated when combat effects are disabled.
	preferences.set_battle_vfx(false)
	var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	var state = preload("res://scripts/expedition_state.gd").new()
	state.start(0,rules,31025)
	state.defense.contact = 0
	var board = preload("res://scenes/board_3d.tscn").instantiate()
	board.expedition = state
	preload("res://scripts/combat/battle_adapter.gd").configure(board,state.prepare_battle(0))
	root.add_child(board)
	board.enemy_timer.stop()
	for frame in range(12): await process_frame
	if board.battle_effects.busy: await board.battle_effects.finished
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	while not board.get_node("MatchResult").started: await process_frame
	await create_timer(2.2).timeout
	preferences.set_skip_cinematics(skip_before)
	preferences.set_battle_vfx(vfx_before)
	quit()
