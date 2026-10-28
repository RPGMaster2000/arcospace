extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Result = preload("res://scripts/combat/battle_result.gd")
var failures := 0
var checks := 0
var store = Save.new()
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func checkpoint(state: Resource, marker: Dictionary = {}) -> Dictionary:
	check(store.save_run(state, marker), "Defense checkpoint writes: " + store.error)
	var loaded: Dictionary = store.load_run()
	check(not loaded.is_empty(), "Defense checkpoint reads: " + store.error)
	if not loaded.is_empty():
		check(JSON.stringify(Save.encode(loaded.state)) == JSON.stringify(Save.encode(state)), "Authoritative state and RNG roundtrip through disk")
		check(loaded.battle.is_empty() if marker.is_empty() else int(loaded.battle.index) == marker.index and loaded.battle.seed == marker.seed, "Unresolved encounter marker roundtrip")
	return loaded
func victory(state: Resource, index: int) -> void:
	state.defense.contact = index
	state.prepare_battle(index)
	var result = Result.new()
	result.encounter_index = index
	result.system_number = state.system_number
	result.result_id = 8000 + index
	result.winner = "player"
	result.escaped_by_ftl = true
	result.player_hull = state.hull
	result.salvage = state.salvage
	result.battles_won = state.battles_won + 1
	state.record_battle(result)
	state.active_battle = -1
func run() -> void:
	store.path = "res://.godot/starfront-persistence.json"
	store.clear_run()
	var state = State.new()
	state.start(0, preload("res://encounters/expedition_rules.tres"), 81)
	var start: Vector3 = state.defense.start
	state.begin_free_travel(State.Defense.wire(start * 0.7))
	state.navigation.report_movement(State.Defense.wire(start * 0.9))
	checkpoint(state)
	var enemy: Vector3 = state.defense.units[0].position
	state.navigation.report_movement(State.Defense.wire(enemy))
	check(state.defense.contact >= 0 and not state.navigation.leg_active, "Contact checkpoint is stopped")
	var index: int = state.defense.contact
	var loaded: Dictionary = checkpoint(state, {"index": index, "seed": "777"})
	if not loaded.is_empty():
		var host = preload("res://scenes/expedition.tscn").instantiate()
		host.persistence_enabled = false
		host.resume_data = loaded
		root.add_child(host)
		await process_frame
		check(is_instance_valid(host.battle) and host.state.active_battle == index, "Continue restores unresolved defense battle")
		check(host.state.defense.snapshot() == state.defense.snapshot(), "Battle restore never advances strategic state")
		host.queue_free()
		await process_frame
	victory(state, index)
	checkpoint(state)
	check(state.defense.reveal_pending and state.consume_defense_reveal() and not state.consume_defense_reveal(), "Reveal consumption commits exactly once")
	checkpoint(state)
	victory(state, 2)
	checkpoint(state)
	check(state.can_jump(), "Restored completion is eligible for voluntary FTL")
	state.generate_system()
	checkpoint(state)
	check(not state.defense.revealed and state.defense.integrity == 100 and state.navigation.position == State.Defense.wire(state.defense.start), "FTL checkpoint contains fresh fleet and player deployment")
	store.clear_run()
	var old_rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
	old_rules.game_mode = "exploration"
	var old_state = State.new()
	old_state.start(0, old_rules, 117)
	var old_data: Dictionary = Save.encode(old_state)
	old_data.metagame_version = 1
	old_data.erase("game_mode")
	old_data.erase("defense")
	var body: String = JSON.stringify({"revision": 1, "ended": false, "expedition": old_data, "battle": {}})
	var old_file := FileAccess.open(store.path, FileAccess.WRITE)
	old_file.store_string(JSON.stringify({"schema": 1, "payload": body, "sha256": body.sha256_text()}))
	old_file.close()
	var migrated: Dictionary = store.load_run()
	check(not migrated.is_empty() and not migrated.state.is_defense() and migrated.state.defense == null, "Version-1 on-disk save continues in exploration without inventing units")
	check(not store.warning.is_empty(), "Legacy mode is disclosed")
	var missing_mode: Dictionary = Save.encode(state)
	missing_mode.erase("game_mode")
	check(store.decode(missing_mode) == null, "Version-2 save cannot silently invent a missing mode")
	store.clear_run()
	print("Starfront persistence: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
