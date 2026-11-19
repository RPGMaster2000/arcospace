extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Actions = preload("res://scripts/combat/progression_actions.gd")
const Execution = preload("res://scripts/combat/combat_execution.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
const Checkpoint = preload("res://scripts/combat/progression_checkpoint.gd")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const Hand = preload("res://scripts/cards/card_hand.gd")
const Board = preload("res://scenes/board_3d.tscn")
var failures := 0


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "0")
	call_deferred("run")


func card(number: int) -> Resource:
	return Cards.CARDS[number - 1]


func funded() -> Dictionary:
	var result := Ship.new().snapshot()
	for key in Actions.PAYMENTS: result[key] = 50
	return result


func card_checks() -> void:
	for number in range(81, 89):
		var definition := card(number)
		var actor := funded()
		actor[definition.family] = definition.cost - 1
		var before := actor.duplicate()
		check(Execution.resolve(definition, false, actor, funded()) == null and actor == before,
			"Rejected payment is atomic for card %d" % number)
	var actor := funded()
	actor.hull = 10
	actor.shields = 5
	check(not Execution.can_play(card(81), false, actor), "Refit needs six Shields")
	actor.shields = 6
	Execution.resolve(card(81), false, actor, funded())
	check(actor.hull == 24 and actor.shields == 0, "Refit exchanges Shields for Hull")
	for shields in [0, 7, 9]:
		actor = funded()
		var target := funded()
		target.shields = shields
		Execution.resolve(card(82), false, actor, target)
		check(actor.energy == (42 if shields == 7 else 36), "Only a real shield break pays Siphon")
	actor = funded()
	var target := funded()
	target.crew = 2
	Execution.resolve(card(83), false, actor, target)
	check(actor.crew == 38 and target.crew == 0, "Boarding Raid only gains Crew taken")
	actor = funded()
	Execution.resolve(card(84), false, actor, funded())
	check(actor.shields == 22 and actor.energy == 56, "Fortified Reactor grants both effects")
	actor = funded()
	target = funded()
	Execution.resolve(card(85), false, actor, target)
	check(target.shields == 0 and target.hull == 15, "Siege Lance uses shield-first damage")
	actor = funded()
	target = funded()
	target.shields = 16
	Execution.resolve(card(86), false, actor, target)
	check(actor.materials == 62, "Salvage Blitz caps actual Shield damage at twelve")
	actor = funded()
	actor.hull = 21
	Execution.resolve(card(87), false, actor, funded())
	check(actor.shields == 38 and actor.hull == 27, "Fortress grants Shields and repairs Hull")
	actor = funded()
	actor.hull = 8
	check(not Execution.can_play(card(88), false, actor), "Gambit cannot sacrifice lethal Hull")
	actor.hull = 9
	Execution.resolve(card(88), false, actor, funded())
	check(actor.hull == 1 and actor.materials == 62 and actor.crew == 62, "Gambit leaves one Hull")
	for action in range(2):
		for payment in Actions.PAYMENTS:
			actor = funded()
			target = funded()
			actor[payment] = 29
			check(not Actions.overdrive(action, payment, actor, target) and actor[payment] == 29,
				"Invalid Overdrive never pays")
			actor[payment] = 30
			check(Actions.overdrive(action, payment, actor, target) and actor[payment] == 0,
				"Both Overdrive actions accept all three resources")
			check(actor.shields == (35 if action == 0 else 10), "Overdrive Shield delta")
			check(target.hull == (30 if action == 0 else 16), "Overdrive damage goes through Shields")
	check(Actions.interrupt_chance(6, 30) > Actions.interrupt_chance(3, 30)
		and is_equal_approx(Actions.interrupt_chance(25, 30), 0.85), "Interruption scales with actual Hull loss")


func high_tier_draw_checks() -> void:
	var hand := Hand.new()
	hand.card_pool.assign([card(1), card(85)])
	hand.tier_three_chance = 1.0
	hand.current_round = hand.tier_two_locked_turns
	check(hand.draw_card() == card(1), "Tier 3 respects the opening-round gate")
	hand.current_round += 1
	check(hand.draw_card() == card(85), "Owned Tier 3 cards are drawable after the opening rounds")
	hand.free()


