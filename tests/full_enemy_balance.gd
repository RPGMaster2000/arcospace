extends "res://tests/combat_balance_audit.gd"

const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Progressed = preload("res://tests/progressed_balance_loadout.gd")
const FactionBalance = preload("res://tests/faction_balance_scenarios.gd")
const CHOIR = ["The Hollow Choir", "Choir Spore", "Choir Guardian", "Choir Leviathan"]
const SENTINEL = ["Bastion Frigate", "Siege Monitor"]
const VALIDATION = ["The Hollow Choir", "Choir Guardian"]
const DECISIVE_DECKS = {
	"Bastion Frigate": ["45_emergency_bulkheads", "28_breach_charge"],
	"Siege Monitor": ["45_emergency_bulkheads", "47_siege_charges"],
	"Choir Spore": ["45_emergency_bulkheads", "17_shield_breachers"],
	"The Hollow Choir": ["45_emergency_bulkheads", "80_boarding_operations"],
	"Choir Guardian": ["45_emergency_bulkheads", "17_shield_breachers"],
}
const DECISIVE_MODES = {
	"decisive-deck": DECISIVE_DECKS,
	"decisive-deck-alt": {
		"Bastion Frigate": ["45_emergency_bulkheads", "20_torpedo_salvo"],
		"Siege Monitor": ["45_emergency_bulkheads", "28_breach_charge"],
	},
	"decisive-affordable": {
		"Bastion Frigate": ["45_emergency_bulkheads", "28_breach_charge"],
		"Siege Monitor": ["45_emergency_bulkheads", "16_missile_team"],
		"The Hollow Choir": ["45_emergency_bulkheads", "23_cargo_raid"],
		"Choir Spore": ["09_hull_nanobots", "23_cargo_raid"],
	},
	"decisive-shields": {"Bastion Frigate": 1.5, "Siege Monitor": 1.5},
	"decisive-production": {"Bastion Frigate": 2.5, "Siege Monitor": 2.5},
	"decisive-spore-trim": {"Choir Spore": ["09_hull_nanobots", ""]},
	"decisive-spore-hull": {"Choir Spore": ["09_hull_nanobots", "80_boarding_operations"]},
}
const VARIANTS = {
	"offense": ["tactical_weights", "damage", 1.25],
	"repair": ["tactical_weights", "hull", 1.05],
	"draw": ["card_effect_weights", "hull", 1.05],
	"economy": ["tactical_weights", "production", 2.8],
	"sentinel-offense": ["tactical_weights", "damage", 1.35],
	"sentinel-draw": ["card_effect_weights", "hull", 1.4],
}


func roster() -> Array:
	var unique := {}
	for enemy in Factions.ships(Config) + Config.enemy_ships + Ships.ENEMIES + [Config.progression.mandatory_boss_profile()]:
		unique[enemy.resource_path] = enemy
	return unique.values()

