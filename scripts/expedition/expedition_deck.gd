extends RefCounted
# RESPONSIBILITY: Own persistent card identities and card reward/upgrade transactions.
# DOES NOT: Hold expedition/Board references, spend currency, resolve encounters or save.
# Context and the authoritative reward RNG are supplied by ExpeditionState per operation.
const Cards = preload("res://scripts/cards/card_library.gd")
var acquired_cards: Array[Resource] = []
var upgraded_cards: Dictionary = {}
var removed_starting_cards: Dictionary = {}
var pending_card: Resource
var upgrades_remaining: int = 0
var upgraded_this_event: Dictionary = {}
var card_offers: Array[Resource] = []
var pending_choice: String = ""


func reset() -> void:
	acquired_cards.clear()
	upgraded_cards.clear()
	removed_starting_cards.clear()
	pending_card = null
	upgrades_remaining = 0
	upgraded_this_event.clear()
	card_offers.clear()
	pending_choice = ""


# Detached serialization-shaped snapshot: no mutable arrays, dictionaries or CardData aliases.
func snapshot() -> Dictionary:
	var levels: Dictionary = {}
	for key in upgraded_cards: levels[key] = upgraded_cards[key].upgrade_level
	return {"acquired": _ids(acquired_cards), "removed": removed_starting_cards.keys(),
		"upgrades": levels, "pending_choice": pending_choice, "offers": _ids(card_offers),
		"pending_card": pending_card.identity_key() if pending_card != null else "",
		"upgrades_remaining": upgrades_remaining, "upgraded_this_event": upgraded_this_event.keys()}


# Same card-choice precedence and exact draw order; the coordinator owns non-card rewards.
func start_card_reward(profile: Resource, rules: Resource, rng: RandomNumberGenerator, minimum_tier: int) -> String:
	pending_choice = "card"
	card_offers = random_card_offers(profile, rules, rng, minimum_tier)
	if card_offers.is_empty():
		pending_choice = ""
		return "\nNo unowned cards meet this reward's minimum tier."
	return ""


func _ids(cards: Array[Resource]) -> Array[String]:
	var result: Array[String] = []
	for card in cards: result.append(card.identity_key())
	return result


func player_pool(profile: Resource) -> Array[Resource]:
	var result: Array[Resource] = []
	var starting: Array = (
		profile.starting_cards if not profile.starting_cards.is_empty() else Cards.CARDS
	)
	var seen: Dictionary = {}
	var retained: Array = []
	for card in starting:
		if not removed_starting_cards.has(card.identity_key()):
			retained.append(card)
	for card in retained + acquired_cards:
		var key: String = card.identity_key()
		if seen.has(key):
			continue
		seen[key] = true
		result.append(upgraded_cards.get(key, card))
	return result


func acquired_draw_weights(rules: Resource) -> Dictionary:
	var result: Dictionary = {}
	for card in acquired_cards:
		result[card.identity_key()] = rules.acquired_card_draw_weight
	return result


func available_reward_cards(profile: Resource, minimum_tier: int = 1) -> Array[Resource]:
	var owned: Dictionary = {}
	for card in player_pool(profile):
		owned[card.identity_key()] = true
	var candidates: Array[Resource] = []
	for card in Cards.CARDS:
		if card.tier >= minimum_tier and card.signature_ship < 0 and not owned.has(card.identity_key()):
			candidates.append(card)
	return candidates


func random_card_offers(profile: Resource, rules: Resource, rng: RandomNumberGenerator, minimum_tier: int = 1) -> Array[Resource]:
	var candidates: Array[Resource] = available_reward_cards(profile, minimum_tier)
	var offers: Array[Resource] = []
	for slot in range(mini(3, candidates.size())):
		var preferred_tier: int = 2 if rng.randf() < rules.reward_tier_two_chance else 1
		var bucket: Array[Resource] = []
		for card in candidates:
			if card.tier == preferred_tier:
				bucket.append(card)
		if bucket.is_empty():
			bucket.assign(candidates)
		var chosen: Resource = bucket[rng.randi_range(0, bucket.size() - 1)]
		offers.append(chosen)
		candidates.erase(chosen)
	return offers


func deck_limit(profile: Resource, rules: Resource) -> int:
	# Never invalidate the existing starting pool if a custom configuration is too small.
	return maxi(profile.starting_cards.size(), maxi(1, rules.max_deck_identities))