func make_run(mode: String) -> Resource:
	var rules := Rules.duplicate(true)
	rules.game_mode = mode
	rules.log_rolls = false
	var state := State.new()
	state.start(0, rules, 717)
	return state


func reward_checks() -> void:
	var state := make_run("exploration")
	var normal := preload("res://ships/enemy/sentinel.tres")
	var index: int = state.encounters.find_custom(func(e): return e.kind == "battle" and not e.get("mandatory_boss", false))
	state.active_battle = index
	state.encounters[index].enemy_data = normal
	var result := preload("res://scripts/combat/battle_result.gd").new()
	result.result_id = 4242
	result.encounter_index = index
	result.system_number = state.system_number
	result.winner = "player"
	result.player_hull = state.hull
	result.battles_won = 1
	check(state.record_battle(result) and not state.record_battle(result), "Victory creates reward once")
	check(state.pending_choice == "battle_reward" and state.card_offers.size() == 5, "Five victory offers")
	check(state.card_offers.any(func(c): return c.tier == 3), "Tier 3 appears in victory offers")
	var restored := Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))), state.rules)
	check(restored != null and restored.pending_choice == "battle_reward", "Reward choice survives JSON save")
	if restored == null: return
	check(restored.choose_battle_reward(true) and not restored.choose_battle_reward(false), "Branches are exclusive")
	check(restored.choose_card(0) and not restored.choose_card(0), "Only one card is granted")
	check(restored.acquired_cards.size() == 1 and restored.upgrades_remaining == 0, "Card branch does not upgrade")
	check(state.choose_battle_reward(false) and state.pending_choice == "upgrade"
		and state.acquired_cards.is_empty(), "Upgrade branch keeps the existing upgrade workflow")
	check(state.deck_limit() == 34, "Capacity is exactly 34")
	while state.player_pool().size() < 36:
		var owned: Array[Resource] = state.acquired_cards
		owned.append(state.available_reward_cards()[0])
		state.acquired_cards = owned
	var legacy := Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))), state.rules)
	check(legacy != null and legacy.player_pool().size() == 36, "Legacy deck loads without deleting cards")
	if legacy != null:
		legacy.pending_choice = ""
		var key: String = legacy.acquired_cards[0].identity_key()
		check(legacy.trim_deck(key) and not legacy.trim_deck(key) and legacy.player_pool().size() == 35,
			"Only explicit trimming removes a legacy identity")


func shop_checks() -> void:
	var state := make_run("exploration")
	for attempt in range(30):
		if not state.service.is_empty(): break
		for entry in state.encounters:
			if entry.get("mandatory_boss", false): entry.completed = true
		state.ftl_access = true
		state.generate_system()
	state.salvage = 100
	var revision: int = state.service_revision
	var pool: Array[Resource] = state.service_card_offers(2)
	check(pool.size() == 6 and pool == state.service_card_offers(2), "Six stable unpaid shop offers")
	check(state.salvage == 100 and not state.purchase_service(2, revision), "Browsing and missing selection are free")
	var cost: int = state.service_cost(2)
	check(state.purchase_service(2, revision, 0, 0) and state.salvage == 100 - cost, "Selected card costs Salvage once")
	check(not state.purchase_service(2, revision, 0, 0) and state.acquired_cards == [pool[0]], "No duplicate purchase")


func make_board(state: Resource, saved: Dictionary = {}) -> Node:
	state.defense.contact = 0
	var setup = state.prepare_battle(0)
	setup.battle_seed = 707
	setup.modifier = 0
	var board := Board.instantiate()
	board.expedition = state
	Adapter.configure(board, setup)
	board.resume_combat = saved
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	return board


