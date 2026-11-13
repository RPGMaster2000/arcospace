extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func fresh(seed_value: int = 1042) -> Resource:
	var state := State.new()
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	state.start(0,rules,seed_value)
	return state
func restore(state: Resource) -> Resource:
	return Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))),state.rules)
func ids(cards: Array) -> Array:
	return cards.map(func(card): return card.identity_key())
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for seed_value in range(1,31):
		var state := fresh(seed_value)
		var twin := fresh(seed_value)
		var owned: Array = ids(state.player_pool())
		check(state.start_card_batch() and twin.start_card_batch(), "Tier 1 batch starts")
		check(ids(state.card_offers) == ids(twin.card_offers) and state.rng.state == twin.rng.state, "Reward selection and RNG continuation are deterministic")
		check(state.card_offers.size() == 2 and state.card_offers[0] != state.card_offers[1], "Two distinct rewards honor unique deck identities")
		for card in state.card_offers:
			check(card.tier == 1 and card.signature_ship < 0 and card.identity_key() not in owned, "Every offered card is eligible Tier 1")
		var promised: Array = ids(state.card_offers)
		var loaded: Resource = restore(state)
		check(loaded != null, "Unconfirmed batch persists")
		if loaded == null: continue
		check(ids(loaded.card_offers) == promised and not loaded.start_card_batch(), "Reopening never rerolls an existing batch")
		check(loaded.confirm_card_batch(), "One confirmation awards both")
		# The normal test profile has capacity; replacement cases below cover full decks.
		if loaded.pending_choice.is_empty():
			check(promised.all(func(id): return id in ids(loaded.player_pool())), "Both rewards are owned")
		check(not loaded.confirm_card_batch(), "Repeated confirmation cannot award again")
	var full := fresh()
	full.rules.max_deck_identities = full.player_pool().size()
	var initial: Array = ids(full.player_pool())
	check(full.start_card_batch(), "Full deck still generates two rewards")
	var promised: Array = ids(full.card_offers)
	check(full.confirm_card_batch() and full.pending_choice == "replace", "Full deck requests first replacement")
	check(not full.decline_card(), "Batch rewards cannot be silently declined")
	var loaded: Resource = restore(full)
	check(loaded != null, "Pending first replacement persists")
	if loaded != null:
		check(loaded.replace_card(initial[0]) and loaded.pending_choice == "replace", "First replacement advances to second reward")
		check(not loaded.replace_card(promised[0]), "First promised reward cannot be exchanged for the second")
		check(loaded.replacement_pool().all(func(card): return card.identity_key() != promised[0]), "Protected reward is absent from replacement gallery")
		loaded = restore(loaded)
		check(loaded != null, "Pending second replacement and protected card persist")
		if loaded != null:
			check(loaded.replace_card(initial[1]) and loaded.pending_choice.is_empty(), "Second replacement completes batch")
			check(promised.all(func(id): return id in ids(loaded.player_pool())), "Full deck keeps both new cards")
			check(loaded.player_pool().size() == loaded.deck_limit(), "Batch respects capacity")
			check(restore(loaded) != null, "Completed batch saves normally")
	var screen = preload("res://scripts/ui/card_management_screen.gd").new()
	root.add_child(screen)
	var visual := fresh()
	visual.start_card_batch()
	screen.present("card_batch",visual.card_offers,0,null,visual.deck_limit(),"")
	check(screen.heading.text.contains("Two Tier 1") and screen.confirm_button.text == "Keep Both Cards", "Existing reward UI describes keeping both")
	check(not screen.decline_button.visible, "Batch confirmation offers no discard-other action")
	screen.free()
	print("Defense PoI card batches: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
