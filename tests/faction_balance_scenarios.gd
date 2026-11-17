extends RefCounted

const Cards = preload("res://scripts/cards/card_library.gd")
const ARMS = {
	"faction-existing": {
		"Siege Monitor": {"replace": ["res://cards/10_shield_recharge.tres", "res://cards/57_emergency_discharge.tres"]},
		"Choir Spore": {"replace": ["res://cards/09_hull_nanobots.tres", "res://cards/42_overloaded_warhead.tres"]},
		"The Hollow Choir": {"replace": ["res://cards/05_structural_reinforcement.tres", "res://cards/47_siege_charges.tres"]},
		"Choir Guardian": {"replace": ["res://cards/45_emergency_bulkheads.tres", "res://cards/42_overloaded_warhead.tres"]},
		"Sentinel": {"catalog_numbers": [1, 3, 4, 6, 8, 10, 11, 12, 13, 14, 16, 17, 19, 21, 26, 29, 35, 43, 45, 57, 59, 71]},
		"Reclaimer": {"catalog_numbers": [1, 3, 4, 5, 7, 9, 11, 12, 15, 18, 23, 28, 30, 36, 39, 42, 46, 48, 49, 51, 52, 69]},
	},
	"faction-prototypes": {
		"Siege Monitor": {"replace": ["res://cards/10_shield_recharge.tres", "res://tests/fixtures/faction_balance/iron_counterbattery.tres"]},
		"Choir Spore": {"replace": ["res://cards/09_hull_nanobots.tres", "res://tests/fixtures/faction_balance/feeding_lunge.tres"]},
		"The Hollow Choir": {"replace": ["res://cards/05_structural_reinforcement.tres", "res://tests/fixtures/faction_balance/feeding_lunge.tres"]},
		"Choir Guardian": {"replace": ["res://cards/45_emergency_bulkheads.tres", "res://tests/fixtures/faction_balance/feeding_lunge.tres"]},
	},
	"faction-siege-hull": {
		"Siege Monitor": {"replace": ["res://cards/09_hull_nanobots.tres", "res://tests/fixtures/faction_balance/iron_counterbattery.tres"]},
	},
}


static func adjusted(base: Resource, change: Dictionary) -> Resource:
	var deck: Array[Resource] = []
	if change.has("catalog_numbers"):
		for number in change.catalog_numbers:
			var card: Resource = Cards.CARDS[number - 1]
			assert(card.resource_path.get_file().begins_with("%02d_" % number) and card.signature_ship < 0)
			deck.append(card)
	else:
		deck.assign(base.starting_cards)
		var outgoing := deck.find(load(change.replace[0]))
		var incoming: Resource = load(change.replace[1])
		assert(outgoing >= 0 and incoming != null and not deck.has(incoming) and incoming.signature_ship < 0)
		deck[outgoing] = incoming
	var profile := base.duplicate()
	profile.starting_cards = deck
	profile.set_meta("audit_resource", base.resource_path)
	return profile
