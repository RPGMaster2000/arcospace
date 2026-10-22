extends SceneTree
# Invoked by the fresh-process regression, never by the ordinary discovery loop.
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const EXPECTED = "user://test_process_expected.json"
var store = Save.new()
func _initialize() -> void:
	create_timer(12).timeout.connect(func(): push_error("Fresh-process phase timed out"); quit(1))
	store.path = "user://test_process_run.json"
	call_deferred("run")
func host(data: Dictionary = {}) -> Node:
	var scene = load("res://scenes/expedition.tscn").instantiate()
	scene.selected_ship = 2
	scene.save_store = store
	scene.resume_data = data
	root.add_child(scene)
	current_scene = scene
	return scene
func opening(board: Node) -> Dictionary:
	var cards: Array = []
	for hand in [board.hand, board.enemy_hand]:
		var ids: Array = []
		for card in hand.cards: ids.append(card.identity_key())
		cards.append(ids)
	return {"player": board.ship_snapshot("player"), "enemy": board.ship_snapshot("enemy"), "cards": cards,
		"modifier": board.modifier.kind, "round_event": board.modifier.next_round,
		"random": [str(board.modifier.rng.state), str(board.hand.rng.state), str(board.enemy_hand.rng.state), str(board.enemy_ai.rng.state), str(board.ftl.rng.state)]}
func run() -> void:
	var mode: String = OS.get_cmdline_user_args()[0]
	match mode:
		"write":
			store.clear_run()
			var scene = host()
			scene.state.salvage = 200
			scene.state.hull = scene.state.ship().hull_capacity - 5
			scene.state.pending_choice = "card"
			scene.state.card_offers = scene.state.random_card_offers()
			scene.state.progress_committed.emit()
			var file = FileAccess.open(EXPECTED, FileAccess.WRITE)
			file.store_string(JSON.stringify(Save.encode(scene.state))); file.close()
			assert(not store.load_run().is_empty())
		"enter":
			var data: Dictionary = store.load_run()
			assert(not data.is_empty())
			assert(JSON.stringify(Save.encode(data.state)) == FileAccess.get_file_as_string(EXPECTED))
			var scene = host(data)
			assert(scene.state.pending_choice == "card")
			assert(scene.state.choose_card(0))
			var card: Resource = scene.state.acquired_cards[0]
			scene.state.pending_choice = "upgrade"
			scene.state.upgrades_remaining = 1
			assert(scene.state.choose_upgrade(card.identity_key()))
			scene.state.add_modifiers({"energy": 3, "shields": -2})
			scene.state.encounters[0] = {"kind": "battle", "enemy_data": Ships.ENEMIES[0], "title": "Marauder", "modifier": 1, "completed": false, "charge_awarded": false}
			scene.start_battle(0, 998877)
			scene.battle.enemy_timer.stop()
			var file = FileAccess.open(EXPECTED, FileAccess.WRITE)
			file.store_string(JSON.stringify(opening(scene.battle))); file.flush(); file.close()
			scene.battle.player_hull = 1
			scene.battle.player_energy = 0
			# Android-like process death: no orderly scene exit or close notification.
			print("Checkpoint ready for forced termination")
			OS.kill(OS.get_process_id())
			return
		"resume":
			var scene = host(store.load_run())
			scene.battle.enemy_timer.stop()
			assert(JSON.stringify(opening(scene.battle)) == FileAccess.get_file_as_string(EXPECTED))
			assert(scene.state.salvage == 200 and scene.state.battles_won == 0)
			scene.battle.enemy_hull = 0
			scene.battle._check_winner()
			var completed: Dictionary = store.load_run()
			assert(completed.battle.is_empty() and completed.state.encounters[0].completed)
			assert(not completed.state.can_visit(0))
			assert(completed.state.battles_won == 1)
			scene.state.hull = 0
			scene.state.progress_committed.emit()
			assert(store.load_run().is_empty())
		"ended":
			assert(store.load_run().is_empty())
			var menu = load("res://scenes/battle_setup.tscn").instantiate()
			menu.save_store = store
			root.add_child(menu)
			assert(menu.get_node("Start").text == "New Expedition")
			DirAccess.remove_absolute(EXPECTED)
	print("Fresh-process phase passed: ", mode)
	quit()
