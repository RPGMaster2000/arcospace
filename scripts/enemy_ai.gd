extends Node

# RESPONSIBILITY: Choose a legal move, using Starship Duel's priorities.
# DOES NOT: Spend resources, apply real effects or advance turns.
const Effects = preload("res://scripts/card_effects.gd")
const Rules = preload("res://scripts/match_rules.gd")
@export var attack_below_hull: int = 15
@export var build_from_hull: int = 40
var rng := RandomNumberGenerator.new()

func choose(cards: Array, actor: Dictionary, enemy: Dictionary, hull_goal: int, resource_goal: int) -> Dictionary:
	var held: Array[int] = []
	var affordable: Array[int] = []
	for slot in range(cards.size()):
		var card: Resource = cards[slot]
		if card != null:
			held.append(slot)
			if actor[card.family] >= card.cost:
				affordable.append(slot)
	if held.is_empty():
		return {}
	if affordable.is_empty():
		return {"slot": _pick(held), "discard": true}
	# Simulate on copies: decision-making never mutates live game state.
	for slot in affordable:
		var simulated: Dictionary = actor.duplicate(true)
		var target: Dictionary = enemy.duplicate(true)
		Effects.play(cards[slot], simulated, target)
		if Rules.wins(simulated, target, hull_goal, resource_goal):
			return {"slot": slot, "discard": false}
	var attacks: Array[int] = []
	var repairs: Array[int] = []
	var upgrades: Array[int] = []
	for slot in affordable:
		var effects: Dictionary = cards[slot].effects
		if effects.get("damage", 0) > 0:
			attacks.append(slot)
		if effects.get("hull", 0) > 0:
			repairs.append(slot)
		for key in Rules.PRODUCTION:
			if effects.get(key, 0) > 0:
				upgrades.append(slot)
				break
	if enemy.hull <= attack_below_hull and not attacks.is_empty():
		return {"slot": _pick(attacks), "discard": false}
	if actor.hull >= build_from_hull and not repairs.is_empty():
		return {"slot": _pick(repairs), "discard": false}
	if not upgrades.is_empty():
		return {"slot": _pick(upgrades), "discard": false}
	return {"slot": _pick(affordable), "discard": false}


func _pick(slots: Array[int]) -> int:
	return slots[rng.randi_range(0, slots.size() - 1)]
