extends "res://tests/six_ship_gameplay_simulation.gd"

const POLICIES = {
	"balanced": {"weights": {}, "allocation": "balanced", "emp": false},
	"aggressive": {"weights": {"damage": 2.5, "disruption": 0.7, "production": 2.0}, "allocation": "offense", "emp": false},
	"defensive": {"weights": {"hull": 2.5, "shields": 1.25}, "allocation": "defense", "emp": false},
	"economic": {"weights": {"resources": 0.8, "production": 8.0}, "allocation": "systems", "emp": false},
	"emp": {"weights": {"hull": 2.5, "shields": 1.25}, "allocation": "defense", "emp": true}
}

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 5 or args.size() > 6 or (args.size() == 6 and args[5] != "storm-only"):
		push_error("Arguments: output path, ship index (-1 for all), first seed, last seed, policy (all or policy name), optional storm-only")
		quit(2)
		return
	var selected := int(args[1])
	var first := int(args[2])
	var last := int(args[3])
	var policy_filter := args[4]
	var storm_only := args.size() == 6
	if selected < -1 or selected >= Ships.PLAYERS.size() or first < 1 or last < first or (policy_filter != "all" and not POLICIES.has(policy_filter)):
		push_error("Invalid audit shard arguments")
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
	var roster := []
	for enemy in enemies: roster.append({"name": enemy.ship_name, "rank": enemy.enemy_rank, "resource": enemy.resource_path})
	file.store_line(JSON.stringify({"type": "config", "revision": source_revision(), "engine": Engine.get_version_info().string,
		"ships": Ships.PLAYERS.map(func(ship): return ship.ship_name), "enemies": roster, "modifiers": Modifier.NAMES,
		"policies": POLICIES, "selected_ship": selected, "first_seed": first, "last_seed": last, "policy_filter": policy_filter,
		"storm_only_control": storm_only,
		"round_limit": ROUND_LIMIT, "action_limit": ACTION_LIMIT, "failure_turns": failure_turns,
		"boss_emp_bonus": Config.defense_tuning.mothership_emp_bonus}))
	var count := 0
	for i in Ships.PLAYERS.size():
		if selected >= 0 and selected != i: continue
		var player: Resource = Ships.PLAYERS[i]
		if storm_only and player.ship_name in ["Ganymede", "Thunderbolt"]:
			player = legacy_starting_deck(player)
		for policy in POLICIES:
			if policy_filter != "all" and policy_filter != policy: continue
			var metrics := {}
			var settings: Dictionary = POLICIES[policy].duplicate(true)
			settings.cards = metrics
			for original_enemy in enemies:
				var enemy: Resource = original_enemy
				if storm_only and enemy.ship_name == "The Hollow Choir":
					enemy = enemy.duplicate()
					enemy.shields = 4
				settings.emp_bonus = Config.defense_tuning.mothership_emp_bonus if enemy.enemy_rank == 2 else 0
				for kind in Modifier.NAMES.size():
					for seed_value in range(first, last + 1):
						var match_result := play_match(player, enemy, kind, seed_value, settings)
						match_result.policy = policy
						match_result.type = "match"
						file.store_line(JSON.stringify(match_result))
						count += 1
			file.store_line(JSON.stringify({"type": "cards", "player": player.ship_name, "policy": policy, "cards": metrics}))
			file.flush()
			print("%s / %s: %d battles complete" % [player.ship_name, policy, count])
	file.store_line(JSON.stringify({"type": "complete", "matches": count}))
	file.close()
	quit()

func legacy_starting_deck(profile: Resource) -> Resource:
	var current: Resource
	var previous: Resource
	if profile.ship_name == "Ganymede":
		current = preload("res://cards/47_siege_charges.tres")
		previous = preload("res://cards/06_shield_disruptor.tres")
	else:
		current = preload("res://cards/53_capacitor_overload.tres")
		previous = preload("res://cards/44_desperate_conversion.tres")
	var slot: int = profile.starting_cards.find(current)
	assert(slot >= 0)
	var copy := profile.duplicate()
	copy.starting_cards = profile.starting_cards.duplicate()
	copy.starting_cards[slot] = previous
	return copy
