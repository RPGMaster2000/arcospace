extends RefCounted
# RESPONSIBILITY: Recovery choices and resource preservation; no live state or RNG sampling.
const Effects = preload("res://scripts/cards/card_effects.gd")
const Rules = preload("res://scripts/match_rules.gd")


static func recovery_costs(cards: Array, actor: Dictionary, enemy: Dictionary) -> Dictionary:
	var costs: Dictionary = {}
	for card in cards:
		if card == null:
			continue
		var funded: Dictionary = actor.duplicate(true)
		funded[card.family] = maxi(funded[card.family], card.cost)
		var target: Dictionary = enemy.duplicate(true)
		Effects.play(card, funded, target, null, true)
		if (
			funded.hull > 0
			and Rules.offline_systems(funded).size() < Rules.offline_systems(actor).size()
		):
			costs[card.family] = mini(int(costs.get(card.family, card.cost)), card.cost)
	return costs


static func discard(
	held: Array[int], cards: Array, actor: Dictionary, enemy: Dictionary, pick: Callable
) -> int:
	if not Rules.systems_failure_triggered(actor):
		return pick.call(held)
	var costs: Dictionary = recovery_costs(cards, actor, enemy)
	var best: int = held[0]
	var score: float = -INF
	for slot in held:
		var card: Resource = cards[slot]
		var funded: Dictionary = actor.duplicate(true)
		funded[card.family] = maxi(funded[card.family], card.cost)
		var target: Dictionary = enemy.duplicate(true)
		Effects.play(card, funded, target, null, true)
		var restores: bool = (
			Rules.offline_systems(funded).size() < Rules.offline_systems(actor).size()
		)
		var value: float = (
			(floor(card.cost / 3.0) if costs.has(card.family) else 0.0)
			- (1000.0 if restores else 0.0)
		)
		if value > score:
			score = value
			best = slot
	return best


static func choose(
	affordable: Array[int],
	held: Array[int],
	cards: Array,
	actor: Dictionary,
	enemy: Dictionary,
	tactical_pick: Callable,
	pick: Callable
) -> Dictionary:
	var costs: Dictionary = recovery_costs(cards, actor, enemy)
	var candidates: Array[int] = []
	var best: int = -1
	var best_recovery: float = 0.0
	for slot in affordable:
		var next_actor: Dictionary = actor.duplicate(true)
		var next_enemy: Dictionary = enemy.duplicate(true)
		Effects.play(cards[slot], next_actor, next_enemy, null, true)
		var repaired: int = (
			Rules.offline_systems(actor).size() - Rules.offline_systems(next_actor).size()
		)
		if repaired > 0:
			var remaining: int = maxi(1, int(actor.get("systems_failure_remaining", 1)))
			var completes: bool = not Rules.systems_failure_triggered(next_actor)
			if not completes and cards[slot].play_again:
				# Only a known held follow-up counts; never assume a lucky replacement draw.
				for followup in affordable:
					if (
						followup == slot
						or next_actor[cards[followup].family] < cards[followup].cost
					):
						continue
					var restored: Dictionary = next_actor.duplicate(true)
					var target: Dictionary = next_enemy.duplicate(true)
					Effects.play(cards[followup], restored, target, null, true)
					completes = (
						completes
						or (restored.hull > 0 and not Rules.systems_failure_triggered(restored))
					)
			var value: float = (
				repaired * 1000.0
				+ (10000.0 / remaining if completes else 0.0)
				- cards[slot].cost * 0.01
			)
			if value > best_recovery:
				best_recovery = value
				best = slot
		var preserves: bool = true
		for family in costs:
			if next_actor[family] < mini(actor[family], costs[family]):
				preserves = false
		if preserves:
			candidates.append(slot)
	if best >= 0:
		return {"slot": best, "discard": false}
	if not candidates.is_empty():
		return {"slot": tactical_pick.call(candidates, cards, actor, enemy), "discard": false}
	return {"slot": discard(held, cards, actor, enemy, pick), "discard": true}
