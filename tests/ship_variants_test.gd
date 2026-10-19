extends SceneTree
const Ships = preload("res://scripts/ship_library.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var seen: Dictionary = {}
	for index in range(Ships.PLAYERS.size()):
		var data = Ships.PLAYERS[index]
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {"player_ship":index,"modifier":0}
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		current_scene = board
		check(board.player_hull == data.hull_capacity and board.player_shields == data.shields, "Ship hull/shield values")
		for key in ["materials","energy","crew"]:
			var production: String = {"materials":"synthesizer","energy":"reactor","crew":"quarters"}[key]
			check(board.get("player_"+key) == data.get(key)+data.get(production), "Correct profile plus first-turn income")
			check(board.get("player_"+production) == data.get(production), "Production stats")
		check(board.ftl.charge_target == data.ftl_turns and board.ftl.charge == 1, "Ship charge duration and first turn")
		check(is_equal_approx(board.ftl.failure_chance(4),0.2*(1-data.ftl_resistance)), "Multiplicative FTL resistance")
		check(is_equal_approx(board.ftl.failure_chance(100),0.6*(1-data.ftl_resistance)), "Existing cap applied before ship resistance")
		check(board.get_node("BattleView/Viewport/Battlefield/PlayerShip").hull_material.albedo_color == data.hull_color, "Profile tints Hull only")
		var enemy = board.enemy_ship_data
		check(board.enemy_hull == enemy.hull_capacity and board.enemy_shields == enemy.shields, "Enemy profile applied")
		check(board.enemy_energy == enemy.energy, "Enemy receives no income before enemy turn")
		board._begin_turn("enemy")
		board.enemy_timer.stop()
		for key in ["materials","energy","crew"]:
			var production: String = {"materials":"synthesizer","energy":"reactor","crew":"quarters"}[key]
			check(board.get("enemy_"+key) == enemy.get(key)+enemy.get(production), "Enemy profile production income")
		board.player_hull += 20
		board.winner = "player"
		board.refresh_display()
		board._continue_encounter()
		await process_frame
		board = current_scene
		check(board.player_hull == data.hull_capacity and board.player_ship_data == data, "Continue preserves selection and strips plating")
		board._restart_match()
		await process_frame
		board = current_scene
		check(board.player_hull == data.hull_capacity and board.player_ship_data == data and board.encounter_number == 1, "Restart resets same player selection")
		board.queue_free()
		await process_frame
	for sample in range(120):
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {"player_ship":0}
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		seen[board.enemy_ship_data.ship_name] = true
		board.queue_free()
		await process_frame
	check(seen.size() == 6, "All six enemies appear across fresh matches")
	# Replacement model remains per-resource, independent of battlefield duplication.
	var replacement_profile: Resource = Ships.PLAYERS[0]
	replacement_profile.model_scene = load("res://scenes/ship_3d.tscn")
	var custom = load("res://scenes/board_3d.tscn").instantiate()
	custom.setup_settings = {"player_ship":0}
	custom.get_node("BattleEffects").enabled = false
	root.add_child(custom)
	check(custom.engine_light == null and custom.player_ship_data == Ships.PLAYERS[0], "Optional model replaces only the selected ship and supports missing engine light")
	custom.queue_free()
	await process_frame
	replacement_profile.model_scene = null
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(menu)
	check(menu.selected_ship == 0, "Endeavour default")
	menu._select(1)
	check(menu.read_settings().player_ship == 1, "Selected ship controls battle settings")
	check(not menu.has_node("Panel/player_materials"), "Old starting options removed")
	for index in range(Ships.PLAYERS.size()):
		check(menu.get_node("Ships/Ship%d/Preview/Viewport" % index).get_child_count() == 3, "Real model previews")
	menu.queue_free()
	await process_frame
	print("Ship variant checks: %d failures" % failures)
	quit(1 if failures else 0)