func decisive_profile(base: Resource, mode: String) -> Resource:
	var adjustment = DECISIVE_MODES[mode][base.ship_name]
	var enemy := base.duplicate()
	enemy.set_meta("audit_resource", base.resource_path)
	if adjustment is Array:
		var deck: Array[Resource] = base.starting_cards.duplicate()
		var path := "res://cards/%s.tres" % adjustment[0]
		var index := deck.find(load(path))
		assert(index >= 0, "Missing card to replace: " + path)
		if adjustment[1].is_empty():
			deck.remove_at(index)
		else:
			var replacement: Resource = load("res://cards/%s.tres" % adjustment[1])
			assert(replacement != null and not deck.has(replacement))
			deck[index] = replacement
		enemy.starting_cards = deck
	elif mode == "decisive-shields":
		enemy.card_effect_weights = base.card_effect_weights.duplicate()
		enemy.card_effect_weights.shields = adjustment
	else:
		enemy.tactical_weights = base.tactical_weights.duplicate()
		enemy.tactical_weights.production = adjustment
	return enemy

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 5 or args.size() > 7:
		push_error("Arguments: output file, ship index (-1 for all), first seed, last seed, mode, optional policies and enemies (comma-separated)")
		quit(2)
		return
	var selected := int(args[1])
	var first := int(args[2])
	var last := int(args[3])
	var variant := args[4]
	var filter := args[5] if args.size() >= 6 else "all"
	var policies: Array = POLICIES.keys() if filter == "all" else Array(filter.split(","))
	var stage := Progressed.scenario(variant)
	var faction_arm: Dictionary = FactionBalance.ARMS.get(variant, {})
	var expedition_pool := OS.get_environment("ARCOSPACE_AUDIT_EXPEDITION_POOL") == "1"
	var valid_mode := variant in ["full", "choir", "sentinel", "validation", "decisive-focus"] or VARIANTS.has(variant) or DECISIVE_MODES.has(variant) or not stage.is_empty() or not faction_arm.is_empty()
	if selected < -1 or selected >= Ships.PLAYERS.size() or first < 1 or last < first or not valid_mode:
		push_error("Invalid enemy audit shard arguments")
		quit(2)
		return
	if policies.any(func(policy): return not POLICIES.has(policy) or policies.count(policy) != 1):
		push_error("Policies must be unique names from the existing audit")
		quit(2)
		return
	var revision := source_revision()
	var production_ref := OS.get_environment("ARCOSPACE_AUDIT_PRODUCTION_REF")
	if not production_ref.is_empty():
		var status := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "diff", "--quiet",
			production_ref, "--", ".", ":(exclude)tests", ":(exclude)tools", ":(exclude)docs"])
		if status != 0:
			push_error("Production files differ from the requested audit revision")
			quit(2)
			return
		revision = production_ref
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Unable to open " + args[0])
		quit(2)
		return
	var enemies := roster()
	if not stage.is_empty():
		enemies = enemies.filter(func(enemy): return enemy.enemy_rank == 2)
		for index in enemies.size():
			var base: Resource = enemies[index]
			enemies[index] = Config.progression.scaled_enemy(base, stage.get("enemy_system", stage.system), true)
			enemies[index].set_meta("audit_resource", base.resource_path)
	elif not faction_arm.is_empty():
		enemies = enemies.filter(func(enemy): return faction_arm.has(enemy.ship_name))
	elif DECISIVE_MODES.has(variant):
		enemies = enemies.filter(func(enemy): return DECISIVE_MODES[variant].has(enemy.ship_name))
	elif variant == "decisive-focus":
		enemies = enemies.filter(func(enemy): return DECISIVE_DECKS.has(enemy.ship_name))
	elif variant != "full":
		var names := SENTINEL if variant.begins_with("sentinel") else CHOIR
		if variant == "validation":
			names = VALIDATION
		enemies = enemies.filter(func(enemy): return enemy.ship_name in names)
	if args.size() == 7:
		var selected_enemies := args[6].split(",")
		enemies = enemies.filter(func(enemy): return enemy.ship_name in selected_enemies)
		if enemies.size() != selected_enemies.size():
			push_error("Enemy filter must contain unique names from the selected mode")
			file.close()
			quit(2)
			return
	var profiles := enemies.map(func(enemy):
		return {"name": enemy.ship_name, "rank": enemy.enemy_rank, "resource": enemy.get_meta("audit_resource", enemy.resource_path),
			"hull": enemy.hull_capacity, "shields": enemy.shields, "crew": enemy.crew, "quarters": enemy.quarters})
	var config_row := {"type": "config", "revision": revision, "engine": Engine.get_version_info().string,
		"variant": variant, "adjustment": faction_arm if not faction_arm.is_empty() else DECISIVE_MODES.get(variant, VARIANTS.get(variant, [])), "selected_ship": selected,
		"first_seed": first, "last_seed": last, "policy_filter": filter, "ships": Ships.PLAYERS.map(func(ship): return ship.ship_name),
		"enemies": profiles, "modifiers": Modifier.NAMES, "policies": POLICIES, "round_limit": ROUND_LIMIT,
		"action_limit": ACTION_LIMIT, "failure_turns": failure_turns, "boss_emp_bonus": Config.defense_tuning.mothership_emp_bonus}
	if expedition_pool:
		config_row.expedition_pool = true
	var loadouts: Array = []
	if not stage.is_empty():
		config_row.stage = stage
		config_row.loadouts = {}
		for index in Ships.PLAYERS.size():
			var setup := Progressed.build(index, Config, stage)
			loadouts.append(setup)
			config_row.loadouts[Ships.PLAYERS[index].ship_name] = {"starting_state": setup.player_state.snapshot(),
				"cards": setup.player_cards.map(func(card): return {"id": card.identity_key(), "name": card.card_name}),
				"acquired_weights": setup.identity_weights}
	file.store_line(JSON.stringify(config_row))
	file.flush()
	var count := 0
	for i in Ships.PLAYERS.size():
		if selected >= 0 and selected != i: continue
		var player: Resource = Ships.PLAYERS[i]
		for policy in policies:
			var settings: Dictionary = POLICIES[policy].duplicate(true)
			if expedition_pool:
				settings.expedition_pool = true
			if not stage.is_empty():
				settings.battle_setup = loadouts[i]
			settings.cards = {}
			for base in enemies:
				var enemy: Resource = base
				if not faction_arm.is_empty():
					enemy = FactionBalance.adjusted(base, faction_arm[base.ship_name])
				elif DECISIVE_MODES.has(variant):
					enemy = decisive_profile(base, variant)
				elif VARIANTS.has(variant):
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
