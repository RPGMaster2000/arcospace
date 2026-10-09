extends Node

# HUVUDANSVAR: Dra en starthand och ersätta spelade kort.
# GÖR INTE: Betala kostnader, utföra effekter eller hantera turer.
const CardLibrary = preload("res://scripts/card_library.gd")
# Tom pool använder card_library.gd. Dra in .tres-filer för en egen testpool.
@export var card_pool: Array[Resource] = []
# Tom starthand ger slumpkort. Fyll i för en bestämd testhand.
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
		push_warning("Kortpoolen är för liten för korthandens kopiegräns.")
		return null
	return eligible[rng.randi_range(0, eligible.size() - 1)]


func replace_card(slot: int) -> void:
	if slot < 0 or slot >= cards.size():
		return
	# Det spelade kortet räknas inte när ersättaren dras.
	cards[slot] = draw_card(slot)
