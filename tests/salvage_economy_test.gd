extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
const Board = preload("res://scenes/board_3d.tscn")
const ORDINARY = preload("res://ships/enemy/marauder.tres")
const ELITE = preload("res://ships/enemy/marauder_vanguard.tres")
const BOSS = preload("res://ships/enemy/sentinel_dreadnought.tres")
const MINING = preload("res://encounters/mining_operation.tres")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func fresh() -> ExpeditionState:
	var config: Resource = Rules.duplicate(true)
	config.game_mode = "defense"
	config.defense_tuning.enemy_speed = 0.0
	config.defense_tuning.pressure_per_second = 0.0
	var state := State.new()
	state.start(0, config, 31025)
	return state

func reveal(state: ExpeditionState) -> void:
	state.defense.pressure = state.defense.reveal_threshold()
	state.defense.revealed = true

func load_json(state: ExpeditionState) -> ExpeditionState:
	return Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))), state.rules)

func begin_battle(state: ExpeditionState, index: int) -> Node:
	state.defense.contact = index
	var board := Board.instantiate()
	board.expedition = state
	Adapter.configure(board, state.prepare_battle(index))
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	return board

func finish(board: Node, method: String) -> void:
	match method:
		"emp":
			board.ftl.charge = board.ftl.charge_target
			board._warp_out()
		"hull":
			board.enemy_hull = 0
		"systems_failure":
			board.enemy_reactor = 0
			board.enemy_quarters = 0
			board._sync_systems_failure()
			board.systems_failure.remaining.enemy = 0
		"loss":
			board.player_hull = 0
		"draw":
			board.player_hull = 0
			board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()

func combat_checks() -> void:
	for rank in range(3):
		var profile: Resource = [ORDINARY, ELITE, BOSS][rank]
		for method in ["hull", "systems_failure", "emp"]:
			var state := fresh()
			var index: int = state.defense.mothership_index() if rank == 2 else 0
			if rank == 2: reveal(state)
			state.encounters[index].enemy_data = profile
			state.salvage = 7
			state.poi_effects.grant_production("reactor", 1, 3)
			var save := Persistence.new()
			save.store.path = "user://salvage-economy-test.json"
			save.store.clear_run()
			state.defense.contact = index
			save.checkpoint_battle(state, index, 777)
			var board := begin_battle(state, index)
			finish(board, method)
			var combat_reward: int = [3, 6, 10][rank] if method == "emp" else (
				profile.destruction_salvage_reward * (state.rules.elite_salvage_multiplier if rank == 1 else 1) + [5, 10, 20][rank])
			var expected := 7 + combat_reward + (10 if rank == 2 else 0)
			check(board.winner == "player" and state.salvage == expected and board.salvage == expected, "Committed and displayed balance for %d/%s" % [rank, method])
			check(state.encounters[index].completed and state.defense.unit_for(index).status == "neutralized", "All valid wins neutralize the encounter")
			check(state.defense.complete == (rank == 2) and state.defense.secured_reward_claimed == (rank == 2), "Only the mothership secures the system")
			check(state.poi_effects.production.reactor.battles == 2, "Temporary production charge consumed once")
			var rewards: String = board.victory_description()
			check(rewards.contains("System secured") == (rank == 2), "Completion reward shown only when committed")
			if method == "emp":
				check(state.pending_choice.is_empty() and rewards.contains("Allied EMP recovery") and not rewards.contains("Defense victory bonus"), "EMP grants recovery without combat upgrades or destruction bonus")
			else:
				check(rewards.contains("Standard reward") and rewards.contains("Defense victory bonus"), "Destruction and Systems Failure show both components")
			var replay = board.battle_result()
			check(not state.record_battle(replay) and state.salvage == expected, "Replaying the Board result has no effect")
			check(save.save_progress(state, board), "Save from the result screen writes the committed balance")
			var checkpoint: Dictionary = save.store.load_run()
			check(not checkpoint.is_empty() and checkpoint.battle.is_empty(), "Completed result is saved without a battle restart marker")
			if not checkpoint.is_empty():
				var restored: ExpeditionState = checkpoint.state
				check(restored.salvage == expected and restored.defense.secured_reward_claimed == (rank == 2), "Disk restoration preserves total and completion claim")
				restored.active_battle = index
				replay.result_id += 1
				check(not restored.record_battle(replay) and restored.salvage == expected, "A fresh stale result cannot replay after reload")
				if rank == 2:
					var legacy := Save.encode(restored)
					legacy.defense.erase("secured_reward_claimed")
					var old: ExpeditionState = Save.new().decode(legacy, restored.rules)
					check(old != null and old.defense.secured_reward_claimed and old.salvage == expected, "Previously secured legacy saves never receive a retroactive reward")
					restored.active_battle = 0
					replay.encounter_index = 0
					check(not restored.record_battle(replay) and restored.salvage == expected, "A different encounter cannot pay after the system is secured")
			save.store.clear_run()
			board.free()
	for method in ["loss", "draw"]:
		var state := fresh()
		state.salvage = 7
		var board := begin_battle(state, 0)
		finish(board, method)
		check(state.run_ended and state.salvage == 7 and board.salvage_rewards.is_empty(), "Failed or drawn Defense grants no Salvage")
		board.free()

