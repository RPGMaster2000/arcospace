extends RefCounted
# RESPONSIBILITY: Own persistent card identities and card reward/upgrade transactions.
# DOES NOT: Hold expedition/Board references, spend currency, resolve encounters or save.
# Context and the authoritative reward RNG are supplied by ExpeditionState per operation.
const Preferences = preload("res://scripts/cards/card_preferences.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const GANYMEDE = preload("res://ships/player/ganymede.tres")
const GANYMEDE_LEGACY_CARD = preload("res://cards/06_shield_disruptor.tres")
const GANYMEDE_NEW_CARD = preload("res://cards/47_siege_charges.tres")
const THUNDERBOLT = preload("res://ships/player/thunderbolt.tres")
const THUNDERBOLT_LEGACY_CARD = preload("res://cards/44_desperate_conversion.tres")
const THUNDERBOLT_NEW_CARD = preload("res://cards/53_capacitor_overload.tres")
var acquired_cards: Array[Resource] = []
## Old saves retain their historical starting pool without newly authored signatures.
var signatures_enabled: bool = true
var revised_starting_decks := true
var upgraded_cards: Dictionary = {}
var removed_starting_cards: Dictionary = {}
var pending_card: Resource
var upgrades_remaining: int = 0
var upgraded_this_event: Dictionary = {}
var card_offers: Array[Resource] = []
var pending_choice: String = ""
var batch_active := false
var batch_queue: Array[Resource] = []
var batch_protected: Array[String] = []


func reset() -> void:
	batch_active = false
	batch_queue.clear()
	batch_protected.clear()
	signatures_enabled = true
	revised_starting_decks = true
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
	return {"signatures_enabled": signatures_enabled, "revised_starting_decks": revised_starting_decks,
		"acquired": _ids(acquired_cards), "removed": removed_starting_cards.keys(),
		"upgrades": levels, "pending_choice": pending_choice, "offers": _ids(card_offers),
		"pending_card": pending_card.identity_key() if pending_card != null else "",
		"batch": {"active":batch_active,"queue":_ids(batch_queue),"protected":batch_protected.duplicate()}, "upgrades_remaining": upgrades_remaining, "upgraded_this_event": upgraded_this_event.keys()}


# Same card-choice precedence and exact draw order; the coordinator owns non-card rewards.
func start_card_reward(profile: Resource, rules: Resource, rng: RandomNumberGenerator, minimum_tier: int, rare: bool = false) -> String:
	pending_choice = "card"
	card_offers = random_card_offers(profile, rules, rng, minimum_tier, rare)
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
		profile.starting_cards if not profile.starting_cards.is_empty() else Cards.BASE_CARDS + Cards.PROTOTYPES
	)
	var seen: Dictionary = {}
	var retained: Array = []
	for starting_card in starting:
		var card: Resource = starting_card
		if not revised_starting_decks:
			if profile == GANYMEDE and card == GANYMEDE_NEW_CARD:
				card = GANYMEDE_LEGACY_CARD
			elif profile == THUNDERBOLT and card == THUNDERBOLT_NEW_CARD:
				card = THUNDERBOLT_LEGACY_CARD
		if not removed_starting_cards.has(card.identity_key()) and (signatures_enabled or card.signature_ship < 0):
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


func available_reward_cards(profile: Resource, minimum_tier: int = 1, include_prototype: bool = true) -> Array[Resource]:
	var owned: Dictionary = {}
	for card in player_pool(profile):
		owned[card.identity_key()] = true
	var candidates: Array[Resource] = []
	for card in (Cards.CARDS if include_prototype else Cards.BASE_CARDS):
		if card.tier >= minimum_tier and card.signature_ship < 0 and not owned.has(card.identity_key()):
			candidates.append(card)
	return candidates


func random_card_offers(
	profile: Resource, rules: Resource, rng: RandomNumberGenerator,
	minimum_tier: int = 1, rare: bool = false
) -> Array[Resource]:
	var candidates := available_reward_cards(profile, minimum_tier)
	var ordinary := candidates.filter(func(card): return card.tier < 3)
	var rare_cards := candidates.filter(func(card): return card.tier == 3)
	var reserve_rare := (rare or minimum_tier == 3) and not rare_cards.is_empty()
	var offers: Array[Resource] = []
	for slot in mini(5 - int(reserve_rare), ordinary.size()):
		var tier := 2 if rng.randf() < rules.reward_tier_two_chance else 1
		var bucket := ordinary.filter(func(card): return card.tier == tier)
		if bucket.is_empty():
			bucket = ordinary
		var chosen: Resource = bucket[rng.randi_range(0, bucket.size() - 1)]
		offers.append(chosen)
		ordinary.erase(chosen)
	if reserve_rare:
		offers.append(rare_cards[rng.randi_range(0, rare_cards.size() - 1)])
	return offers


