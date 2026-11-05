extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
var failures: int = 0

class Store extends RefCounted:
	var calls: Array[String] = []
	var data: Dictionary = {}
	var marker: Dictionary = {}
	var succeed: bool = true
	func save_run(state: Resource) -> bool:
		calls.append("run")
		data = Save.encode(state)
		marker = {}
		return succeed
	func save_data(value: Dictionary, battle: Dictionary) -> bool:
		calls.append("checkpoint")
		data = value.duplicate(true)
		marker = battle.duplicate(true)
		return succeed
	func clear_run() -> bool:
		calls.append("clear")
		return succeed

class Board extends Node:
	var result_recorded: bool = false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var state = State.new()
	var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
	rules.game_mode = "exploration"
	rules.log_rolls = false
	state.start(0, rules, 1042)
	var session = Persistence.new()
	var store = Store.new()
	session.store = store
	check(session.save_candidate(state) and store.calls == ["run"], "Candidate is saved before activation")
	var before: Dictionary = Save.encode(state)
	var entry: Dictionary = session.checkpoint_battle(state, 0, 778899)
	check(entry.saved and entry.seed == 778899 and session.battle_checkpoint == before, "Entry preserves explicit seed and unconsumed state")
	check(Save.encode(state) == before, "Checkpoint creation does not mutate gameplay or RNG")
	var board = Board.new()
	state.salvage += 100
	check(session.save_progress(state, board) and store.data == before and store.marker.seed == "778899", "Unfinished combat saves entry state, never live changes")
	board.result_recorded = true
	check(session.save_progress(state, board) and store.data.salvage == state.salvage and store.marker.is_empty(), "Recorded result saves committed rewards")
	store.succeed = false
	var failed: Dictionary = session.checkpoint_battle(state, 1, 123)
	check(not failed.saved and failed.seed == 123 and session.battle_checkpoint == before and session.battle_marker.seed == "778899", "Failed checkpoint keeps previous entry and retry seed")
	check(not session.save_progress(state, board), "Write failure reaches caller")
	board.result_recorded = false
	state.run_ended = true
	check(not session.save_progress(state, board) and store.calls.back() == "clear", "Terminal cleanup takes priority over unfinished checkpoint and propagates failure")
	state.run_ended = false
	state.hull = 0
	store.succeed = true
	check(session.save_progress(state, board) and store.calls.back() == "clear", "Hull death clears the slot")
	session.enabled = false
	var calls: int = store.calls.size()
	check(session.save_progress(null, board) and session.save_candidate(state) and store.calls.size() == calls, "Disabled persistence neither writes nor rejects absent state")
	session.reset_battle()
	check(session.battle_checkpoint.is_empty() and session.battle_marker.is_empty(), "New run drops old entry data")
	board.free()
	print("Expedition persistence session: %d failures" % failures)
	quit(1 if failures else 0)
