extends "res://tests/combat_balance_audit.gd"

const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const CHOIR = ["The Hollow Choir", "Choir Spore", "Choir Guardian", "Choir Leviathan"]
const SENTINEL = ["Bastion Frigate", "Siege Monitor"]
const VALIDATION = ["The Hollow Choir", "Choir Guardian"]
const VARIANTS = {
	"offense": ["tactical_weights", "damage", 1.25],
	"repair": ["tactical_weights", "hull", 1.05],
	"draw": ["card_effect_weights", "hull", 1.05],
	"economy": ["tactical_weights", "production", 2.8],
	"sentinel-offense": ["tactical_weights", "damage", 1.35],
}


func roster() -> Array:
	var unique := {}
	for enemy in Factions.ships(Config) + Config.enemy_ships + Ships.ENEMIES + [Config.progression.mandatory_boss_profile()]:
		unique[enemy.resource_path] = enemy
	return unique.values()


func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 5:
		push_error("Arguments: output file, ship index (-1 for all), first seed, last seed, full/choir/sentinel/validation or named variant")
		quit(2)
		return
	var selected := int(args[1])
	var first := int(args[2])
	var last := int(args[3])
	var variant := args[4]
	if selected < -1 or selected >= Ships.PLAYERS.size() or first < 1 or last < first or (variant not in ["full", "choir", "sentinel", "validation"] and not VARIANTS.has(variant)):
		push_error("Invalid enemy audit shard arguments")
		quit(2)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Unable to open " + args[0])
		quit(2)
		return
	var enemies := roster()
	if variant != "full":
		var names := SENTINEL if variant.begins_with("sentinel") else CHOIR
		if variant == "validation":
			names = VALIDATION
		enemies = enemies.filter(func(enemy): return enemy.ship_name in names)
	var profiles := enemies.map(func(enemy):
		return {"name": enemy.ship_name, "rank": enemy.enemy_rank, "resource": enemy.resource_path,
			"hull": enemy.hull_capacity, "shields": enemy.shields, "crew": enemy.crew, "quarters": enemy.quarters})
	file.store_line(JSON.stringify({"type": "config", "revision": source_revision(), "engine": Engine.get_version_info().string,
		"variant": variant, "adjustment": VARIANTS.get(variant, []), "selected_ship": selected,
		"first_seed": first, "last_seed": last, "policy_filter": "all", "ships": Ships.PLAYERS.map(func(ship): return ship.ship_name),
		"enemies": profiles, "modifiers": Modifier.NAMES, "policies": POLICIES, "round_limit": ROUND_LIMIT,
		"action_limit": ACTION_LIMIT, "failure_turns": failure_turns, "boss_emp_bonus": Config.defense_tuning.mothership_emp_bonus}))
	var count := 0
	for i in Ships.PLAYERS.size():
		if selected >= 0 and selected != i: continue
		var player: Resource = Ships.PLAYERS[i]
		for policy in POLICIES:
			var settings: Dictionary = POLICIES[policy].duplicate(true)
			settings.cards = {}
			for base in enemies:
				var enemy: Resource = base
				if VARIANTS.has(variant):
					var adjustment: Array = VARIANTS[variant]
					var weights: Dictionary = base.get(adjustment[0]).duplicate()
					weights[adjustment[1]] = adjustment[2]
					enemy = base.duplicate()
					enemy.set(adjustment[0], weights)
					enemy.set_meta("audit_resource", base.resource_path)
				settings.enemy_cards = {}
				settings.emp_bonus = Config.defense_tuning.mothership_emp_bonus if enemy.enemy_rank == 2 else 0
				for kind in Modifier.NAMES.size():
					for seed_value in range(first, last + 1):
						var result := play_match(player, enemy, kind, seed_value, settings)
						result.type = "match"
						result.policy = policy
						file.store_line(JSON.stringify(result))
						count += 1
				file.store_line(JSON.stringify({"type": "enemy_cards", "player": player.ship_name,
					"enemy": base.ship_name, "policy": policy, "cards": settings.enemy_cards}))
			file.store_line(JSON.stringify({"type": "cards", "player": player.ship_name, "policy": policy, "cards": settings.cards}))
			file.flush()
			print("%s / %s / %s: %d battles complete" % [variant, player.ship_name, policy, count])
	file.store_line(JSON.stringify({"type": "complete", "matches": count}))
	file.close()
	quit()
