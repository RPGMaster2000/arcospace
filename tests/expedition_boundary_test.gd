extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Result = preload("res://scripts/combat/battle_result.gd")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var state = State.new()
	state.start(0, Rules, 17)
	state.encounters[0] = {"kind": "battle", "enemy": 0, "modifier": 2, "completed": false}
	state.add_modifiers({"energy": 3})
	var setup = state.prepare_battle(0)
	check(setup.player_state.energy == state.ship().energy + 3 and state.pending_bonuses.is_empty(), "Data setup consumes bonuses at entry")
	check(setup.enemy_state.hull == setup.enemy_profile.hull_capacity and setup.modifier == 2, "Enemy and modifier are explicit setup data")
	var data = Result.new()
	data.encounter_index = setup.encounter_index
	data.system_number = setup.system_number
	data.winner = "player"
	data.player_hull = 23
	data.salvage = 12
	data.battles_won = 1
	data.earned_tactical = true
	state.record_battle(data)
	var charge: int = state.pressure
	var bonuses: Dictionary = state.pending_bonuses.duplicate()
	data.salvage = 999
	state.record_battle(data)
	check(state.salvage == 12 and state.hull == 23 and state.pressure == charge and state.pending_bonuses == bonuses, "Node-free result is applied once, including currency and FTL")
	var replay = Result.new()
	replay.encounter_index = setup.encounter_index
	replay.system_number = setup.system_number
	replay.winner = "player"
	replay.salvage = 999
	state.record_battle(replay)
	check(state.salvage == 12 and state.pressure == charge, "A fresh result object cannot repeat encounter rewards")
	var stale = Result.new()
	stale.system_number = state.system_number - 1
	stale.encounter_index = 0
	stale.salvage = 500
	state.record_battle(stale)
	check(state.salvage == 12, "Stale system cannot overwrite persistent values")
	# Live adapter owns hand synchronization; freeing it must disconnect the listener.
	state = State.new()
	state.start(0, Rules, 18)
	state.encounters[0] = {"kind": "battle", "enemy_data": preload("res://scripts/ships/ship_library.gd").ENEMIES[0], "modifier": 0, "completed": false}
	var board = load("res://scenes/board.tscn").instantiate()
	board.expedition = state
	Adapter.configure(board, state.prepare_battle(0))
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	var before: Dictionary = board.ship_snapshot("player")
	Adapter.apply_setup(board, board.battle_setup)
	check(board.ship_snapshot("player") == before, "Reapplying setup cannot reset income or consume bonuses")
	board.battle_setup.player_state.hull = 1
	check(board.player_hull == before.hull, "Setup data cannot mutate live state after transfer")
	var card: Resource = state.player_pool()[0]
	board.hand.cards[0] = card
	state.pending_choice = "upgrade"
	state.upgrades_remaining = 1
	check(state.choose_upgrade(card.identity_key()), "Upgrade is accepted in expedition ledger")
	check(board.hand.cards[0].upgrade_level == 1, "Signal updates live held copies through the adapter")
	var owned: Dictionary = {}
	for item in state.player_pool(): owned[item.identity_key()] = true
	for item in state.shared_pool():
		if not owned.has(item.identity_key()):
			state.pending_card = item
			break
	state.pending_choice = "replace"
	check(state.replace_card(card.identity_key()), "Ledger removes the selected identity")
	for held in board.hand.cards:
		check(held == null or held.identity_key() != card.identity_key(), "Removed identity leaves the live hand")
	check(board.hand.card_pool == state.player_pool() and board.hand.identity_weights == state.acquired_draw_weights(), "Live deck and weights stay synchronized")
	board.free()
	check(state.deck_changed.get_connections().is_empty(), "Expedition retains no dead hand/Board listener")
	print("Expedition boundary: %d failures" % failures)
	quit(1 if failures else 0)
