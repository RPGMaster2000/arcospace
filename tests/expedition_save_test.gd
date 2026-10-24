extends SceneTree
const Save = preload("res://scripts/persistence/expedition_save.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Ships = preload("res://scripts/ships/ship_library.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var store = Save.new()
	store.path = "user://test_expedition_save.json"
	store.clear_run()
	check(store.load_run().is_empty() and store.error.is_empty(), "Missing save is normal")
	for index in range(Ships.PLAYERS.size()):
		var state = State.new()
		state.start(index, Rules, 12345 + index)
		var data: Dictionary = Save.encode(state)
		var restored = store.decode(data)
		check(restored != null, "All six player runs decode")
		if restored != null:
			check(JSON.stringify(Save.encode(restored)) == JSON.stringify(data), "Exact authoritative state round trip")
		check(store.save_run(state), "New run writes: " + store.error)
		var loaded: Dictionary = store.load_run()
		check(not loaded.is_empty(), "Written run loads: " + store.error)
	var state = State.new()
	state.start(0, Rules, 9876)
	state.salvage = 500
	state.hull = 19
	state.production_upgrades = {"reactor": 2}
	state.pending_bonuses = {"energy": 3}
	state.pending_penalties = {"shields": -4}
	state.rng.seed = 9223372036854775807
	state.rng.randf()
	var offers: Array[Resource] = state.random_card_offers()
	state.pending_choice = "card"
	state.card_offers = offers
	check(store.save_run(state), "Pending offers save")
	var restored = store.load_run().get("state")
	check(restored != null and restored.pending_choice == "card" and restored.card_offers == offers, "Choices and exact offers survive")
	check(restored.rng.state == state.rng.state and restored.rng.randf() == state.rng.randf(), "64-bit RNG survives JSON without precision loss")
	check(restored.choose_card(0), "Loaded choice can be acquired")
	var acquired: Resource = restored.acquired_cards[0]
	restored.pending_choice = "upgrade"
	restored.upgrades_remaining = 2
	check(restored.choose_upgrade(acquired.identity_key()), "Upgrade commits")
	var removal: String = restored.ship().starting_cards[0].identity_key()
	restored.removed_starting_cards = restored.removed_starting_cards.merged({removal: true}, true)
	check(store.save_run(restored), "Deck ledger saves")
	var deck = store.load_run().state
	check(deck.upgraded_cards[acquired.identity_key()].upgrade_level == 1 and deck.upgrades_remaining == 1, "Upgrade level and remaining selections survive")
	check(deck.removed_starting_cards.has(removal) and deck.player_pool().size() == restored.player_pool().size(), "Removed cards remain absent")
	check(deck.hull == 19 and deck.salvage == 500 and deck.production("reactor") == state.ship().reactor + 2, "Hull currency and production survive")
	# Durable transaction revision prevents reusing an old repair/purchase confirmation.
	deck.pending_choice = ""
	deck.field_repairs_open = true
	var revision: int = deck.service_revision
	check(deck.field_repair(1, revision), "Field repair commits")
	check(store.save_run(deck), "Committed repair saves")
	var repaired = store.load_run().state
	repaired.field_repairs_open = true
	check(not repaired.field_repair(1, revision) and repaired.hull == 20, "Old repair confirmation cannot replay")
	var good: String = FileAccess.get_file_as_string(store.path)
	var envelope: Dictionary = JSON.parse_string(good)
	envelope.schema = 999
	var file = FileAccess.open(store.path, FileAccess.WRITE)
	file.store_string(JSON.stringify(envelope)); file.close()
	check(store.load_run().is_empty() and not store.error.is_empty(), "Unsupported schema rejects safely")
	file = FileAccess.open(store.path, FileAccess.WRITE); file.store_string("{broken"); file.close()
	check(store.load_run().is_empty() and not store.error.is_empty(), "Corrupt JSON rejects without partial load")
	# An unpublished replacement must not abandon an intact published run.
	var unpublished: Dictionary = JSON.parse_string(envelope.payload)
	unpublished.revision = store.revision + 10
	unpublished.expedition.salvage = 9999
	var unpublished_body: String = JSON.stringify(unpublished)
	file = FileAccess.open(store.path, FileAccess.WRITE); file.store_string(good); file.close()
	file = FileAccess.open(store.path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": Save.VERSION, "payload": unpublished_body, "sha256": unpublished_body.sha256_text()})); file.close()
	check(store.load_run().state.salvage != 9999, "Unpublished replacement cannot replace the last confirmed save")
	file = FileAccess.open(store.path, FileAccess.WRITE); file.store_string("broken"); file.close()
	# Recovery chooses a complete newest temporary checkpoint, never a torn write.
	file = FileAccess.open(store.path + ".tmp", FileAccess.WRITE); file.store_string(good); file.close()
	check(not store.load_run().is_empty() and not store.warning.is_empty(), "Interrupted replacement recovers complete temporary file")
	file = FileAccess.open(store.path + ".previous", FileAccess.WRITE); file.store_string(good); file.close()
	file = FileAccess.open(store.path, FileAccess.WRITE); file.store_string("broken"); file.close()
	file = FileAccess.open(store.path + ".tmp", FileAccess.WRITE); file.store_string("torn"); file.close()
	check(not store.load_run().is_empty(), "Torn active/temp recover a validated previous file")
	# A directory occupying the temporary filename deterministically forces a write failure.
	DirAccess.remove_absolute(store.path + ".tmp")
	DirAccess.make_dir_absolute(store.path + ".tmp")
	check(not store.save_run(state) and FileAccess.get_file_as_string(store.path) == good, "Failed write preserves previous complete save")
	DirAccess.remove_absolute(store.path + ".tmp")
	check(store.clear_run() and store.load_run().is_empty(), "Ended run removes Continue")
	# Even an interrupted tombstone replacement must not resurrect the older active run.
	file = FileAccess.open(store.path, FileAccess.WRITE); file.store_string(good); file.close()
	var ended_payload: String = JSON.stringify({"revision": store.revision + 1, "ended": true})
	file = FileAccess.open(store.path + ".tmp", FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema": Save.VERSION, "payload": ended_payload, "sha256": ended_payload.sha256_text()})); file.close()
	check(store.load_run().is_empty(), "Terminal tombstone wins over a pre-death checkpoint")
	# Generated boss/elite identities and completion guards survive re-instantiation.
	var progression = State.new()
	progression.start(1, Rules, 7711)
	while progression.system_number < 6:
		for index in range(progression.encounters.size()): progression._complete_encounter(index)
		progression.ftl_charge = maxi(progression.ftl_charge, progression.required_ftl_charge)
		check(progression.generate_system(), "System travel commits")
	check(store.save_run(progression), "Boss system saves stable enemy identities")
	progression = store.load_run().state
	var boss: int = -1
	for index in range(progression.encounters.size()):
		if progression.encounters[index].get("mandatory_boss", false): boss = index
	check(boss >= 0 and progression.mandatory_boss_pending(), "Mandatory boss survives loading")
	var result = preload("res://scripts/combat/battle_result.gd").new()
	progression.active_battle = boss
	result.encounter_index = boss
	result.system_number = progression.system_number
	result.winner = "player"
	result.player_hull = progression.hull
	result.salvage = progression.victory_salvage(result)
	result.battles_won = 1
	progression.record_battle(result)
	check(store.save_run(progression), "Completed boss and pending upgrades save")
	var won = store.load_run().state
	var currency: int = won.salvage
	var charge: int = won.ftl_charge
	won.active_battle = boss
	won.record_battle(result)
	check(won.encounters[boss].completed and not won.mandatory_boss_pending() and won.salvage == currency and won.ftl_charge == charge, "Boss completion cannot reward twice after load")
	# Outpost revisions, pending production choice and purchase counters.
	var station = State.new()
	station.start(0, Rules, 4411)
	station.salvage = 1000
	station.service = {"kind": "service", "poi": Rules.trading_outpost, "title": "Trading Outpost", "completed": false}
	var slot: int = -1
	for index in range(station.service.poi.approaches.size()):
		if station.service.poi.approaches[index].success.production_choice > 0: slot = index
	var old_revision: int = station.service_revision
	check(slot >= 0 and station.purchase_service(slot, old_revision), "Station purchase commits")
	check(store.save_run(station), "Station purchase saves")
	var purchased = store.load_run().state
	check(purchased.pending_choice == "production" and purchased.station_production_purchases == 1 and not purchased.purchase_service(slot, old_revision), "Purchase and outstanding choice cannot replay")
	check(purchased.choose_attribute("reactor") and store.save_run(purchased), "Purchased production choice saves")
	check(store.load_run().state.production("reactor") == purchased.production("reactor"), "Purchased production survives")
	# A full-deck reward restores the exact pending replacement without rerolling offers.
	var full = State.new()
	full.start(0, Rules, 5511)
	while full.player_pool().size() < full.deck_limit():
		full.pending_choice = "card"
		var offer: Array[Resource] = [full.available_reward_cards()[0]]
		full.card_offers = offer
		full.choose_card(0)
	full.pending_choice = "card"
	full.card_offers = full.random_card_offers()
	var incoming: String = full.card_offers[0].identity_key()
	check(full.choose_card(0) and full.pending_choice == "replace" and store.save_run(full), "Pending replacement saves")
	var replacement = store.load_run().state
	var removed: String = replacement.player_pool()[0].identity_key()
	check(replacement.pending_card.identity_key() == incoming and replacement.replace_card(removed) and store.save_run(replacement), "Exact incoming card replaces owned identity after load")
	check(store.load_run().state.removed_starting_cards.has(removed), "Committed removal remains removed")
	# Chasedown enemy, response and already-paid penalties are authoritative data.
	var chase = State.new()
	chase.start(0, Rules, 6611)
	chase.encounters[0] = {"kind": "poi", "poi": Rules.pois[0], "title": Rules.pois[0].title, "completed": false}
	chase.encounters[1] = chase.encounters[0].duplicate()
	chase.arrive_destination(0)
	check(chase.begin_travel(1, 0.0) and store.save_run(chase), "Chasedown interception saves")
	var intercepted = store.load_run().state
	check(intercepted.pending_destination == 1 and intercepted.chasedown_unresolved(), "Chasedown and selected destination survive")
	check(intercepted.choose_chasedown_response(1) and store.save_run(intercepted), "Committed response saves")
	var response = store.load_run().state
	check(response.encounters[response.chasedown_index].response == 1 and not response.choose_chasedown_response(1), "Response penalties cannot be applied twice")
	var invalid: Dictionary = Save.encode(response)
	invalid.ship_id = "res://scripts/board.gd"
	check(store.decode(invalid) == null, "Arbitrary resource paths are rejected")
	store.clear_run()
	print("Expedition save: %d failures" % failures)
	quit(1 if failures else 0)
