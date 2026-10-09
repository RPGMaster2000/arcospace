extends Node

# RESPONSIBILITY: Deal an opening hand and replace used cards.
# DOES NOT: Pay costs, apply effects or manage turns.
const CardLibrary = preload("res://scripts/card_library.gd")
# An empty pool uses card_library.gd. Drag in .tres files for a custom pool.
@export var card_pool: Array[Resource] = []
# An empty starting hand draws randomly. Assign cards for a fixed test hand.
@export var starting_hand: Array[Resource] = []
@export_range(1, 6, 1) var max_copies: int = 2
var cards: Array[Resource] = []
var rng := RandomNumberGenerator.new()

func deal(size: int) -> void:
	cards.clear()
	for slot in range(size):
		var initial: Resource = starting_hand[slot] if slot < starting_hand.size() else null
		if initial != null and cards.count(initial) < max_copies:
			cards.append(initial)
		else:
			cards.append(draw_card())


func draw_card(excluded_slot: int = -1) -> Resource:
	var pool: Array = card_pool if not card_pool.is_empty() else CardLibrary.CARDS
	var eligible: Array[Resource] = []
	for card in pool:
		if card == null or eligible.has(card):
			continue
		var copies: int = 0
		for slot in range(cards.size()):
			if slot != excluded_slot and cards[slot] == card:
				copies += 1
		if copies < max_copies:
			eligible.append(card)
	if eligible.is_empty():
		push_warning("The card pool is too small for the hand copy limit.")
		return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]


func replace_card(slot: int) -> void:
	if slot < 0 or slot >= cards.size():
		return
	# Exclude the used card when counting copies for its replacement.
	cards[slot] = draw_card(slot)
