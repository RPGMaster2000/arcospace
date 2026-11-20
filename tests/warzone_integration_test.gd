extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Board = preload("res://scenes/board.tscn")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func operation(integrity: int) -> Resource:
	var state := State.new()
	var legacy_rules := Rules.duplicate()
	legacy_rules.warzone_lattice_enabled = false
	state.start(0, legacy_rules, 22731)
	state.defense.integrity = integrity
	state.defense.revealed = true
	for unit in state.defense.units: state.defense.neutralize(unit.encounter)
	state._secure_defense()
	state.generate_system()
	return state


func fight(supported: bool) -> void:
	var state := operation(100)
	var index := 0 if supported else 3
	check(state.can_engage(index) == supported, "Opening allied contact is immediately accessible and the distant patrol is not")
	state.update_navigation_position(state.battle_location(index))
	check(state.can_engage(index), "The player can intercept a hostile fleet at its live position")
	var session := Persistence.new()
	session.store.path = "user://warzone-integration-test.json"
	session.store.clear_run()
	var checkpoint := session.checkpoint_battle(state, index, 1712)
	check(checkpoint.saved, "Combat entry checkpoint writes")
	var resumed: Dictionary = session.store.load_run()
	check(not resumed.is_empty() and resumed.battle.environment == checkpoint.environment, "Save and resume preserves battle support and modifier")
	if resumed.is_empty():
		return
	state = resumed.state
	var board := Board.instantiate()
	board.expedition = state
	board.expedition_encounter = index
	board.battle_setup = state.prepare_battle(index, null, resumed.battle.environment)
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	var support: Dictionary = board.battle_environment.get("friendly_support", {})
	check((not support.is_empty()) == supported, "Only ongoing allied battles grant fleet support")
	if supported and not support.is_empty():
		board.turn_number = 1 + support.interval
		var before: int = board.enemy_hull + board.enemy_shields
		check(board._fire_turret_support() and not board._fire_turret_support(), "The allied shot fires once at its fixed interval")
		check(before - board.enemy_hull - board.enemy_shields == support.damage, "The shot uses the participating ally's snapshotted strength")
	var before_salvage: int = state.salvage
	var normal: int = state.enemy_profile(state.encounters[index]).destruction_salvage_reward
	board.winner = "player"
	board.enemy_hull = 0
	board._record_result()
	check(state.salvage == before_salvage + (normal / 2 if supported else normal), "Solo and supported fights grant their respective direct Salvage")
	var upgrades: int = Rules.standard_upgrades
	check(state.battle_upgrade_count(board.battle_result()) == (maxi(1, upgrades / 2) if supported else upgrades), "Supported combat reduces card upgrades without losing the reward choice")
	check(state.warzone.player_victories == 1 and state.encounters[index].completed and state.battles_won == 1, "Winning records the intervention and ordinary campaign progress")
	check(board.victory_description().contains("Hostile fleet defeated") and
		(board.victory_description().contains("Allied Defender") if supported else true),
		"The combat result explains the strategic outcome")
	board.free()
	session.store.clear_run()


func failed_intervention() -> void:
	var state := operation(100)
	var veteran: int = state.warzone.fleets[0].strength
	state._commit_activity_time(3)
	var board := Board.instantiate()
	board.expedition = state
	board.expedition_encounter = 0
	board.battle_setup = state.prepare_battle(0)
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	var balance: int = state.salvage
	board.enemy_hull = board.enemy_hull_capacity / 2
	board.player_hull = 0
	board.winner = "enemy"
	board._record_result()
	check(state.run_ended and not state.can_jump() and state.warzone.player_victories == 0 and state.salvage == balance,
		"An unsuccessful intervention grants no victory or reward")
	check(state.warzone.fleets[2].strength < Rules.warzone_tuning.hostile_strength and state.warzone.fleets[0].strength < veteran,
		"Defeat commits the damage inflicted and the NPC casualties from the battle interval")
	check(board.victory_description().contains("Hostile fleet remains") and board.victory_description().contains("Allied Defender"),
		"The defeat screen reports both sides of the intervention")
	check(not state.record_battle(board.battle_result()), "The failed battle cannot resolve twice")
	board.free()


func pyrrhic_campaign() -> void:
	var state := operation(1)
	state._commit_activity_time(150)
	check(state.warzone.fleet_count("allied") == 0, "The emergency opening can lose both autonomous allies")
	for index in [0, 1]:
		for fleet in state.warzone.fleets:
			if fleet.side == "hostile" and (fleet.destination == index or (index == 1 and fleet.role != "Defender")):
				state.warzone.player_victory(fleet.id)
		state.update_navigation_position(State.Defense.wire(state.warzone.objectives[index].position))
		state._commit_activity_time(state.warzone.tuning.capture_seconds)
	check(not state.can_jump(), "Two recently captured objectives still require consolidation")
	var before: int = state.salvage
	state._commit_activity_time(state.warzone.tuning.consolidation_seconds)
	check(state.can_jump() and state.warzone_outcome.get("grade") == "Pyrrhic Victory", "Pyrrhic Victory unlocks the real FTL gate")
	check(state.salvage == before + Rules.warzone_tuning.pyrrhic_salvage, "Objective victory grants its full campaign bonus")
	var store = Persistence.new().store
	var resumed = store.decode(store.encode(state))
	check(resumed != null and resumed.can_jump(), "A completed operation with no allies survives save decoding")
	if resumed != null:
		var saved: Dictionary = resumed.warzone_outcome.duplicate()
		check(resumed.generate_system() and resumed.system_number == 3 and resumed.is_defense(), "FTL continues to System 3")
		check(resumed.warzone_outcome == saved and resumed.salvage > state.salvage, "The next system retains the outcome and grants emergency support")


func contact_resolved_en_route() -> void:
	var state := operation(100)
	state.warzone.fleets[2].strength = 1
	state.begin_travel(0)
	check(state.navigation.leg_active and state.travel_destination == 0, "The player can pursue an engaged contact")
	state._commit_activity_time(4)
	check(state.encounters[0].completed and not state.navigation.leg_active and state.travel_destination == -1,
		"An allied victory cancels travel to the destroyed contact")
	var store = Persistence.new().store
	var old: Dictionary = store.encode(state)
	old.service = {}
	var resumed = store.decode(old)
	check(resumed != null and not resumed.service.is_empty() and resumed.warzone.snapshot() == state.warzone.snapshot(),
		"An older Warzone save gains the protected service without changing its fleet state")


func run() -> void:
	fight(false)
	fight(true)
	failed_intervention()
	pyrrhic_campaign()
	contact_resolved_en_route()
	print("Warzone integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
