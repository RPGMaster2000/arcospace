extends SceneTree
const Save = preload("res://scripts/persistence/expedition_save.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Cards = preload("res://scripts/cards/card_library.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func new_host(store: RefCounted, data: Dictionary = {}) -> Node:
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.save_store = store
	host.resume_data = data
	root.add_child(host)
	current_scene = host
	return host
func opening(board: Node) -> Dictionary:
	var hand: Array = []
	for card in board.hand.cards: hand.append(card.identity_key())
	var enemy: Array = []
	for card in board.enemy_hand.cards: enemy.append(card.identity_key())
	return {"player": board.ship_snapshot("player"), "enemy": board.ship_snapshot("enemy"),
		"hand": hand, "enemy_hand": enemy, "modifier": board.modifier.kind,
		"modifier_rng": str(board.modifier.rng.state), "next_round": board.modifier.next_round,
		"ai_rng": str(board.enemy_ai.rng.state), "emp_rng": str(board.ftl.rng.state),
		"hand_rng": str(board.hand.rng.state), "enemy_hand_rng": str(board.enemy_hand.rng.state)}
func run() -> void:
	var store = Save.new()
	store.path = "user://test_resume.json"
	store.clear_run()
	var host = new_host(store)
	check(not store.load_run().is_empty(), "Fresh expedition autosaves")
	host._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not quit_on_go_back and host.settings_button.menu.shade.visible, "Android Back opens Resume/Save and Quit rather than exiting")
	host.settings_button.menu.dismiss()
	host.state.salvage = 99
	host.state.hull = 23
	host.state.add_modifiers({"energy": 5, "shields": -3})
	host.state.encounters[0] = {"kind": "battle", "enemy_data": preload("res://scripts/ships/ship_library.gd").ENEMIES[0], "title": "Test enemy", "modifier": 4, "completed": false, "charge_awarded": false}
	host._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(store.load_run().state.hull == 23, "Android-style suspension saves a complete checkpoint")
	host.start_battle(0, 778899)
	check(host.battle != null, "Durable entry starts battle")
	host.battle.enemy_timer.stop()
	var settings = host.battle.settings_button.menu
	settings.present()
	settings.main_menu_button.pressed.emit()
	var notices: Array[Node] = settings.find_children("*", "ConfirmationDialog", false, false)
	check(not notices.is_empty() and notices[0].dialog_text == "Your current battle will restart when you continue.", "Battle Save and Quit explains restart policy")
	for notice in notices: notice.queue_free()
	settings.dismiss()
	var expected: Dictionary = opening(host.battle)
	var checkpoint: Dictionary = store.load_run()
	check(checkpoint.battle.index == 0 and checkpoint.state.pending_bonuses.energy == 5, "Entry checkpoint retains exact unconsumed bonuses")
	host.battle.player_hull = 1
	host.battle.salvage = 0
	check(host._save_and_quit(), "Save and Quit succeeds")
	await process_frame
	var menu = current_scene
	menu.showcase.skip_cinematics = true
	menu.continue_fade_duration = 0.001
	menu.white_fade_duration = 0.001
	menu.map_reveal_duration = 0.001
	menu.showcase._stop_tween()
	menu.showcase._finish_intro()
	menu.showcase.logo.modulate.a = 0.0
	menu.showcase.phase = menu.showcase.Phase.SHIP_SELECTION
	menu._selection_ready()
	await process_frame
	check(menu.scene_file_path.ends_with("battle_setup.tscn") and menu.start_button.text == "CONTINUE EXPEDITION", "Main menu promotes Continue")
	for dimensions in [Vector2i(1280, 720), Vector2i(686, 384)]:
		root.size = dimensions
		menu._layout()
		await process_frame
		await process_frame
		check(not menu.begin_button.get_global_rect().intersects(menu.start_button.get_global_rect()), "Continue and New Expedition fit both landscape sizes")
	root.size = Vector2i(1280, 720)
	menu._layout()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://continue-expedition.png")
	var before: String = FileAccess.get_file_as_string(store.path)
	menu._request_new()
	check(menu.overwrite_confirmation.visible and FileAccess.get_file_as_string(store.path) == before, "New run asks before overwriting")
	menu.overwrite_confirmation.hide()
	DirAccess.make_dir_absolute(store.path + ".tmp")
	menu.overwrite_confirmation.confirmed.emit()
	check(current_scene == menu and FileAccess.get_file_as_string(store.path) == before, "Failed new-run replacement retains the original expedition")
	DirAccess.remove_absolute(store.path + ".tmp")
	menu.save_notice.hide()
	menu._continue_expedition()
	for frame in range(8): await process_frame
	host = current_scene
	host.battle.enemy_timer.stop()
	check(opening(host.battle) == expected, "Same enemy modifier stats opening decks and RNG after interruption")
	check(host.state.salvage == 99 and host.state.battles_won == 0, "No interrupted-battle gains or losses persist")
	# Failure keeps the existing scene and live battle intact.
	DirAccess.make_dir_absolute(store.path + ".tmp")
	var live: Node = host.battle
	check(not host._save_and_quit() and current_scene == host and host.battle == live, "Write failure preserves the active session")
	DirAccess.remove_absolute(store.path + ".tmp")
	host.save_error.hide()
	# Quitting with already-determined lethal damage still restarts the encounter.
	host.battle.modifier.configure(0)
	host.battle.enemy_shields = 3
	host.battle.player_materials = 100
	host.battle.damage_timeline.set_process(false)
	var lethal = preload("res://scripts/cards/card_data.gd").new()
	lethal.family = "materials"
	lethal.cost = 0
	lethal.effects = {"damage": 1000}
	host.battle._resolve_card("player", 0, false, lethal)
	check(not host.battle.damage_timeline.pending.is_empty(), "Lethal Hull is waiting for its impact cue")
	check(host._save_and_quit(), "Pending impact can safely quit")
	await process_frame
	check(not store.load_run().battle.is_empty() and store.load_run().state.battles_won == 0, "Scene cleanup cannot commit phantom rewards")
	current_scene.queue_free()
	await process_frame
	host = new_host(store, store.load_run())
	host.battle.get_node("BattleEffects").enabled = false
	host.battle.enemy_timer.stop()
	host.battle.player_reactor = 0
	host.battle.player_quarters = 0
	host.battle.systems_failure.remaining.player = 0
	host.battle._check_winner()
	check(host.state.run_ended and host.state.hull > 0 and store.load_run().is_empty(), "Systems Failure is permanent defeat despite positive Hull")
	host.queue_free()
	await process_frame
	# Failed chase rolls and pending travel are not rerolled on load.
	var state = State.new()
	state.start(0, Rules, 8811)
	state.encounters[0] = {"kind": "poi", "poi": Rules.pois[0], "title": Rules.pois[0].title, "completed": false}
	state.encounters[1] = state.encounters[0].duplicate()
	state.arrive_destination(0)
	state.begin_travel(1, 1.0)
	check(store.save_run(state), "Navigation decision saves")
	var resumed = store.load_run().state
	var rng: int = resumed.chasedown_rng.state
	check(resumed.travel_destination == 1 and not resumed.begin_travel(1, 0.0) and resumed.chasedown_rng.state == rng, "Committed failed chase cannot be rerolled")
	resumed.arrive_destination(1)
	check(resumed.travel_destination == -1, "Arrival clears committed travel")
	store.clear_run()
	print("Expedition resume: %d failures" % failures)
	quit(1 if failures else 0)
