extends Node

# RESPONSIBILITY: Deal an opening hand and replace used cards.
# DOES NOT: Pay costs, apply effects or manage turns.
const CardLibrary = preload("res://scripts/cards/card_library.gd")
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
@export_range(0, 20, 1) var tier_two_locked_turns: int = 2
var identity_weights: Dictionary = {}
var family_weights: Dictionary = {}
var effect_weights: Dictionary = {}
const Preferences = preload("res://scripts/cards/card_preferences.gd")
var current_round: int = 1
var drop_multiplier: float = 1.0
var cards: Array[Resource] = []
var rng := RandomNumberGenerator.new()
var allocation_mode: String = "balanced"
var _allocation_enabled: bool = false
var _allocation_multiplier: float = 1.0

#region Allocation and opening


# Only Board's player hand opts in. No RNG or current-hand changes on mode selection.
func configure_player_allocation(multiplier: float) -> void:
	_allocation_enabled = true
	_allocation_multiplier = maxf(1.0, multiplier) if is_finite(multiplier) else 1.0
	allocation_mode = "balanced"


func select_allocation(mode: String) -> bool:
	if not _allocation_enabled or mode not in ["balanced", "offense", "defense", "systems"]:
		return false
	allocation_mode = mode
	return true


func deal(size: int) -> void:
	cards.clear()
	for slot in range(size):
		var initial: Resource = starting_hand[slot] if slot < starting_hand.size() else null
		if initial != null and _eligible(initial, -1):
			cards.append(initial)
		else:
			cards.append(draw_card())


func deal_player_opening() -> void:
	# Opening only: two costs from each family, without changing replacement draws.
	# Fixed Inspector/test cards keep their slots when they satisfy quota and eligibility.
	cards.clear()
	cards.resize(6)
	var remaining: Dictionary = {"materials": 2, "energy": 2, "crew": 2}
	for slot in range(6):
		var initial: Resource = starting_hand[slot] if slot < starting_hand.size() else null
		if initial != null and remaining.get(initial.family, 0) > 0 and _eligible(initial, -1):
			cards[slot] = initial
			remaining[initial.family] -= 1
	var families: Array[String] = []
	for family in remaining:
		for n in range(remaining[family]):
			families.append(family)
	# Shuffle slot families using this hand's seed, not the global RNG.
	for index in range(families.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var value: String = families[index]
		families[index] = families[other]
		families[other] = value
	for slot in range(6):
		if cards[slot] == null:
			cards[slot] = draw_card(-1, families.pop_back())


#endregion

#region Weighted draws


# Filter eligibility first, roll rarity, then weight identities within that rarity; cost is not a draw filter.
# EXTEND: New draw weights must preserve _eligible, tier fallback and player/enemy separation.
func draw_card(excluded_slot: int = -1, required_family: String = "") -> Resource:
	var pool: Array = card_pool if not card_pool.is_empty() else CardLibrary.CARDS
	var buckets: Dictionary = {1: [], 2: [], 3: []}
	for card in pool:
		# Custom repeated entries are weights, not extra hand slots; acquisitions use identity_weights.
		if (
			card != null
			and (required_family.is_empty() or card.family == required_family)
			and _eligible(card, excluded_slot)
		):
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
		# Incomplete custom pools must not block a valid draw; bundled player pools meet 2/2/2.
		if not required_family.is_empty():
			return draw_card(excluded_slot)
		# Custom test pools may contain only Tier 2; respect the cap rather than overfill.
		push_warning("No eligible cards in the selected tier or Tier 1 fallback.")
		return null
	var total: float = 0.0
	for card in eligible:
		total += _draw_weight(card)
	var selection: float = rng.randf() * total
	for card in eligible:
		selection -= _draw_weight(card)
		if selection <= 0:
			return card
	return eligible.back()


func _draw_weight(card: Resource) -> float:
	var weight: float = (
		maxf(0.01, float(identity_weights.get(card.identity_key(), 1.0)))
		* Preferences.draw_weight(card, family_weights, effect_weights)
	)
	if (
		_allocation_enabled
		and allocation_mode != "balanced"
		and card.allocation_category == allocation_mode
	):
		weight *= _allocation_multiplier
	return weight


# Count identities excluding the replaced slot; upgrades keep original rarity and duplicate identity.
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


#endregion

#region Owned card updates


func apply_upgrades(upgrades: Dictionary) -> void:
	for slot in range(card_pool.size()):
		card_pool[slot] = upgrades.get(card_pool[slot].identity_key(), card_pool[slot])
	for slot in range(cards.size()):
		if cards[slot] != null:
			cards[slot] = upgrades.get(cards[slot].identity_key(), cards[slot])


func replace_card(slot: int) -> void:
	if slot < 0 or slot >= cards.size():
		return
	# Exclude the used card when counting copies for its replacement.
	cards[slot] = draw_card(slot)

#endregion
