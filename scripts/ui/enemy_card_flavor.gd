extends RefCounted
## Presentation aliases only. Resources, identities, effects and player names stay intact.
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const TITLES = {
	"hollow_choir":
	{
		"42_overloaded_warhead": "Rupture Brood",
		"47_siege_charges": "Ravenous Lunge",
		"49_salvage_cannibalization": "Flesh Regrowth",
		"16_missile_team": "Spinal Volley"
	},
	"iron_directorate": {"49_salvage_cannibalization": "Armor Salvage"},
	"axiom_collective":
	{"19_system_disruption": "System Interdict", "06_shield_disruptor": "Shield Nullifier"},
	"scavenger_clans":
	{"42_overloaded_warhead": "Jury-Rigged Warhead", "36_salvage_strike": "Scrap Strike"}
}


static func faction(ship: Resource) -> String:
	if ship == null:
		return ""
	# Scaled profiles are copies, so compare their retained name to catalog entries.
	for profile in Factions.DEFAULTS:
		var roster: Array = profile.standard_roster + profile.elite_roster
		if profile.mothership != null:
			roster.append(profile.mothership)
		for candidate in roster:
			if candidate.ship_name == ship.ship_name:
				return profile.id
	return ""


static func title(card: Resource, ship: Resource) -> String:
	if card == null:
		return ""
	var base: Resource = card.get_meta("inspection_base", card)
	var key: String = base.identity_key().get_file().get_basename()
	var alias: String = TITLES.get(faction(ship), {}).get(key, "")
	return card.card_name if alias.is_empty() else alias + "+".repeat(card.upgrade_level)