# Extend the built-in roster while retaining its authored decks and prototype entries.
# Keep candidates bounded and rank them using the same preferences as enemy draws.
static func enemy_pool(profile: Resource, system: int, built_in: bool, prefer_affordable: bool = false) -> Array[Resource]:
	var pool: Array[Resource] = []
	pool.assign(profile.starting_cards if profile != null and not profile.starting_cards.is_empty()
		else Cards.BASE_CARDS)
	if profile == null or system < 3 or not built_in:
		return pool
	for tier in [2, 3]:
		if tier == 3 and profile.enemy_rank == 0 and system < 5:
			break
		var candidates: Array = Cards.SYNERGY_CARDS.filter(func(card): return card.tier == tier)
		var weights := {}
		for card in candidates:
			var weight := Preferences.draw_weight(card, profile.card_family_weights, profile.card_effect_weights)
			if prefer_affordable:
				var production: String = {"materials":"synthesizer", "energy":"reactor", "crew":"quarters"}[card.family]
				var budget: float = profile.get(card.family) + profile.get(production) * (1.5 if tier == 2 else 3.0)
				weight *= clampf(budget / maxf(1.0, card.cost), 0.45, 1.0)
			weights[card] = weight
		candidates.sort_custom(func(a, b):
			return a.identity_key() < b.identity_key() if weights[a] == weights[b] else weights[a] > weights[b])
		var limit := 6 if tier == 2 else (2 if profile.enemy_rank == 0 else 3)
		pool.append_array(candidates.slice(0, limit))
	return pool


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
# Uniform draws over every unowned, non-signature Tier 1 identity. Ownership is
# unique in this project, so draw without replacement and never offer duplicates.
func start_card_batch(profile: Resource, rng: RandomNumberGenerator) -> bool:
	if not pending_choice.is_empty() or batch_active: return false
	var candidates: Array[Resource] = []
	for card in available_reward_cards(profile):
		if card.tier == 1: candidates.append(card)
	if candidates.size() < 2: return false
	card_offers.clear()
	for slot in range(2):
		var selected: Resource = candidates[rng.randi_range(0,candidates.size()-1)]
		card_offers.append(selected)
		candidates.erase(selected)
	batch_active = true
	pending_choice = "card_batch"
	return true

func confirm_card_batch(profile: Resource, rules: Resource) -> Dictionary:
	if not batch_active or pending_choice != "card_batch" or card_offers.size() != 2 or player_pool(profile).size() > deck_limit(profile, rules): return {}
	batch_queue.assign(card_offers)
	card_offers.clear()
	pending_choice = ""
	return advance_card_batch(profile,rules)

func advance_card_batch(profile: Resource, rules: Resource) -> Dictionary:
	var result := {"message":"","deck_changed":false}
	if not batch_active or pending_choice == "card_batch" or pending_choice == "replace": return result
	while not batch_queue.is_empty():
		var chosen: Resource = batch_queue.pop_front()
		if player_pool(profile).size() >= deck_limit(profile,rules):
			pending_card = chosen
			pending_choice = "replace"
			return result
		result.message += _acquire_card(chosen,rules)
		result.deck_changed = true
	batch_active = false
	batch_protected.clear()
	return result

func choose_card(index: int, profile: Resource, rules: Resource) -> Dictionary:
	if pending_choice != "card" or index < 0 or index >= card_offers.size():
		return {}
	if player_pool(profile).size() > deck_limit(profile, rules):
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
	if batch_active: batch_protected.append(chosen.identity_key())
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
	if player_pool(profile).size() > deck_limit(profile, rules) or not owned.has(key) or owned.has(pending_card.identity_key()) or key in batch_protected:
		return {}
	# No mutation until the explicit confirmation reaches this validated method.
	_remove_identity(key)
	message += "\nRemoved %s." % owned[key].card_name
	message += _acquire_card(pending_card, rules)
	return {"message": message, "deck_changed": true}


func trim_deck(key: String, profile: Resource, rules: Resource) -> Dictionary:
	if not pending_choice.is_empty() or player_pool(profile).size() <= deck_limit(profile, rules):
		return {}
	for card in player_pool(profile):
		if card.identity_key() == key:
			_remove_identity(key)
			return {"message": "\nRemoved %s." % card.card_name, "deck_changed": true}
	return {}


func _remove_identity(key: String) -> void:
	removed_starting_cards[key] = true
	for index in range(acquired_cards.size() - 1, -1, -1):
		if acquired_cards[index].identity_key() == key:
			acquired_cards.remove_at(index)
	upgraded_cards.erase(key)


func decline_card() -> Dictionary:
	if batch_active: return {}
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
	var batch: Dictionary = data.get("card_batch", {"active":false,"queue":[],"protected":[]})
	batch_active = batch.active
	batch_protected.assign(batch.protected)
	batch_queue.clear()
	for id in batch.queue: batch_queue.append(cards[id])
	signatures_enabled = bool(data.get("signatures_enabled", false))
	revised_starting_decks = data.get("revised_starting_decks", false)
	pending_choice = data.pending_choice
	upgrades_remaining = int(data.upgrades_remaining)
	for id in data.acquired: acquired_cards.append(cards[id])
	for id in data.removed: removed_starting_cards[id] = true
	for id in data.upgrades: upgraded_cards[id] = cards[id].with_upgrade(int(data.upgrades[id]))
	for id in data.upgraded_this_event: upgraded_this_event[id] = true
	for id in data.offers: card_offers.append(cards[id])
	pending_card = cards.get(data.pending_card)