func upgrade_candidates(profile: Resource) -> Array[Resource]:
	var result: Array[Resource] = []
	for card in player_pool(profile):
		if pending_choice == "upgrade" and upgraded_this_event.has(card.identity_key()):
			continue
		if card.upgrade_level < mini(2, mini(card.max_upgrades, card.upgrade_effects.size())):
			result.append(card)
	return result


# Valid offer commits either acquisition or a fixed pending replacement, never both.
func choose_card(index: int, profile: Resource, rules: Resource) -> Dictionary:
	if pending_choice != "card" or index < 0 or index >= card_offers.size():
		return {}
	var chosen: Resource = card_offers[index]
	for card in player_pool(profile):
		if card.identity_key() == chosen.identity_key():
			return {}
	if player_pool(profile).size() >= deck_limit(profile, rules):
		pending_card = chosen
		pending_choice = "replace"
		card_offers.clear()
		return {"message": "", "deck_changed": false}
	return {"message": _acquire_card(chosen, rules), "deck_changed": true}


func _acquire_card(chosen: Resource, rules: Resource) -> String:
	var message: String = ""
	acquired_cards.append(chosen)
	message += (
		"\nAcquired %s: added to your expedition pool (×%.1f draw weight within rarity)."
		% [chosen.card_name, rules.acquired_card_draw_weight]
	)
	pending_choice = ""
	pending_card = null
	card_offers.clear()

	return message


func replace_card(key: String, profile: Resource, rules: Resource) -> Dictionary:
	var message: String = ""
	if pending_choice != "replace" or pending_card == null:
		return {}
	var owned: Dictionary = {}
	for card in player_pool(profile):
		owned[card.identity_key()] = card
	if not owned.has(key) or owned.has(pending_card.identity_key()):
		return {}
	# No mutation until the explicit confirmation reaches this validated method.
	removed_starting_cards[key] = true
	for index in range(acquired_cards.size() - 1, -1, -1):
		if acquired_cards[index].identity_key() == key:
			acquired_cards.remove_at(index)
	upgraded_cards.erase(key)
	message += "\nRemoved %s." % owned[key].card_name
	message += _acquire_card(pending_card, rules)
	return {"message": message, "deck_changed": true}


func decline_card() -> Dictionary:
	var message: String = ""
	if pending_choice != "replace" or pending_card == null:
		return {}
	message += "\nKept current deck; new card declined."
	pending_card = null
	pending_choice = ""
	card_offers.clear()
	return {"message": message, "deck_changed": false}


# One level per identity per event; exhaustion closes the event atomically.
func choose_upgrade(key: String, profile: Resource) -> Dictionary:
	var message: String = ""
	if pending_choice != "upgrade":
		return {}
	for card in upgrade_candidates(profile):
		if card.identity_key() != key:
			continue
		var copy: Resource = card.with_upgrade(card.upgrade_level + 1)
		upgraded_cards[key] = copy
		message += (
			"\nUpgraded %s: %s (cost unchanged; player only)." % [copy.card_name, copy.description]
		)
		upgraded_this_event[key] = true
		upgrades_remaining = maxi(0, upgrades_remaining - 1)
		if upgrades_remaining == 0 or upgrade_candidates(profile).is_empty():
			finish_upgrades(profile)
		return {"message": message, "deck_changed": true}
	return {}


func start_upgrade_event(count: int, profile: Resource) -> String:
	var message: String = ""
	upgraded_this_event.clear()
	upgrades_remaining = mini(maxi(0, count), upgrade_candidates(profile).size())
	pending_choice = "upgrade" if upgrades_remaining > 0 else ""
	if upgrades_remaining == 0:
		message += "\nNo eligible card upgrades remain."

	return message


func finish_upgrades(profile: Resource) -> bool:
	if upgrades_remaining > 0 and not upgrade_candidates(profile).is_empty():
		return false
	if pending_choice != "upgrade":
		return false
	pending_choice = ""
	upgrades_remaining = 0
	upgraded_this_event.clear()

	return true


# Only the save codec calls this, after validating the version-1 shape and card registry.
# No rolls, rewards, signals or currency changes occur while restoring a checkpoint.
func restore(data: Dictionary, cards: Dictionary) -> void:
	reset()
	pending_choice = data.pending_choice
	upgrades_remaining = int(data.upgrades_remaining)
	for id in data.acquired: acquired_cards.append(cards[id])
	for id in data.removed: removed_starting_cards[id] = true
	for id in data.upgrades: upgraded_cards[id] = cards[id].with_upgrade(int(data.upgrades[id]))
	for id in data.upgraded_this_event: upgraded_this_event[id] = true
	for id in data.offers: card_offers.append(cards[id])
	pending_card = cards.get(data.pending_card)
