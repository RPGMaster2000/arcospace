extends "res://tests/six_ship_gameplay_simulation.gd"

func run() -> void:
	var checks := 0
	var failures := 0
	for kind in [0, 2, 5]:
		var player: Resource = Ships.PLAYERS[0]
		var enemy: Resource = Config.enemy_ships[0]
		var scene := preload("res://scenes/board.tscn").instantiate()
		scene.battle_setup = Board.BattleSetup.new()
		scene.battle_setup.battle_seed = 913
		scene.setup_settings = {"player_ship": 0, "enemy_ship": 0,
			"player_data": player, "enemy_data": enemy, "modifier": kind}
		root.add_child(scene)
		scene.enemy_timer.stop()
		var draw := Hand.new()
		draw.rng.seed = 913 ^ 101
		draw.card_pool.assign(player.starting_cards)
		draw.signature_card = player.signature_card
		draw.drop_multiplier = Modifier.TEMPORAL_DROP_MULTIPLIER if kind == 5 else 1.0
		draw.configure_player_allocation(scene.allocation_settings.matching_draw_weight)
		draw.deal_player_opening()
		var actor := state(player)
		var target := state(enemy)
		Execution.begin_turn(actor)
		var modifier := Modifier.new()
		modifier.configure(kind, 913)
		modifier.begin_round(1)
		var expected_modifier_rng: int = modifier.rng.state
		var slot := 0
		var card: Resource = draw.cards[slot]
		var discard := not Execution.can_play(card, false, actor)
		var result = Execution.resolve(card, discard, actor, target, modifier)
		var expected_charge := 1
		for valid in [draw.cards == scene.hand.cards, scene.ftl.charge == expected_charge,
				scene.modifier.rng.state == expected_modifier_rng]:
			checks += 1
			if not valid: failures += 1
		scene._resolve_card("player", slot, discard, card)
		scene.damage_timeline.finish_now()
		for key in ["hull", "shields"] + Rules.RESOURCES + Rules.PRODUCTION:
			checks += 1
			if actor[key] != scene.ship_snapshot("player")[key] or target[key] != scene.ship_snapshot("enemy")[key]:
				failures += 1
				push_error("State mismatch for %s, modifier %d" % [key, kind])
		checks += 1
		if result.extra_action != scene.extra_action_requested or modifier.rng.state != scene.modifier.rng.state: failures += 1
		scene.free()
		modifier.free()
		draw.free()
		await process_frame
	print("Combat audit parity: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
