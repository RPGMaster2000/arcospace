extends SceneTree
# Pure ownership rules run without a Board, hand, UI or scene instance.
const Deck = preload("res://scripts/expedition/expedition_deck.gd")
const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
var checks: int = 0
var failures: int = 0
var notifications: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	var deck = Deck.new()
	var profile: Resource = Ships.PLAYERS[0]
	var rules: Resource = Rules.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = 431
	check(deck.player_pool(profile) == profile.starting_cards, "Starting identities/order unchanged")
	check(deck.choose_card(0, profile, rules).is_empty(), "No offer cannot be acquired")
	deck.pending_choice = "card"
	deck.card_offers = deck.random_card_offers(profile, rules, rng, 2)
	for card in deck.card_offers:
		check(card.tier >= 2, "Tier restriction")
	var incoming: Resource = deck.card_offers[0]
	check(not deck.choose_card(0, profile, rules).is_empty(), "Acquire valid offer")
	check(deck.choose_card(0, profile, rules).is_empty(), "Acquisition consumed once")
	check(deck.acquired_draw_weights(rules) == {incoming.identity_key(): rules.acquired_card_draw_weight}, "Acquisition weight unchanged")
	deck.pending_choice = "card"
	deck.card_offers.assign([incoming])
	check(deck.choose_card(0, profile, rules).is_empty(), "Owned identity rejects a stale offer")
	deck.pending_choice = ""
	deck.start_upgrade_event(2, profile)
	var key: String = incoming.identity_key()
	check(not deck.choose_upgrade(key, profile).is_empty(), "Upgrade I")
	check(deck.upgraded_cards[key].upgrade_level == 1 and deck.upgrades_remaining == 1, "Upgrade level/count")
	check(deck.choose_upgrade(key, profile).is_empty(), "One selection per identity per event")
	check(not deck.finish_upgrades(profile), "Mandatory award cannot be skipped")
	var other: String = deck.upgrade_candidates(profile)[0].identity_key()
	check(other != key and not deck.choose_upgrade(other, profile).is_empty(), "Different identity remains eligible")
	check(deck.pending_choice.is_empty() and deck.upgrades_remaining == 0, "Event closes after spending")
	deck.start_upgrade_event(1, profile)
	check(not deck.choose_upgrade(key, profile).is_empty() and deck.upgraded_cards[key].upgrade_level == 2, "Later event permits Upgrade II")
	var upgraded_snapshot: Dictionary = deck.snapshot()
	upgraded_snapshot.upgrades[key] = 0
	check(deck.upgraded_cards[key].upgrade_level == 2, "Snapshot levels cannot change owned upgrades")
	deck.start_upgrade_event(1, profile)
	check(deck.choose_upgrade(key, profile).is_empty(), "Upgrade maximum enforced")
	check(deck.upgraded_cards[key].cost == incoming.cost and incoming.upgrade_level == 0, "Base definitions and costs untouched")
	deck.reset()
	rules.max_deck_identities = profile.starting_cards.size()
	deck.pending_choice = "card"
	deck.card_offers = deck.random_card_offers(profile, rules, rng)
	incoming = deck.card_offers[0]
	var pool: Array[Resource] = deck.player_pool(profile)
	check(not deck.choose_card(0, profile, rules).is_empty() and deck.pending_card == incoming, "Full deck fixes incoming")
	check(deck.player_pool(profile) == pool and deck.card_offers.is_empty(), "Replacement deferred without ownership mutation")
	check(deck.replace_card("invalid", profile, rules).is_empty(), "Invalid removal changes nothing")
	check(not deck.decline_card().is_empty() and deck.decline_card().is_empty(), "Decline consumed once")
	check(deck.player_pool(profile) == pool, "Decline preserves ownership")
	deck.pending_choice = "card"
	deck.card_offers.assign([incoming])
	deck.choose_card(0, profile, rules)
	var removed: String = pool[0].identity_key()
	check(not deck.replace_card(removed, profile, rules).is_empty(), "Replace validated identity")
	check(deck.replace_card(removed, profile, rules).is_empty(), "Repeated replacement rejected")
	check(deck.player_pool(profile).size() == rules.max_deck_identities and deck.removed_starting_cards.has(removed), "Capacity/removal retained")
	check(deck.acquired_cards.size() == 1 and deck.acquired_cards[0] == incoming, "New card acquired once")
	check(not deck.player_pool(profile).any(func(card: Resource): return card.identity_key() == removed), "Removed starting identity stays absent")
	var detached_pool: Array[Resource] = deck.player_pool(profile)
	detached_pool.clear()
	check(deck.player_pool(profile).size() == rules.max_deck_identities, "Derived pool is not a second mutable inventory")
	var snapshot: Dictionary = deck.snapshot()
	snapshot.acquired.clear()
	snapshot.removed.clear()
	snapshot.upgrades[key] = 2
	snapshot.upgraded_this_event.append(removed)
	check(deck.snapshot().acquired.size() == 1 and deck.snapshot().removed.size() == 1 and deck.upgraded_cards.is_empty() and deck.upgraded_this_event.is_empty(), "Detached nested snapshot cannot mutate deck")
	var state = State.new()
	state.start(0, rules, 431)
	state.deck_changed.connect(func(): notifications.append("deck"))
	state.progress_committed.connect(func(): notifications.append("progress"))
	state.pending_choice = "card"
	state.card_offers = state.random_card_offers()
	check(state.choose_card(0) and notifications == ["progress"], "Pending replacement saves without deck mutation")
	notifications.clear()
	check(state.replace_card(removed) and notifications == ["deck", "progress"], "Replacement notifies deck then saves once")
	notifications.clear()
	check(not state.replace_card(removed) and notifications.is_empty(), "Replay emits no notifications")
	var acquired: Array[Resource] = state.acquired_cards
	acquired.clear()
	var removals: Dictionary = state.removed_starting_cards
	removals.clear()
	var supplied: Array[Resource] = state.card_offers
	state.card_offers = supplied
	supplied.append(incoming)
	check(state.acquired_cards.size() == 1 and state.removed_starting_cards.has(removed) and state.card_offers.is_empty(), "Facade containers and setter inputs cannot alias ledgers")
	# These payloads were recorded by the pre-refactor codec, not encoded by this owner.
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/deck_ownership_baseline.json"))
	for kind in ["replacement", "upgrade"]:
		var loaded: Resource = Save.new().decode(baseline.saves[kind])
		check(loaded != null, "Existing-format %s fixture loads" % kind)
		if loaded == null: continue
		var migrated: Dictionary = JSON.parse_string(JSON.stringify(Save.encode(loaded)))
		for field in ["ship_id", "seed", "rng", "acquired", "removed", "upgrades", "upgraded_this_event", "offers", "pending_card", "pending_choice", "upgrades_remaining"]:
			check(migrated[field] == baseline.saves[kind][field], "Historic %s ledger survives metagame migration: %s" % [kind, field])
		if kind == "replacement":
			var identity: String = loaded.player_pool()[0].identity_key()
			check(loaded.replace_card(identity) and not loaded.replace_card(identity), "Resumed replacement consumed once")
		else:
			var already: String = loaded.upgraded_this_event.keys()[0]
			check(not loaded.choose_upgrade(already), "Resumed event retains chosen identities")
			loaded.finish_upgrades()
			check(loaded.pending_choice == "upgrade", "Resumed upgrade cannot be skipped")
			check(loaded.choose_upgrade(loaded.upgrade_candidates()[0].identity_key()) and not loaded.choose_upgrade(already), "Resumed award finishes once")
	print("Deck ownership: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