func combat_checks() -> void:
	var state := make_run("defense")
	state.system_number = 2
	state.battles_won = 4
	var board := make_board(state)
	await process_frame
	board.turn_number = 2
	board.current_actor = "enemy"
	board.player_hull = 30
	board.player_shields = 15
	var original_hand: Array = board.enemy_hand.cards.duplicate()
	await board._on_enemy_timeout()
	check(board.progression_actions.beam == Actions.Beam.CHARGING and board.current_actor == "player"
		and board.player_hull == 30 and board.enemy_hand.cards == original_hand, "Charge replaces enemy card play")
	board.player_materials = 35
	board.refresh_display()
	board.hud.player_panel.handle.pressed.emit()
	var menu: PopupMenu = board.overdrive_button.get_popup()
	check(board.overdrive_button.is_visible_in_tree() and not menu.is_item_disabled(0),
		"Opening the player drawer exposes the available Overdrive")
	check(board.hud._system.text.contains("Pressure") and board.hud._system.text.contains("Hostile ships")
		and board.hud._beam.text.contains("25 damage next enemy turn"),
		"Player drawer shows defense context and enemy drawer tracks the charged beam")
	menu.id_pressed.emit(menu.get_item_id(0))
	check(board.player_materials == 5 and not board.hud.player_panel.open,
		"Overdrive menu pays for the existing ability and closes the drawer")
	check(not board.activate_overdrive(0, "materials"),
		"Only one Overdrive use per player turn")
	var persistence := Persistence.new()
	persistence.store.path = "user://ten_battle_progression_checkpoint.json"
	check(persistence.checkpoint_battle(state, 0, 707).saved, "Save a battle marker")
	check(persistence.save_progress(state, board), "Save & Quit writes settled prototype combat")
	var loaded := persistence.store.load_run()
	check(not loaded.is_empty(), "Continue reads the saved battle")
	var snapshot: Dictionary = loaded.get("battle", {}).get("combat", {})
	persistence.store.clear_run()
	check(Checkpoint.valid(snapshot), "Settled prototype state validates after JSON conversion")
	if not Checkpoint.valid(snapshot):
		board.queue_free()
		return
	board.queue_free()
	await process_frame
	var second := make_run("defense")
	second.system_number = 2
	second.battles_won = 4
	var resumed := make_board(second, snapshot)
	check(resumed.progression_actions.beam == Actions.Beam.CHARGING and resumed.progression_actions.overdrive_used
		and resumed.player_materials == 5, "Resume retains charge and paid Overdrive")
	resumed.player_shields = 10
	resumed.current_actor = "enemy"
	await resumed._on_enemy_timeout()
	check(resumed.player_hull == 15 and resumed.player_shields == 0 and resumed.current_actor == "player",
		"Charged beam fires on following enemy turn")
	check(resumed.enemy_hand.cards == original_hand and not resumed.progression_actions.overdrive_used,
		"No enemy card consumed; next player turn resets Overdrive")
	resumed.progression_actions.beam = Actions.Beam.CHARGING
	resumed.progression_actions.charge_hull = 30
	var rng_before: int = resumed.progression_actions.rng.state
	resumed._apply_hull_report({"target": 15}, "player", false, false)
	check(resumed.progression_actions.beam == Actions.Beam.CHARGING
		and resumed.progression_actions.rng.state == rng_before, "Environmental damage does not roll interruption")
	for seed_value in range(100):
		resumed.progression_actions.rng.seed = seed_value
		resumed._interrupt_charged_beam(30)
		if resumed.progression_actions.beam == Actions.Beam.DISRUPTED: break
	check(resumed.progression_actions.beam == Actions.Beam.DISRUPTED, "Actual Hull damage can disrupt")
	var reserves: int = resumed.enemy_energy
	await resumed._begin_turn("enemy")
	check(resumed.current_actor == "player" and resumed.enemy_energy == reserves
		and resumed.progression_actions.beam == Actions.Beam.SPENT, "Interrupted enemy loses its full next turn")
	resumed.queue_free()
	await process_frame


func run() -> void:
	card_checks()
	high_tier_draw_checks()
	reward_checks()
	shop_checks()
	await combat_checks()
	print("Ten-battle progression: %d failures" % failures)
	quit(int(failures > 0))
