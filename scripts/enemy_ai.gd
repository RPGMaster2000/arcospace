extends Node

# RESPONSIBILITY: Choose a legal move, using Starship Duel's priorities.
# DOES NOT: Spend resources, apply real effects or advance turns.
const Effects = preload("res://scripts/card_effects.gd")
const Rules = preload("res://scripts/match_rules.gd")
@export var attack_below_hull: int = 15
@export var build_from_hull: int = 40
var rng := RandomNumberGenerator.new()
var tactical_weights: Dictionary = {}
var tactical_variation: float = 0.25
var hull_capacity: int = 35

# Prefer safe immediate wins, then configured tactical scores or fallback priorities; discard if nothing is affordable.
func choose(cards: Array, actor: Dictionary, enemy: Dictionary, resource_goal: int) -> Dictionary:
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
		Effects.play(cards[slot], simulated, target, null, true)
		if simulated.hull > 0 and Rules.wins(simulated, target, resource_goal):
			return {"slot": slot, "discard": false}
	# Avoid fatal self damage when choosing a non-winning move.
	var safe: Array[int] = []
	for slot in affordable:
		var safe_actor: Dictionary = actor.duplicate(true)
		var safe_target: Dictionary = enemy.duplicate(true)
		Effects.play(cards[slot], safe_actor, safe_target, null, true)
		if safe_actor.hull > 0:
			safe.append(slot)
	if safe.is_empty():
		return {"slot": _pick(affordable), "discard": true}
	affordable = safe
	if not tactical_weights.is_empty():
		return {"slot": _tactical_pick(affordable, cards, actor, enemy), "discard": false}
	var attacks: Array[int] = []
	var repairs: Array[int] = []
	var upgrades: Array[int] = []
	for slot in affordable:
		var effects: Dictionary = cards[slot].effects
		if effects.get("damage", 0) > 0:
			attacks.append(slot)
		if effects.get("hull", 0) > 0:
			repairs.append(slot)
		if effects.has("production_other"):
			upgrades.append(slot)
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

# Uses only public combat state and conservative effect simulation, never the player's hand.
func _tactical_pick(slots: Array[int], cards: Array, actor: Dictionary, enemy: Dictionary) -> int:
	var best: int = slots[0]
	var best_score: float = -INF
	for slot in slots:
		var next_actor: Dictionary = actor.duplicate(true)
		var next_enemy: Dictionary = enemy.duplicate(true)
		Effects.play(cards[slot], next_actor, next_enemy, null, true)
		var score: float = 0.0
		score += (enemy.hull - next_enemy.hull) * float(tactical_weights.get("damage", 1.0))
		var healed: int = mini(hull_capacity, next_actor.hull) - mini(hull_capacity, actor.hull)
		score += healed * float(tactical_weights.get("hull", 1.0)) * (2.0 if actor.hull < hull_capacity / 2 else 1.0)
		score += (next_actor.shields - actor.shields) * float(tactical_weights.get("shields", 0.4))
		score += (enemy.shields - next_enemy.shields) * float(tactical_weights.get("disruption", 0.4))
		for index in range(Rules.RESOURCES.size()):
			var resource: String = Rules.RESOURCES[index]
			var production: String = Rules.PRODUCTION[index]
			score += (next_actor[resource] - actor[resource]) * float(tactical_weights.get("resources", 0.3))
			score += (enemy[resource] - next_enemy[resource]) * float(tactical_weights.get("disruption", 0.4))
			score += (next_actor[production] - actor[production]) * float(tactical_weights.get("production", 4.0))
			score += (enemy[production] - next_enemy[production]) * float(tactical_weights.get("disruption", 0.4)) * 2.0
		# Random resource gains are absent from conservative simulation; value their expectation.
		var effects: Dictionary = cards[slot].effects
		var random_value: float = float(effects.get("random_gain", 0)) + float(effects.get("random_gain_other", 0))
		if effects.has("random_gain_range_other"):
			random_value += (float(effects.random_gain_range_other.min) + float(effects.random_gain_range_other.max)) / 2.0
		score += random_value * float(tactical_weights.get("resources", 0.3))
		score += float(tactical_weights.get("play_again", 1.0)) if cards[slot].play_again else 0.0
		score += rng.randf_range(-tactical_variation, tactical_variation) * maxf(1.0, absf(score))
		if score > best_score:
			best_score = score
			best = slot
	return best
