extends RefCounted
const Cards = preload("res://scripts/cards/card_library.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
static func cases() -> Array:
	var result: Array = []
	var hands: Array = [[11,2,40,41,12,10],[40,2,41,11,43,3],[18,38,39,42,43,67],[68,70,72,3,10,17],[11,20,25,40,56,61],[0,8,20,25,30,61]]
	var contexts: Array = [{"kind":0},{"kind":1},{"kind":2,"active":false},{"kind":2,"active":true,"ion_factor":0.5},{"kind":2,"active":true,"ion_factor":2.0},{"kind":3,"active":true},{"kind":4,"miss_rate":30},{"kind":5}]
	for hand_index in range(hands.size()):
		var cards: Array = []
		for index in hands[hand_index]:
			cards.append(Cards.CARDS[index].with_upgrade(index % 3) if hand_index == 4 else Cards.CARDS[index])
		for situation in range(5):
			var actor: Dictionary = Ship.new().snapshot()
			var enemy: Dictionary = Ship.new().snapshot()
			for key in Ship.RESOURCES: actor[key] = 40
			if situation == 1:
				enemy.hull = 6
				enemy.shields = 0
			if situation == 2:
				actor.hull = 4
				actor.shields = 12
				enemy.hull = 40
				enemy.shields = 12
			if situation == 3:
				actor.synthesizer = 0
				actor.reactor = 0
				actor.systems_failure_remaining = 1
			if situation == 4:
				for key in Ship.RESOURCES: actor[key] = 0
			for seed_value in [7,43]:
				for mode in range(contexts.size()):
					result.append({"id":"%d/%d/%d/%d" % [hand_index,situation,seed_value,mode],"cards":cards,"actor":actor.duplicate(true),"enemy":enemy.duplicate(true),"context":contexts[mode].duplicate(),"seed":seed_value,"weights":{"hull":2.0,"damage":1.2} if situation == 3 else {}})
	return result
static func fingerprint(item: Dictionary) -> String:
	var cards: Array = []
	for card in item.cards: cards.append([card.identity_key(),card.upgrade_level,card.effects])
	return JSON.stringify([cards,item.actor,item.enemy,item.context,item.seed,item.weights]).sha256_text()
