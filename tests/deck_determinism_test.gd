extends SceneTree
# Generation deliberately changed from six encounters/charge to profiles/objectives.
# Preserve the historical fixture, verify its card ledgers migrate unchanged, then
# compare every checkpoint of two independently executed current seeded runs.
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Result = preload("res://scripts/combat/battle_result.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func mark(state: Resource, trace: Array, label: String) -> void:
	var data: Dictionary = Save.encode(state)
	check(Save.new().decode(data, state.rules) != null, "Checkpoint is independently resumable: " + label)
	trace.append({"step": label, "hash": JSON.stringify(data).sha256_text()})

func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/deck_ownership_baseline.json"))
	check(not baseline.trace.is_empty(), "Historical pre-refactor trace remains available")
	for kind in ["replacement", "upgrade"]:
		var historical: Dictionary = baseline.saves[kind]
		var restored: Resource = Save.new().decode(historical)
		check(restored != null, "Historical ownership fixture migrates: " + kind)
		if restored == null: continue
		var migrated: Dictionary = JSON.parse_string(JSON.stringify(Save.encode(restored)))
		for field in ["acquired", "removed", "upgrades", "upgraded_this_event", "offers", "pending_card", "pending_choice", "upgrades_remaining", "rng"]:
			check(migrated[field] == historical[field], "Historical ledger/RNG unchanged: %s/%s" % [kind, field])
	var checkpoints: int = 0
	for ship_index in range(6):
		for seed_value in [43, 65537, 98981]:
			var first: Array = seeded_trace(ship_index, seed_value)
			var second: Array = seeded_trace(ship_index, seed_value)
			check(first.size() == second.size(), "Same checkpoint count for repeated seed")
			for index in range(mini(first.size(), second.size())):
				check(first[index] == second[index], "Seeded deck/state checkpoint differs: %s/%s/%s" % [ship_index, seed_value, index])
			checkpoints += first.size()
	print("Deck determinism: %d checks, %d checkpoints, %d failures" % [checks, checkpoints, failures])
	quit(1 if failures else 0)

func seeded_trace(ship_index: int, seed_value: int) -> Array:
	var trace: Array = []
	var rules: Resource = Rules.duplicate()
	rules.log_rolls = false
	var state = State.new()
	state.start(ship_index, rules, seed_value)
	mark(state, trace, "start/%s/%s" % [ship_index, seed_value])
	for system in range(1, 7):
		state.salvage = 500
		# A second pass resolves an access route that precedes its prerequisite in map order.
		for pass_index in range(2):
			for index in range(state.encounters.size()):
				if state.encounters[index].completed or state.objective_locked(index): continue
				if state.encounters[index].kind == "poi":
					state.resolve_approach(index, 0)
				else:
					var setup = state.prepare_battle(index)
					trace.append({"setup_hash": JSON.stringify({"pool": ids(setup.player_cards), "weights": setup.identity_weights}).sha256_text()})
					var result = Result.new()
					result.encounter_index = index
					result.system_number = state.system_number
					result.winner = "player"
					result.player_hull = state.ship().hull_capacity
					result.salvage = state.salvage + 10
					result.battles_won = state.battles_won + 1
					state.record_battle(result)
					var rewarded: Dictionary = Save.encode(state)
					state.record_battle(result)
					check(Save.encode(state) == rewarded, "Duplicate combat result cannot reward twice")
					state.active_battle = -1
				mark(state, trace, "resolved/%s" % index)
				settle(state)
		if not state.service.is_empty():
			for slot in [2, 3]:
				state.purchase_service(slot, state.service_revision)
				mark(state, trace, "service/%s" % slot)
				settle(state)
		state.hull = state.ship().hull_capacity
		state.active_battle = -1
		check(state.generate_system(), "Completed system retains a viable FTL route")
		mark(state, trace, "jump")
	var destinations: Array[int] = []
	for index in state.encounters.size():
		if state.encounters[index].kind == "poi" and not state.objective_locked(index): destinations.append(index)
	state.arrive_destination(destinations[0])
	check(state.begin_travel(destinations[1], 0.0), "Forced eligible Chasedown begins")
	check(state.choose_chasedown_response(3), "Chasedown response accepted")
	state.prepare_battle(state.chasedown_index)
	var interception = Result.new()
	interception.encounter_index = state.chasedown_index
	interception.system_number = state.system_number
	interception.winner = "player"
	interception.player_hull = state.hull
	interception.salvage = state.salvage + 10
	interception.battles_won = state.battles_won + 1
	state.record_battle(interception)
	state.record_battle(interception)
	state.active_battle = -1
	mark(state, trace, "chasedown")
	settle(state)
	state.arrive_destination(destinations[1])
	while state.player_pool().size() < state.deck_limit():
		state.pending_choice = "card"
		state.card_offers = state.random_card_offers()
		state.choose_card(0)
	state.pending_choice = "card"
	state.card_offers = state.random_card_offers(2)
	state.choose_card(0)
	mark(state, trace, "pending replacement")
	state = Save.new().decode(Save.encode(state), rules)
	check(state != null, "Pending replacement reloads")
	if state == null: return trace
	check(state.replace_card(state.player_pool()[0].identity_key()), "Resumed replacement commits")
	mark(state, trace, "replacement resumed")
	state.start_upgrade_event(2)
	state.choose_upgrade(state.upgrade_candidates()[0].identity_key())
	mark(state, trace, "partial upgrade")
	state = Save.new().decode(Save.encode(state), rules)
	check(state != null, "Partial upgrade reloads")
	if state == null: return trace
	settle(state)
	mark(state, trace, "upgrade resumed")
	return trace

func ids(cards: Array[Resource]) -> Array:
	var result: Array = []
	for card in cards: result.append([card.identity_key(), card.upgrade_level])
	return result

func settle(state: Resource) -> void:
	while not state.pending_choice.is_empty():
		match state.pending_choice:
			"card": state.choose_card(0)
			"replace": state.decline_card()
			"upgrade": state.choose_upgrade(state.upgrade_candidates()[0].identity_key())
			"resource": state.choose_attribute("energy")
			"production": state.choose_attribute("reactor")
