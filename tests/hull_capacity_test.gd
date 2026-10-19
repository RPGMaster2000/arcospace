extends SceneTree
const Effects = preload("res://scripts/cards/card_effects.gd")
const Data = preload("res://scripts/cards/card_data.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func state(hull: int, shield: int) -> Dictionary:
	return {"hull":hull,"shields":shield,"materials":100,"energy":100,"crew":100,"synthesizer":2,"reactor":2,"quarters":2}
func card(effects: Dictionary):
	var result = Data.new()
	result.family = "materials"
	result.cost = 0
	result.effects = effects
	return result
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var target = state(30,10)
	Effects.play(card({"hull":20}),target,state(30,10))
	check(target.hull == 50, "Repairs fill permanent hull then add unlimited plating")
	Effects.play(card({"damage":12}),state(30,10),target)
	check(target.shields == 0 and target.hull == 48, "Shield then plating damage")
	Effects.play(card({"damage":18}),state(30,10),target)
	check(target.hull == 30, "Remaining plating then permanent hull damage")
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	current_scene = board
	check(board.player_hull_capacity == 30 and board.enemy_hull_capacity == 30, "Both starter capacities are 30")
	board.player_hull_capacity = 35 # Exercise configurable capacities.
	check(board.permanent_damage(48,30,35) == 5 and board.permanent_damage(50,40,35) == 0, "FTL excludes consumed plating")
	board.player_hull = 50
	board.player_shields = 0
	board._resolve_card("enemy",0,false,card({"damage":10}))
	check(board.player_hull == 40 and board.ftl.disabled_turns == 0, "Plating-only hit never disrupts FTL")
	board.ftl.rng.seed = 7
	var sample: float = board.ftl.rng.randf()
	board.ftl.rng.seed = 7
	board._resolve_card("enemy",0,false,card({"damage":10}))
	check(board.player_hull == 30 and (board.ftl.disabled_turns > 0) == (sample < board.ftl.failure_chance(5)), "Cross-boundary hit uses only five permanent hull damage for FTL")
	board.player_hull = 40
	board._resolve_card("player",0,false,card({"hull":100}))
	check(board.player_hull == 140 and board.winner.is_empty(), "No plating cap and no hull victory")
	board.player_hull = 50
	board.player_hull_capacity = 45
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	check(board.player_hull_label.text == "Hull 50/45" and board.player_hull_label.get_theme_color("font_color") == board.get_node("PlayerHullBar").plating_color, "Bar identifies temporary excess at custom capacity")
	board._continue_encounter()
	await process_frame
	board = current_scene
	check(board.player_hull == 45 and board.player_hull_capacity == 45 and board.starting_player_hull == 45, "Capacity retained but plating removed on transition")
	board.queue_free()
	await process_frame
	print("Hull capacity checks: %d failures" % failures)
	quit(1 if failures else 0)