func mining_checks() -> void:
	var state := fresh()
	var index := -1
	for i in state.encounters.size():
		if state.encounters[i].kind == "poi" and state.encounters[i].poi == MINING:
			index = i
			break
	if index < 0:
		for i in state.encounters.size():
			if state.encounters[i].kind == "poi":
				state.encounters[i].poi = MINING
				index = i
				break
	check(index >= 0, "Mining has an authoritative map anchor")
	if index < 0: return
	state.defense.tuning.pressure_per_second = 0.5
	check(state.resolve_approach(index, 4), "Reactivate Extraction resolves normally")
	check(state.salvage == 0 and state.defense.pressure == 1.0 and state.poi_effects.extraction_remaining == 15.0, "Four seconds elapse before extraction starts")
	check(not state.resolve_approach(index, 0) and state.salvage == 0, "A resolved mine cannot pay a second approach")
	state.defense.tuning.pressure_per_second = 0.0
	await create_timer(0.15).timeout
	check(state.poi_effects.extraction_remaining == 15.0, "Waiting does not advance extraction")
	state._commit_activity_time(14.75)
	var before_tick := load_json(state)
	check(before_tick != null and before_tick.salvage == 0 and before_tick.poi_effects.extraction_remaining == 0.25, "Save immediately before first payout preserves the clock")
	if before_tick == null: return
	var malformed := Save.encode(before_tick)
	malformed.defense_poi_effects.extraction.source = 0
	check(Save.new().decode(malformed, state.rules) == null, "Extraction must reference a completed Mining Operation")
	state = before_tick
	var from: Vector3 = state.defense.start
	state._advance_strategy(0.25, from, from.move_toward(state.defense.home, 1.75), false)
	check(state.salvage == 3 and state.poi_effects.extraction_paid == 3, "First payout occurs at fifteen seconds")
	state = load_json(state)
	check(state != null and state.salvage == 3 and state.poi_effects.extraction_remaining == 15.0, "Save immediately after payout preserves the paid ledger")
	if state == null: return
	var split := load_json(state)
	for tick in range(3):
		split._commit_activity_time(15.0)
		check(split.salvage == 6 + 3 * tick, "Each subsequent interval pays exactly three")
	state._commit_activity_time(14)
	var board := begin_battle(state, 0)
	await create_timer(0.15).timeout
	check(state.salvage == 3 and state.poi_effects.extraction_remaining == 1.0, "Active combat freezes extraction")
	state._commit_activity_time(20)
	check(state.salvage == 3, "Blocked strategic time cannot advance extraction")
	finish(board, "emp")
	check(state.poi_effects.extraction_remaining == 13.5 and board.salvage == state.salvage
		and board.salvage_rewards.extraction == 3, "Committed battle activity pays extraction before displaying the total")
	board.free()
	state.active_battle = -1
	state._commit_activity_time(100)
	check(state.poi_effects.extraction_paid == 12 and state.salvage == split.salvage + 3, "Large advances pay remaining intervals once, capped at twelve")
	state._commit_activity_time(60)
	check(state.salvage == 15, "Exhausted extraction never pays again")
	var partial := fresh()
	partial.encounters[index].poi = MINING
	check(partial.resolve_approach(index, 4), "Second fixture activates the mine")
	partial._commit_activity_time(14.9)
	reveal(partial)
	board = begin_battle(partial, partial.defense.mothership_index())
	finish(board, "emp")
	check(partial.salvage == 20 and partial.poi_effects.extraction_source < 0, "Mothership EMP secures the system before any further extraction")
	board.free()
	partial.active_battle = -1
	partial._commit_activity_time(80)
	check(partial.salvage == 20 and partial.generate_system() and partial.poi_effects.extraction_source < 0 and partial.salvage == 20, "Secured time and leaving the system cannot pay unused extraction")

func run() -> void:
	combat_checks()
	await mining_checks()
	print("Salvage economy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
