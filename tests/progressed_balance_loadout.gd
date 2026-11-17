extends RefCounted

const Expedition = preload("res://scripts/expedition_state.gd")
const STAGES = {
	"boss-early": {"system": 1, "acquisitions": 1, "upgrades": 1, "production": [], "hull_fraction": 0.90,
		"bonuses": {"materials": 2}},
	"boss-middle": {"system": 6, "acquisitions": 3, "upgrades": 3, "production": ["reactor"], "hull_fraction": 0.88,
		"bonuses": {"energy": 4, "shields": 3}},
	"boss-later": {"system": 12, "acquisitions": 5, "upgrades": 5, "production": ["reactor", "quarters"], "hull_fraction": 0.85,
		"bonuses": {"energy": 4, "materials": 4, "shields": 5}},
}


static func build(ship_index: int, rules: Resource, stage: Dictionary) -> RefCounted:
	var expedition := Expedition.new()
	expedition.start(ship_index, rules, 73501 + ship_index)
	expedition.system_number = stage.system
	var player: Resource = expedition.ship()
	expedition.hull = roundi(player.hull_capacity * stage.hull_fraction)
	for index in stage.acquisitions:
		expedition.card_offers = expedition.random_card_offers(2 if index > 1 else 1)
		assert(not expedition.card_offers.is_empty())
		var selection := 0
		for slot in expedition.card_offers.size():
			if expedition.card_offers[slot].effects.has("damage"):
				selection = slot
				break
		expedition.pending_choice = "card"
		assert(expedition.choose_card(selection) or expedition.pending_choice == "replace")
		if expedition.pending_choice == "replace":
			var removable := expedition.player_pool().filter(func(card): return card.signature_ship < 0 and card.effects.has("hull"))
			assert(not removable.is_empty() and expedition.replace_card(removable[0].identity_key()))
	for index in stage.upgrades:
		expedition.start_upgrade_event(1)
		var candidates := expedition.upgrade_candidates()
		var attacks := candidates.filter(func(card): return card.effects.has("damage"))
		var choice: Resource = attacks[index % attacks.size()] if not attacks.is_empty() else candidates[0]
		assert(expedition.choose_upgrade(choice.identity_key()))
	for key in stage.production:
		expedition.pending_choice = "production"
		expedition.choice_amount = 1
		assert(expedition.choose_attribute(key))
	expedition.add_modifiers(stage.bonuses)
	return expedition.prepare_battle()
