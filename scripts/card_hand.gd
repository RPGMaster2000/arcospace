extends Node

# RESPONSIBILITY: Deal an opening hand and replace used cards.
# DOES NOT: Pay costs, apply effects or manage turns.
const CardLibrary = preload("res://scripts/card_library.gd")
# An empty pool uses card_library.gd. Drag in .tres files for a custom pool.
@export var card_pool: Array[Resource] = []
# An empty starting hand draws randomly. Assign cards for a fixed test hand.
@export var starting_hand: Array[Resource] = []
@export_range(1, 6, 1) var max_copies: int = 2
## TUNE: Tier 2 chance when the hand has room: 0.15 = 15%.
@export_range(0.0, 1.0, 0.01) var tier_two_chance: float = 0.15
## TUNE: Tier 3 chance, reserved for future cards. Zero disables random Tier 3 draws.
@export_range(0.0, 1.0, 0.01) var tier_three_chance: float = 0.0
## TUNE: Tier 2 is unavailable through this full round, including opening hands.
@export_range(0, 20, 1) var tier_two_locked_turns: int = 5
var current_round: int = 1
var drop_multiplier: float = 1.0
var cards: Array[Resource] = []
var rng := RandomNumberGenerator.new()

func deal(size: int) -> void:
	cards.clear()
	for slot in range(size):
		var initial: Resource = starting_hand[slot] if slot < starting_hand.size() else null
		if initial != null and _eligible(initial, -1):
			cards.append(initial)
		else:
			cards.append(draw_card())


func draw_card(excluded_slot: int = -1) -> Resource:
	var pool: Array = card_pool if not card_pool.is_empty() else CardLibrary.CARDS
	var buckets: Dictionary = {1: [], 2: [], 3: []}
	for card in pool:
		# Repeated pool entries represent acquired draw weight, not extra hand slots.
		if card != null and _eligible(card, excluded_slot):
			buckets[card.tier].append(card)
	var roll: float = rng.randf()
	var tier: int = 1
	if roll < tier_three_chance:
		tier = 3
	elif roll < tier_three_chance + clampf(tier_two_chance * drop_multiplier, 0, 1):
		tier = 2
	# Full Tier 2 hands fall back to Tier 1; probabilities are per eligible draw.
	var eligible: Array = buckets[tier] if not buckets[tier].is_empty() else buckets[1]
	if eligible.is_empty():
		# Custom test pools may contain only Tier 2; respect the cap rather than overfill.
		push_warning("No eligible cards in the selected tier or Tier 1 fallback.")
		return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]

func _eligible(card: Resource, excluded_slot: int) -> bool:
	if card.tier == 2 and current_round <= tier_two_locked_turns:
		return false
	var copies: int = 0
	for slot in range(cards.size()):
		if slot == excluded_slot or cards[slot] == null:
			continue
		if card.tier > 1 and cards[slot].tier == card.tier:
			return false
		if cards[slot].identity_key() == card.identity_key():
			copies += 1
	return copies < max_copies


func replace_card(slot: int) -> void:
	if slot < 0 or slot >= cards.size():
		return
	# Exclude the used card when counting copies for its replacement.
	cards[slot] = draw_card(slot)
