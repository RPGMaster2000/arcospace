extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func run() -> void:
	for ship_index in range(preload("res://scripts/ships/ship_library.gd").PLAYERS.size()):
		for enemy in Rules.enemy_ships:
			var host = load("res://scenes/expedition.tscn").instantiate()
			host.persistence_enabled = false
			host.selected_ship = ship_index
			root.add_child(host)
			host.state.encounters[0] = {"kind":"battle", "enemy":0, "enemy_data":enemy, "modifier":0, "completed":false, "title":enemy.ship_name}
			host.start_battle(0)
			var battle = host.battle
			battle.battle_effects.enabled = false
			if battle.battle_effects.busy: await battle.battle_effects.finished
			var expected_enemy: Resource = host.state.enemy_profile(host.state.encounters[0])
			check(battle.enemy_ship_data.ship_name == expected_enemy.ship_name and battle.enemy_hull == expected_enemy.hull_capacity, "Pressure-scaled Inspector enemy profile reaches real battle")
			check(battle.ftl.charge_target == host.state.ship().ftl_turns, "Ship-specific EMP Pulse duration preserved")
			battle.ftl.charge = battle.ftl.charge_target
			battle.refresh_display()
			await process_frame
			var label = battle.get_node("FTLPanel/Charge")
			var button = battle.get_node("FTLPanel/WarpButton")
			check(not label.visible and not battle.get_node("FTLPanel/Progress").visible and button.visible and is_equal_approx(button.position.x, 0), "Charged Jump replaces the FTL display")
			battle._warp_out()
			check(battle.escaped_by_ftl and battle.winner == "player", "Live EMP Pulse succeeds")
			check(host.state.pressure == 1 and host.state.salvage == 0, "Live escape grants one pressure and zero Salvage")
			battle.refresh_display()
			check(host.state.pressure == 1, "Refresh does not repeat reward")
			battle._continue_encounter()
			check(host.view_kind == "system" and host.state.encounters[0].completed and not host.state.can_visit(0), "Escape completes encounter through result screen")
			host.free()
			await process_frame
	print("Travel battle integration: 30 ship/enemy combinations, %d failures" % failures)
	quit(1 if failures else 0)

