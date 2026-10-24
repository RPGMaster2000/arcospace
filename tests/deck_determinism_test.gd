extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Result = preload("res://scripts/combat/battle_result.gd")
var trace: Array = []
var fixtures: Dictionary = {}
func mark(state: Resource, label: String) -> void:
	trace.append({"step": label, "hash": JSON.stringify(Save.encode(state)).sha256_text()})
func _initialize() -> void:
	for ship_index in range(6):
		for seed_value in [43, 65537, 98981]:
			var rules: Resource = Rules.duplicate()
			rules.log_rolls = false
			var state = State.new()
			state.start(ship_index, rules, seed_value)
			mark(state, "start/%s/%s" % [ship_index, seed_value])
			for system in range(1, 7):
				state.salvage = 500
				for index in range(state.encounters.size()):
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
						state.record_battle(result)
					mark(state, "resolved/%s" % index)
					settle(state)
				if not state.service.is_empty():
					for slot in [2, 3]:
						state.purchase_service(slot, state.service_revision)
						mark(state, "service/%s" % slot)
						settle(state)
				state.hull = state.ship().hull_capacity
				state.active_battle = -1
				state.generate_system()
				mark(state, "jump")
			state.encounters[0] = {"kind": "poi", "poi": rules.pois[0], "title": rules.pois[0].title, "completed": false, "charge_awarded": false}
			state.encounters[1] = {"kind": "poi", "poi": rules.pois[1], "title": rules.pois[1].title, "completed": false, "charge_awarded": false}
			state.active_battle = -1
			state.arrive_destination(0)
			state.try_chasedown(1, 0.0)
			state.choose_chasedown_response(3)
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
			mark(state, "chasedown")
			settle(state)
			state.active_battle = -1
			state.arrive_destination(1)
			# Fill then replace, snapshot the existing save format at both pending boundaries.
			while state.player_pool().size() < state.deck_limit():
				state.pending_choice = "card"
				state.card_offers = state.random_card_offers()
				state.choose_card(0)
			state.pending_choice = "card"
			state.card_offers = state.random_card_offers(2)
			state.choose_card(0)
			if ship_index == 0 and seed_value == 43: fixtures.replacement = Save.encode(state)
			mark(state, "pending replacement")
			state = Save.new().decode(Save.encode(state), rules)
			state.replace_card(state.player_pool()[0].identity_key())
			mark(state, "replacement resumed")
			state.start_upgrade_event(2)
			state.choose_upgrade(state.upgrade_candidates()[0].identity_key())
			if ship_index == 0 and seed_value == 43: fixtures.upgrade = Save.encode(state)
			mark(state, "partial upgrade")
			state = Save.new().decode(Save.encode(state), rules)
			settle(state)
			mark(state, "upgrade resumed")
	var output: Dictionary = {"baseline": "a25b58a06d3cd3473d54191bff5ae9e56f4024b8", "trace": trace, "saves": fixtures}
	if "--write-baseline" in OS.get_cmdline_user_args():
		var file = FileAccess.open("res://tests/deck_ownership_baseline.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(output, "\t"))
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/deck_ownership_baseline.json"))
		# Normalize JSON numeric types before structural comparison (integers load as floats).
		var actual: Dictionary = JSON.parse_string(JSON.stringify(output))
		if JSON.stringify(actual) != JSON.stringify(expected):
			for index in range(mini(trace.size(), expected.trace.size())):
				if JSON.stringify(actual.trace[index]) != JSON.stringify(expected.trace[index]):
					push_error("First differing deck checkpoint %s: %s" % [index, trace[index]])
					break
			push_error("Seeded deck trace differs from pre-refactor baseline")
			quit(1)
			return
	print("Deck baseline trace: %s checkpoints matched" % trace.size())
	quit()
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
