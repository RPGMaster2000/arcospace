extends "res://tests/combat_balance_audit.gd"
## Run with the storm-only gameplay revision. One shard per named variant.

const DECK_SWAPS = {
	"Ganymede": [preload("res://cards/06_shield_disruptor.tres"), preload("res://cards/47_siege_charges.tres")],
	"Thunderbolt": [preload("res://cards/44_desperate_conversion.tres"), preload("res://cards/53_capacitor_overload.tres")],
}
const CARD_VARIANTS = {
	"fabrication": preload("res://cards/70_fabrication_strike.tres"),
	"infiltration": preload("res://cards/74_command_infiltration.tres"),
	"boarding": preload("res://cards/80_boarding_operations.tres"),
}
const ENEMY_VARIANTS = {"choir": "The Hollow Choir", "rustjack": "Rustjack"}
const SHIP_VARIANTS = {"ganymede_deck": "Ganymede", "ganymede_reactor": "Ganymede",
	"ganymede_both": "Ganymede", "thunderbolt": "Thunderbolt"}

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 4:
		push_error("Arguments: output path, variant, first seed, last seed")
		quit(2)
		return
	var variant := args[1]
	var first := int(args[2])
	var last := int(args[3])
	if not (SHIP_VARIANTS.has(variant) or CARD_VARIANTS.has(variant) or ENEMY_VARIANTS.has(variant) or variant == "progressed_boss") or first < 1 or last < first:
		push_error("Invalid candidate shard arguments")
		quit(2)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Unable to open " + args[0])
		quit(2)
		return
	var enemies: Array = []
	for enemy in Config.enemy_ships + Ships.ENEMIES + [Config.progression.mandatory_boss_profile()]:
		if enemy not in enemies: enemies.append(enemy)
	var card: Resource = CARD_VARIANTS.get(variant)
	var replacement: Resource
	if card != null:
		replacement = card.duplicate(true)
		replacement.set_meta("card_identity", card.identity_key())
		if variant == "boarding":
			replacement.effects.steal.crew = 3
		else:
			replacement.cost = 16
	var modifiers := range(Modifier.NAMES.size()) if SHIP_VARIANTS.has(variant) else [0, 2, 6, 7]
	file.store_line(JSON.stringify({"type": "config", "revision": source_revision(), "variant": variant,
		"first_seed": first, "last_seed": last, "modifier_ids": modifiers, "engine": Engine.get_version_info().string}))
	var count := 0
	for original in Ships.PLAYERS:
		if SHIP_VARIANTS.has(variant) and original.ship_name != SHIP_VARIANTS[variant]: continue
		var player: Resource = original
		if SHIP_VARIANTS.has(variant):
			player = original.duplicate()
			if variant in ["ganymede_deck", "ganymede_both", "thunderbolt"]:
				var swap: Array = DECK_SWAPS[original.ship_name]
				player = replace_card(player, swap[0], swap[1])
			if variant in ["ganymede_reactor", "ganymede_both"]:
				player.reactor = 2
		elif card != null:
			player = replace_card(original, card, replacement)
		for policy in POLICIES:
			var settings: Dictionary = POLICIES[policy].duplicate(true)
			for original_enemy in enemies:
				var enemy: Resource = original_enemy
				if variant == "progressed_boss" and enemy != Config.progression.mandatory_boss_profile():
					continue
				if ENEMY_VARIANTS.has(variant):
					if enemy.ship_name != ENEMY_VARIANTS[variant]: continue
					enemy = original_enemy.duplicate()
					enemy.shields = 2 if variant == "choir" else 6
				elif card != null:
					enemy = replace_card(original_enemy, card, replacement)
					if player == original and enemy == original_enemy: continue
				settings.emp_bonus = Config.defense_tuning.mothership_emp_bonus if enemy.enemy_rank == 2 else 0
				if variant == "progressed_boss":
					settings.progression = progressed_cards(player)
				for kind in modifiers:
					var metrics := {}
					var reference_metrics := {}
					settings.cards = metrics
					for seed_value in range(first, last + 1):
						var row := play_match(player, enemy, kind, seed_value, settings)
						row.policy = policy
						row.type = "match"
						file.store_line(JSON.stringify(row))
						count += 1
						if card != null and player != original:
							var reference := settings.duplicate()
							reference.cards = reference_metrics
							play_match(original, original_enemy, kind, seed_value, reference)
					if card != null:
						file.store_line(JSON.stringify({"type": "cards", "player": player.ship_name,
							"policy": policy, "card": metrics.get(card.identity_key(), {}),
							"reference": reference_metrics.get(card.identity_key(), {})}))
		file.flush()
	file.store_line(JSON.stringify({"type": "complete", "matches": count}))
	file.close()
	print("%s: %d battles complete" % [variant, count])
	quit()

func replace_card(profile: Resource, original: Resource, replacement: Resource) -> Resource:
	var slot: int = profile.starting_cards.find(original)
	if slot < 0 and profile.signature_card != original:
		return profile
	var copy := profile.duplicate()
	copy.starting_cards = profile.starting_cards.duplicate()
	if slot >= 0:
		copy.starting_cards[slot] = replacement
	if profile.signature_card == original:
		copy.signature_card = replacement
	return copy

func progressed_cards(player: Resource) -> Dictionary:
	# Model three acquisitions and three upgrade levels using the normal draw weight.
	# Upgrade one starting card per family, preferring early, affordable cards.
	var acquired: Array[Resource] = []
	var upgrades := {}
	for family in Rules.RESOURCES:
		for card in Cards.CARDS:
			if card.family == family and card.tier == 1 and card.cost >= 4 and card.signature_ship < 0 and card not in player.starting_cards:
				acquired.append(card)
				break
		for card in player.starting_cards:
			if card.family == family and card.tier == 1 and card.cost >= 4 and card.signature_ship < 0 and not card.upgrade_effects.is_empty():
				upgrades[card.identity_key()] = card.with_upgrade(1)
				break
	assert(acquired.size() == 3 and upgrades.size() == 3)
	return {"acquired": acquired, "upgrades": upgrades}
