extends "res://tests/full_enemy_balance.gd"

const Preferences = preload("res://scripts/cards/card_preferences.gd")


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected a deck inventory output path")
		quit(2)
		return
	var output := FileAccess.open(args[0], FileAccess.WRITE)
	if output == null:
		push_error("Cannot write " + args[0])
		quit(2)
		return
	var faction_names := {}
	for faction in Factions.eligible(Config):
		for ship in Factions.roster(faction) + faction.elite_roster + [faction.mothership]:
			if ship != null:
				faction_names[ship.resource_path] = faction.id
	var definitions := {}
	var profiles := {}
	for profile in roster():
		var pool: Array = profile.starting_cards if not profile.starting_cards.is_empty() else Cards.BASE_CARDS
		var cards: Array[String] = []
		for card in pool:
			var id: String = card.identity_key()
			cards.append(id)
			definitions[id] = {"name": card.card_name, "cost": card.cost, "family": card.family,
				"tier": card.tier, "allocation": card.allocation_category, "description": card.description,
				"tags": Preferences.categories(card), "effects": card.effects}
		profiles[profile.ship_name] = {"faction": faction_names.get(profile.resource_path, "legacy"),
			"role": profile.subtitle, "summary": profile.summary, "rank": profile.enemy_rank,
			"starting_state": state(profile), "fallback": profile.starting_cards.is_empty(), "cards": cards,
			"family_weights": profile.card_family_weights, "effect_weights": profile.card_effect_weights,
			"tactics": profile.tactical_weights, "tactical_variation": profile.tactical_variation}
	output.store_string(JSON.stringify({"revision": source_revision(), "profiles": profiles, "cards": definitions}))
	output.close()
	quit()
