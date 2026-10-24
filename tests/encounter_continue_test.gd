extends SceneTree
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func board():
	var result = load("res://scenes/board_3d.tscn").instantiate()
	result.setup_settings = {"player_energy":7,"player_reactor":3,"modifier":0}
	result.get_node("BattleEffects").enabled = false
	root.add_child(result)
	current_scene = result
	return result
func run() -> void:
	var battle = board()
	battle.player_hull = 65
	check(not battle._check_winner(), "Hull above 50 cannot win")
	battle.player_hull = 17
	battle.player_shields = 1
	battle.player_energy = 99
	battle.player_reactor = 8
	battle.enemy_hull = 0
	battle._check_winner()
	battle.refresh_display()
	check(battle.get_node("MatchResult/Panel/Continue").visible, "Victory exposes Continue")
	var next: int = battle.next_modifier
	battle.refresh_display()
	check(next == battle.next_modifier and next >= 1 and next < battle.modifier.NAMES.size(), "Encounter modifier is rolled once and previewed")
	battle.get_node("MatchResult/Panel/Continue").pressed.emit()
	await process_frame
	battle = current_scene
	check(battle.player_hull == 17 and battle.player_shields == 20, "Only hull persists; shield resets")
	check(battle.player_energy == 10 and battle.player_reactor == 3, "Resources/production reset to setup plus first income")
	check(battle.encounter_number == 2 and battle.modifier.kind == next and battle.turn_number == 1, "Fresh encounter uses previewed modifier and restarts rounds")
	check(battle.ftl.charge == 1 and battle.ftl.disabled_turns == 0, "FTL resets")
	if battle.battle_effects.busy:
		await battle.battle_effects.finished
	await process_frame
	battle.ftl.charge = battle.ftl.charge_target
	battle._warp_out()
	battle.refresh_display()
	check(battle.get_node("MatchResult/Panel/Title").text == "EMP PULSE SUCCESS" and battle.get_node("MatchResult/Panel/Continue").visible, "Escape result survives refresh and allows Continue")
	battle.queue_free()
	await process_frame
	battle = board()
	battle.player_hull = 0
	battle._check_winner()
	battle.refresh_display()
	check(not battle.get_node("MatchResult/Panel/Continue").visible, "Defeat cannot continue with destroyed ship")
	battle._continue_encounter()
	check(current_scene == battle, "Defeat transition rejected")
	battle.queue_free()
	await process_frame
	print("Encounter continuation checks: %d failures" % failures)
	quit(1 if failures else 0)
