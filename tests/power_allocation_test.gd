extends SceneTree
const Hand = preload("res://scripts/card_hand.gd")
const Cards = preload("res://scripts/card_library.gd")
const Preferences = preload("res://scripts/card_preferences.gd")
const MODES = ["balanced", "offense", "defense", "systems"]
const Ships = preload("res://scripts/ship_library.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

# Frozen pre-allocation selection formula: compare the actual seeded identity sequence.
func legacy_draw(hand: Node) -> Resource:
	var buckets: Dictionary = {1:[], 2:[], 3:[]}
	var pool: Array = hand.card_pool if not hand.card_pool.is_empty() else Cards.CARDS
	for card in pool:
		if card != null and hand._eligible(card, -1): buckets[card.tier].append(card)
	var roll: float = hand.rng.randf()
	var tier: int = 1
	if roll < hand.tier_three_chance: tier = 3
	elif roll < hand.tier_three_chance + clampf(hand.tier_two_chance * hand.drop_multiplier, 0, 1): tier = 2
	var eligible: Array = buckets[tier] if not buckets[tier].is_empty() else buckets[1]
	if eligible.is_empty(): return null
	var weights: Array[float] = []
	var total: float = 0
	for card in eligible:
		var weight: float = maxf(0.01, float(hand.identity_weights.get(card.identity_key(), 1.0))) * Preferences.draw_weight(card, hand.family_weights, hand.effect_weights)
		weights.append(weight)
		total += weight
	var selection: float = hand.rng.randf() * total
	for index in range(eligible.size()):
		selection -= weights[index]
		if selection <= 0: return eligible[index]
	return eligible.back()

func legal(hand: Node, round_number: int) -> bool:
	if hand.cards.size() != 6: return false
	var copies: Dictionary = {}
	var rare: int = 0
	for card in hand.cards:
		if card == null: return false
		var key: String = card.identity_key()
		copies[key] = copies.get(key, 0) + 1
		if copies[key] > 2: return false
		if card.tier == 2:
			rare += 1
			if round_number <= 2 or rare > 1: return false
	return true

func settle() -> void:
	for n in range(8): await process_frame

func activate(control: Control, touch: bool) -> void:
	var location: Vector2 = control.get_global_rect().get_center()
	if touch:
		for down in [true, false]:
			var event = InputEventScreenTouch.new()
			event.index = 0
			event.position = location
			event.pressed = down
			root.push_input(event, true)
			await process_frame
	else:
		var motion = InputEventMouseMotion.new()
		motion.position = location
		root.push_input(motion, true)
		for down in [true, false]:
			var event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = location
			event.global_position = location
			event.pressed = down
			event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
			root.push_input(event, true)
			await process_frame
	await settle()

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/testlogs/allocation-" + label + ".png")

func run() -> void:
	var category_counts: Dictionary = {"offense":0,"defense":0,"systems":0}
	for card in Cards.CARDS:
		check(card.allocation_category in category_counts, "Every card has one primary category")
		category_counts[card.allocation_category] += 1
		for level in [1,2]:
			check(card.with_upgrade(level).allocation_category == card.allocation_category, "Upgrades retain category")
	print("Allocation categories: ", category_counts)
	for ship in Ships.PLAYERS:
		var opener = Hand.new()
		opener.configure_player_allocation(2)
		opener.card_pool.assign(ship.starting_cards)
		for seed_value in range(200):
			opener.rng.seed = 5000 + seed_value
			opener.deal_player_opening()
			var families: Dictionary = {"materials":0,"energy":0,"crew":0}
			for card in opener.cards: families[card.family] += 1
			check(families == {"materials":2,"energy":2,"crew":2} and legal(opener,1), "Every ship opens with 2/2/2 resource costs and legal identities")
		opener.free()
	var custom = Hand.new()
	custom.card_pool.assign([Cards.CARDS[0],Cards.CARDS[1],Cards.CARDS[2]])
	custom.deal_player_opening()
	check(legal(custom,1), "Incomplete custom family pool still draws six eligible cards")
	custom.free()
	var actual = Hand.new()
	var old = Hand.new()
	actual.configure_player_allocation(2)
	for sample in [actual, old]:
		sample.rng.seed = 641321
		sample.current_round = 3
		sample.identity_weights = {Cards.CARDS[0].identity_key():3.0}
		sample.family_weights = {"energy":1.7}
		sample.effect_weights = {"damage":1.4}
	for n in range(3000):
		check(actual.draw_card() == legacy_draw(old) and actual.rng.state == old.rng.state, "Balanced exactly preserves original seeded draws")
	actual.free()
	old.free()
	var observed: Dictionary = {}
	for mode in MODES:
		var hand = Hand.new()
		hand.configure_player_allocation(2)
		hand.select_allocation(mode)
		hand.rng.seed = 7241
		hand.tier_two_chance = 0
		var hits: Dictionary = {"offense":0,"defense":0,"systems":0}
		var expected: Dictionary = {"offense":0.0,"defense":0.0,"systems":0.0}
		# Acquired weighting combines multiplicatively: 3 * 2, not a replacement.
		hand.identity_weights = {Cards.CARDS[0].identity_key():3.0}
		check(is_equal_approx(hand._draw_weight(Cards.CARDS[0]), 6.0 if mode == "defense" else 3.0), "Allocation combines with acquired-card weight")
		for card in Cards.CARDS:
			if card.tier == 1: expected[card.allocation_category] += hand._draw_weight(card)
		var total: float = expected.offense + expected.defense + expected.systems
		for n in range(12000): hits[hand.draw_card().allocation_category] += 1
		observed[mode] = hits
		for category in hits: check(absf(hits[category] / 12000.0 - expected[category] / total) < 0.02, "Seeded distribution matches normalized weight: " + mode + "/" + category)
		print("Allocation samples / 12000: ", mode, " ", hits)
		hand.free()
	for mode in MODES.slice(1): check(observed[mode][mode] > observed.balanced[mode] * 1.2, "Specialization increases matching draws")
	# Eligibility, rarity rolls and caps remain outside the allocation calculation.
	for mode in MODES:
		var hand = Hand.new()
		hand.configure_player_allocation(2)
		hand.select_allocation(mode)
		hand.rng.seed = 6618
		hand.deal(6)
		var drew_tier_two: bool = false
		for round_number in range(1,6):
			hand.current_round = round_number
			for n in range(300):
				hand.replace_card(n % 6)
				check(legal(hand, round_number), "Six-card hand, duplicate cap and original rarity lock: " + mode)
				for card in hand.cards: drew_tier_two = drew_tier_two or card.tier == 2
		check(drew_tier_two, "Tier 2 becomes available from round 3")
		var legacy = Hand.new()
		legacy.current_round = 3
		legacy.rng.seed = 4101
		hand.cards.clear()
		hand.rng.seed = 4101
		hand.current_round = 3
		for n in range(1500): check(hand.draw_card().tier == legacy.draw_card().tier, "Allocation leaves tier roll probabilities identical")
		legacy.free()
		hand.free()
	var fallback = Hand.new()
	fallback.configure_player_allocation(2)
	fallback.select_allocation("offense")
	fallback.card_pool.assign([Cards.CARDS[0],Cards.CARDS[1]])
	var normal = Hand.new()
	normal.card_pool.assign(fallback.card_pool)
	fallback.rng.seed = 9108
	normal.rng.seed = 9108
	for n in range(500): check(fallback.draw_card() == normal.draw_card(), "No matching eligible card falls back to original probabilities")
	fallback.free()
	normal.free()
	# Enemy cannot opt in through the mode selector; preferences retain their exact weights.
	var enemy = Hand.new()
	check(not enemy.select_allocation("offense"), "Enemy allocation stays disabled")
	enemy.family_weights = {"energy":2.0}
	enemy.effect_weights = {"damage":1.5}
	check(is_equal_approx(enemy._draw_weight(Cards.CARDS[11]), 3.0), "Enemy preferences unchanged")
	enemy.free()
	# Real UI events and live board integration at the same responsive anchors.
	for ship_index in range(3):
		root.size = Vector2i(1280,720)
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.setup_settings = {"player_ship":ship_index,"enemy_ship":ship_index}
		board.allocation_settings = board.allocation_settings.duplicate()
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		await settle()
		check(board.hand.allocation_mode == "balanced", "Every new battle starts Balanced")
		check(legal(board.hand,1), "All three ships have valid opening hands")
		var opening_families: Dictionary = {"materials":0,"energy":0,"crew":0}
		for card in board.hand.cards: opening_families[card.family] += 1
		check(opening_families == {"materials":2,"energy":2,"crew":2}, "Actual battle starts 2/2/2")
		var held: Array = board.hand.cards.duplicate()
		var enemy_held: Array = board.enemy_hand.cards.duplicate()
		var rng_state: int = board.hand.rng.state
		var enemy_rng: int = board.enemy_hand.rng.state
		var original_resources: Dictionary = board._read_state("player")
		var charge: int = board.ftl.charge
		var turn: int = board.turn_number
		board.allocation_settings.matching_draw_weight = 9
		check(board.hand._allocation_multiplier == 2, "Inspector value is frozen for current battle")
		for dimensions in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(800,450)]:
			root.size = dimensions
			await settle()
			var poses: Array = []
			for path in board.card_slots:
				var card: Control = board.get_node(path)
				poses.append([card.position,card.size,card.scale])
				var expected_scale: float = minf(1.0, (board.size.x - 82) / (198 * 6))
				check(card.size == Vector2(198,294) and card.scale.is_equal_approx(Vector2.ONE * expected_scale), "Existing card dimensions/scaling preserved")
			check(board.allocation_button.position.is_equal_approx(Vector2(board.size.x-80, board.get_node(board.card_slots[0]).position.y-60)), "One shared action-strip anchor at all aspect ratios")
			for index in range(MODES.size()):
				await activate(board.allocation_button, index % 2 == 1)
				check(board.allocation_popup.shade.visible, "Mouse/touch opens allocation popup")
				check(root.get_visible_rect().encloses(board.allocation_popup.panel.get_global_rect()), "Centered popup fits landscape viewport")
				if ship_index == 0 and index == 0: await capture(str(dimensions.x))
				await activate(board.allocation_popup.choices[index], index % 2 == 1)
				check(board.hand.allocation_mode == MODES[index] and not board.allocation_popup.shade.visible, "Choice applies and closes popup")
				check(board.allocation_button.text == board.allocation_popup.ICONS[index], "Button shows selected emoji")
				check(board.hand.cards == held and board.enemy_hand.cards == enemy_held and board.hand.rng.state == rng_state and board.enemy_hand.rng.state == enemy_rng, "Switch never modifies/rerolls either current hand")
				check(board._read_state("player") == original_resources and board.ftl.charge == charge and board.turn_number == turn, "Switch has no cost, cooldown or turn effect")
				for slot in range(6):
					var card: Control = board.get_node(board.card_slots[slot])
					check([card.position,card.size,card.scale] == poses[slot], "Popup never moves or resizes the hand")
			await activate(board.allocation_button, false)
			var cancel = InputEventAction.new()
			cancel.action = "ui_cancel"
			cancel.pressed = true
			root.push_input(cancel, true)
			check(not board.allocation_popup.shade.visible and board.hand.allocation_mode == "systems", "Back dismisses without changing mode")
		board.current_actor = "enemy"
		board._select_allocation("offense")
		check(board.hand.allocation_mode == "offense", "Switching is free during enemy turn too")
		board.hand.current_round = 3
		board.hand.replace_card(0)
		check(board.hand.cards.slice(1) == held.slice(1) and board.hand.rng.state != rng_state, "Only the subsequent replacement draws a new card")
		board.free()
		await process_frame
	print("Power Allocation: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
