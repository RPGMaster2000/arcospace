extends RefCounted

const Expedition = preload("res://scripts/expedition_state.gd")
const Preferences = preload("res://scripts/cards/card_preferences.gd")
const STRATEGIES = ["offense", "defense", "economy", "balanced"]
const STAGES = {
	"boss-early": {"system": 1, "acquisitions": 1, "upgrades": 1, "production": [], "hull_fraction": 0.90,
		"bonuses": {"materials": 2}},
	"boss-middle": {"system": 6, "acquisitions": 3, "upgrades": 3, "production": ["reactor"], "hull_fraction": 0.88,
		"bonuses": {"energy": 4, "shields": 3}},
	"boss-later": {"system": 12, "acquisitions": 5, "upgrades": 5, "production": ["reactor", "quarters"], "hull_fraction": 0.85,
		"bonuses": {"energy": 4, "materials": 4, "shields": 5}},
}

static func scenario(mode: String) -> Dictionary:
	var parts := mode.split("-")
	if parts.size() <= 2:
		return STAGES.get(mode, {})
	var stage: Dictionary = STAGES.get("-".join(parts.slice(0, 2)), {}).duplicate(true)
	if stage.is_empty() or parts[2] not in STRATEGIES or parts.size() > 4:
		return {}
	stage.strategy = parts[2]
	if parts.size() == 4:
		if parts[1] != "later" or parts[2] != "balanced":
			return {}
		match parts[3]:
			"fixed":
				stage.enemy_system = 1
			"starter":
				stage.merge({"acquisitions": 0, "upgrades": 0, "production": [], "hull_fraction": 1.0, "bonuses": {}}, true)
			_:
				return {}
	return stage


static func preferred(cards: Array, strategy: String, index: int) -> Array:
	var role: String = STRATEGIES[index % 3] if strategy == "balanced" else strategy
	return cards.filter(func(card):
		if role == "economy":
			var categories := Preferences.categories(card)
			return card.allocation_category == "systems" and ("economy" in categories or "production" in categories)
		return card.allocation_category == role)


static func build(ship_index: int, rules: Resource, stage: Dictionary) -> RefCounted:
	var expedition := Expedition.new()
	expedition.start(ship_index, rules, 73501 + ship_index)
	expedition.system_number = stage.system
	var player: Resource = expedition.ship()
	var strategy: String = stage.get("strategy", "")
	expedition.hull = roundi(player.hull_capacity * stage.hull_fraction)
	for index in stage.acquisitions:
		expedition.card_offers = expedition.random_card_offers(2 if index > 1 else 1)
		assert(not expedition.card_offers.is_empty())
		var selection := 0
		var offers: Array = expedition.card_offers
		var fitting := preferred(offers, strategy, index) if not strategy.is_empty() else offers.filter(func(card): return card.effects.has("damage"))
		if not fitting.is_empty():
			selection = offers.find(fitting[0])
		expedition.pending_choice = "card"
		assert(expedition.choose_card(selection) or expedition.pending_choice == "replace")
		if expedition.pending_choice == "replace":
			var removable := expedition.player_pool().filter(func(card): return card.signature_ship < 0 and card.effects.has("hull"))
			assert(not removable.is_empty() and expedition.replace_card(removable[0].identity_key()))
	for index in stage.upgrades:
		expedition.start_upgrade_event(1)
		var candidates := expedition.upgrade_candidates()
		var fitting := preferred(candidates, strategy, index) if not strategy.is_empty() else candidates.filter(func(card): return card.effects.has("damage"))
		var choice: Resource = fitting[index % fitting.size()] if not fitting.is_empty() else candidates[0]
		assert(expedition.choose_upgrade(choice.identity_key()))
	for key in stage.production:
		expedition.pending_choice = "production"
		expedition.choice_amount = 1
		assert(expedition.choose_attribute(key))
	expedition.add_modifiers(stage.bonuses)
	return expedition.prepare_battle()
