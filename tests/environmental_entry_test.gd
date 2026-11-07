extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Environment = preload("res://scripts/expedition/battle_environment.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func host(store: RefCounted, data: Dictionary) -> Node:
	var node = load("res://scenes/expedition.tscn").instantiate()
	node.save_store = store
	node.resume_data = data
	node.use_star_map = false
	root.add_child(node)
	current_scene = node
	return node

func run() -> void:
	var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
	rules.game_mode = "exploration"
	rules.log_rolls = false
	var state = State.new()
	state.start(0, rules, 1042)
	state.navigation.checkpoint_position([3, 0, 4])
	var index := -1
	for i in state.encounters.size():
		if state.encounters[i].kind == "battle": index = i; break
	var store = Save.new()
	store.path = "user://environment_entry_test.json"
	store.clear_run()
	check(store.save_run(state), "New neutral expedition saves")
	var node = host(store, {"state": state, "battle": {}})
	node.show_battle_preview(index)
	var briefing = node.view.find_child("ModifierDetails", true, false)
	check(not briefing.visible, "Neutral preview hides environmental labels")
	var rng: int = state.rng.state
	node.start_battle(index, 778899)
	check(is_instance_valid(node.battle), "Neutral battle enters")
	if not is_instance_valid(node.battle):
		node.free()
		quit(1)
		return
	node.battle.enemy_timer.stop()
	var snapshot: Dictionary = node.battle.battle_environment
	check(Environment.valid_snapshot(snapshot) and snapshot.legacy_modifier == 0 and state.rng.state == rng, "Entry snapshot is neutral and gameplay RNG is untouched")
	check(node.battle.modifier.kind == 0 and node.battle.hand.drop_multiplier == 1.0, "Neutral combat has normal draw rules")
	var panel = node.battle.get_node("ModifierDisplay/Meter")
	check(not panel.visible and panel.get_node("Text").text.is_empty(), "Neutral combat has no environmental label")
	check(store.load_run().battle.environment == snapshot, "Marker saves exact entry snapshot before combat")
	state.navigation.checkpoint_position([8, 0, 9])
	state.environmental_instances.append(Environment.instance("future", Environment.TEMPORAL_RIFT))
	check(node.battle.battle_environment == snapshot, "Live movement/world changes never replace active snapshot")
	check(node._save_and_quit(), "Real Save and Quit succeeds")
	await process_frame
	var menu = current_scene
	check(menu.saved_run.battle.environment == snapshot, "Menu Continue reads the frozen entry")
	# Existing Continue path, with test-only cinematic timing.
	menu.showcase.skip_cinematics = true
	menu.continue_fade_duration = 0.001
	menu.white_fade_duration = 0.001
	menu.map_reveal_duration = 0.001
	menu.showcase._stop_tween()
	menu.showcase._finish_intro()
	menu.showcase.logo.modulate.a = 0.0
	menu.showcase.phase = menu.showcase.Phase.SHIP_SELECTION
	menu._selection_ready()
	menu._continue_expedition()
	for frame in range(8): await process_frame
	node = current_scene
	check(node.has_method("start_battle") and is_instance_valid(node.battle), "Continue reconstructs battle")
	if node.has_method("start_battle") and is_instance_valid(node.battle):
		node.battle.enemy_timer.stop()
		check(node.battle.battle_environment == snapshot and node.battle.modifier.kind == 0, "Continue reuses exact snapshot")
	node.free()
	await process_frame
	# No snapshot/world fields in an existing unfinished battle: preserve its modifier.
	var legacy: Dictionary = Save.encode(state)
	legacy.erase("environmental_instances")
	legacy.encounters[index].modifier = 4
	check(store.save_data(legacy, {"index": index, "seed": "778899"}), "Legacy marker remains accepted")
	var loaded: Dictionary = store.load_run()
	node = host(store, loaded)
	node.battle.enemy_timer.stop()
	check(node.battle.modifier.kind == 4 and node.battle.battle_environment.legacy_modifier == 4, "Legacy unfinished battle restores original effect")
	check(node.battle.get_node("ModifierDisplay/Meter").visible, "Legacy effect still has its label")
	node.free()
	await process_frame
	# A failed write returns the same snapshot to the retry adapter.
	loaded = store.load_run()
	var session = Persistence.new()
	session.store = store
	DirAccess.make_dir_absolute(store.path + ".tmp")
	var failed: Dictionary = session.checkpoint_battle(loaded.state, index, 123)
	check(not failed.saved and session.battle_marker.is_empty(), "Failed checkpoint does not activate battle entry")
	DirAccess.remove_absolute(store.path + ".tmp")
	loaded.state.navigation.checkpoint_position([12, 0, 13])
	var retried: Dictionary = session.checkpoint_battle(loaded.state, index, failed.seed, failed.environment)
	check(retried.saved and retried.environment == failed.environment, "Retry reuses entry selection rather than moving it")
	var corrupt: Dictionary = session.battle_marker.duplicate(true)
	corrupt.environment.encounter_index = index + 1
	check(not store.save_data(session.battle_checkpoint, corrupt), "Mismatched marker identity rejected")
	check(store.load_run().battle.environment == retried.environment, "Rejected marker preserves last valid slot")
	store.clear_run()
	print("Environmental entry/resume: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
