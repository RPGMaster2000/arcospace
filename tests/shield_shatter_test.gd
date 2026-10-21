extends SceneTree
const CardData = preload("res://scripts/cards/card_data.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func make_board() -> Control:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	board.battle_effects.visual_settings = board.battle_effects.visual_settings.duplicate(true)
	board.battle_effects.visual_settings.shield_shatter = (
		board.battle_effects.visual_settings.shield_shatter.duplicate(true)
	)
	board.battle_effects.enabled = true
	board.damage_timeline.set_process(false)  # Explicit advancement proves the exact boundary.
	return board


func attack(board: Control, actor: String, amount: int) -> void:
	var card = CardData.new()
	card.family = "materials"
	card.cost = 0
	card.effects = {"damage": amount}
	board._resolve_card(actor, 0, false, card)


func model(board: Control, side: String) -> Node3D:
	return board.get_node(
		"BattleView/Viewport/Battlefield/" + ("PlayerShip" if side == "player" else "EnemyShip")
	)


func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/shatter-" + name + ".png")


func run() -> void:
	for side in ["player", "enemy"]:
		var actor: String = "enemy" if side == "player" else "player"
		var board = make_board()
		var ship = model(board, side)
		board.set(side + "_shields", 10)
		board.refresh_display()
		attack(board, actor, 2)
		check(
			board.get(side + "_shields") == 8 and not is_instance_valid(ship.shatter_effect),
			side + ": ordinary hit retains ripple"
		)
		board.free()
		await process_frame

		board = make_board()
		ship = model(board, side)
		board.set(side + "_shields", 3)
		board.refresh_display()
		attack(board, actor, 3)
		check(
			board.get(side + "_hull") == 30 and board.damage_timeline.pending.is_empty(),
			side + ": exact shield break has no pending Hull loss"
		)
		check(
			is_instance_valid(ship.shatter_effect) and ship.shield.visible,
			side + ": impact keeps bubble visible at zero Shields"
		)
		ship.shatter_effect.seek(0.75)
		check(not ship.shield.visible, side + ": collapsed bubble hidden")
		board.free()
		await process_frame

		board = make_board()
		ship = model(board, side)
		board.set(side + "_shields", 3)
		board.refresh_display()
		var impact_events: Array = []
		ship.hull_impact_started.connect(
			func():
				impact_events.append(
					{"hull": board.get(side + "_hull"), "burst": ship.shatter_effect.burst_started}
				)
		)
		attack(board, actor, 8)
		var effect: Node3D = ship.shatter_effect
		check(
			board.get(side + "_shields") == 0 and board.get(side + "_hull") == 30,
			side + ": Shields commit first, Hull stays authoritative at old value"
		)
		check(
			(
				not board.damage_timeline.pending.is_empty()
				and board._display_snapshot().resolving_card
			),
			side + ": pending event locks actions"
		)
		check(
			not effect.burst_started and ship.hull_material.albedo_color == ship.base_color,
			side + ": no early Hull flash or burst"
		)
		board.damage_timeline.advance(0.15)
		check(
			(
				float(ship.shield_material.get_shader_parameter("fracture")) > 0
				and board.get(side + "_hull") == 30
			),
			side + ": fracture precedes damage"
		)
		await capture(side + "-fracture")
		board.damage_timeline.advance(0.049)
		check(board.get(side + "_hull") == 30, side + ": Hull unchanged at 0.199 seconds")
		board.damage_timeline.advance(0.002)
		check(
			board.get(side + "_hull") == 25 and effect.burst_started,
			side + ": burst and Hull commit share Stage 3 boundary"
		)
		check(
			board.get(side + "_hull_label").text == "Hull 25/30", side + ": HUD changes at commit"
		)
		check(
			effect.particles.multimesh.instance_count == 32,
			side + ": bounded shared fragment batch"
		)
		check(
			impact_events.size() == 1 and impact_events[0].hull == 25 and impact_events[0].burst,
			side + ": existing Hull impact starts once, exactly at the burst commit"
		)
		await create_timer(0.06).timeout
		await capture(side + "-burst")
		board.damage_timeline.advance(0.2)
		check(
			not ship.shield.visible and effect.particles.visible,
			side + ": fragments persist after the intact bubble disappears"
		)
		await capture(side + "-fragments")
		board.damage_timeline.advance(0.6)
		board.damage_timeline.finish_now()
		check(
			board.get(side + "_hull") == 25 and not ship.shield.visible,
			side + ": final cleanup does not duplicate damage"
		)
		board.set(side + "_shields", 5)
		board.refresh_display()
		var reactivate = ship.create_tween()
		ship.shield_was_offline = true
		ship.animate_shield(reactivate, 0.1, true)
		await reactivate.finished
		check(
			(
				ship.shield.visible
				and is_equal_approx(
					float(ship.shield_material.get_shader_parameter("formation")), 1.0
				)
			),
			side + ": original reactivation remains functional"
		)
		attack(board, actor, 5)
		check(
			is_instance_valid(ship.shatter_effect) and ship.shatter_effect.active,
			side + ": repeated collapse creates a fresh effect"
		)
		ship.shatter_effect.cancel()
		board.free()
		await process_frame

	var board = make_board()
	board.enemy_shields = 0
	attack(board, "player", 8)
	check(
		board.enemy_hull == 22 and board.damage_timeline.pending.is_empty(),
		"Unshielded damage stays immediate"
	)
	board.free()
	await process_frame

	board = make_board()
	board.enemy_shields = 3
	board.enemy_hull = 4
	board.refresh_display()
	attack(board, "player", 8)
	check(
		board.winner.is_empty() and board.enemy_hull == 4 and not board.result_recorded,
		"Lethal overflow does not declare victory early"
	)
	board.damage_timeline.advance(0.2)
	check(
		board.enemy_hull == 0 and board.winner == "player" and board.result_recorded,
		"Lethal overflow commits destruction and victory at burst"
	)
	check(
		model(board, "enemy").body.visible,
		"Destroyed ship remains available for coherent impact presentation"
	)
	board.free()
	await process_frame

	for interruption in ["skip", "visual_cancel", "cleanup", "second_event"]:
		board = make_board()
		board.player_shields = 3
		board.refresh_display()
		attack(board, "enemy", 8)
		var received: Dictionary = {}
		board.damage_timeline.damage_applied.connect(func(): received["hull"] = board.player_hull)
		match interruption:
			"skip":
				board.battle_effects.enabled = false
				board.damage_timeline._process(0.01)
				board.damage_timeline.finish_now()
			"visual_cancel":
				model(board, "player").shatter_effect.cancel()
				board.damage_timeline.advance(0.2)
				board.damage_timeline.finish_now()
			"cleanup":
				board.free()
			"second_event":
				attack(board, "enemy", 2)
		check(received.get("hull", -1) == 25, interruption + ": pending damage resolves once")
		if interruption != "cleanup":
			check(
				board.player_hull == (23 if interruption == "second_event" else 25),
				interruption + ": resulting Hull is correct"
			)
			board.free()
		await process_frame

	board = make_board()
	board.player_shields = 3
	board.enemy_shields = 3
	var simultaneous = CardData.new()
	simultaneous.family = "materials"
	simultaneous.effects = {"damage": 8, "self_damage_regular": 8}
	board._resolve_card("player", 0, false, simultaneous)
	check(
		(
			board.player_hull == 30
			and board.enemy_hull == 30
			and board.damage_timeline.pending.size() == 2
		),
		"Both sides can stage overflow in one atomic event batch"
	)
	check(
		not await board._act("player", 0, false), "Pending damage rejects conflicting card actions"
	)
	board.damage_timeline.advance(0.2)
	check(
		board.player_hull == 25 and board.enemy_hull == 25 and board.player_hull_damage_taken == 5,
		"Both sides resolve once with unchanged damage totals"
	)
	board.free()
	await process_frame

	board = make_board()
	board.enemy_shields = 3
	var piercing = CardData.new()
	piercing.family = "materials"
	piercing.effects = {"damage": 8, "pierce": 0.25}
	board._resolve_card("player", 0, false, piercing)
	check(
		board.enemy_hull == 30 and board.damage_timeline.pending[0].amount == 5,
		"A mixed piercing/overflow attack uses one pending Hull event and one impact"
	)
	board.damage_timeline.advance(0.2)
	check(board.enemy_hull == 25, "Pierce plus overflow preserves original final damage")
	board.free()
	await process_frame

	board = make_board()
	board.battle_effects.visual_settings.shield_shatter.shatter_burst_start = 0.31
	board.enemy_shields = 3
	attack(board, "player", 8)
	board.damage_timeline.advance(0.30)
	check(board.enemy_hull == 30, "Custom burst setting also controls the pending damage clock")
	board.damage_timeline.advance(0.02)
	check(
		board.enemy_hull == 25 and model(board, "enemy").shatter_effect.burst_started,
		"Custom burst commits and launches together"
	)
	board.free()
	await process_frame

	board = make_board()
	board.enemy_shields = 8
	board.refresh_display()
	attack(board, "player", 2)
	attack(board, "player", 8)
	board.damage_timeline.advance(0.15)
	await create_timer(0.4).timeout
	check(
		is_equal_approx(
			float(model(board, "enemy").shield_material.get_shader_parameter("hit")), 0.75
		),
		"Old hit Tween cannot overwrite a newer collapse"
	)
	board.damage_timeline.advance(0.05)
	check(board.enemy_hull == 28, "Overlapping ordinary hit and collapse preserve damage")
	board.free()
	await process_frame

	board = make_board()
	board.player_shields = 3
	var restored = CardData.new()
	restored.family = "materials"
	restored.effects = {"hull": 12, "self_damage_regular": 8}
	board._resolve_card("player", 0, false, restored)
	check(
		board.player_hull == 42 and board.damage_timeline.pending[0].amount == 5,
		"Immediate healing is retained while the full calculated overflow waits"
	)
	board.damage_timeline.advance(0.2)
	check(
		board.player_hull == 37 and board.player_hull_damage_taken == 5,
		"Healing plus overflow preserves original final result and damage accounting"
	)
	board.free()
	await process_frame

	board = make_board()
	board.enemy_shields = 20
	var bypass = CardData.new()
	bypass.family = "materials"
	bypass.effects = {"damage": 8, "pierce": 0.25}
	board._resolve_card("player", 0, false, bypass)
	check(
		(
			board.enemy_hull == 28
			and board.enemy_shields == 14
			and board.damage_timeline.pending.is_empty()
		),
		"Piercing damage without shield collapse retains its immediate behavior"
	)
	board.free()
	await process_frame

	board = make_board()
	board.player_shields = 3
	board.get_node("ModifierDisplay").cinematic_enabled = false
	board.modifier.configure(1)
	board.modifier.next_round = board.turn_number
	for candidate in range(100):
		var generator = RandomNumberGenerator.new()
		generator.seed = candidate
		generator.randi_range(board.modifier.MIN_INTERVAL, board.modifier.MAX_INTERVAL)
		if generator.randf() < board.modifier.ASTEROID_CHANCE:
			board.modifier.rng.seed = candidate
			break
	board._begin_turn("player")
	check(
		(
			board.player_shields == 0
			and board.player_hull == 30
			and not board.damage_timeline.pending.is_empty()
		),
		"Asteroid overflow follows the same staged application path"
	)
	board.damage_timeline.advance(0.2)
	check(
		board.player_hull == 23 and board.player_hull_damage_taken == 7,
		"Asteroid Hull consequences apply at Stage 3 without changing its formula"
	)
	board.free()
	await process_frame

	board = make_board()
	board.enemy_shields = 3
	board.enemy_hull = 4
	attack(board, "player", 8)
	var final_result: Dictionary = {}
	board.damage_timeline.damage_applied.connect(
		func():
			final_result["hull"] = board.enemy_hull
			final_result["winner"] = board.winner
			final_result["recorded"] = board.result_recorded
	)
	board.free()
	check(
		(
			final_result.get("hull", -1) == 0
			and final_result.get("winner", "") == "player"
			and final_result.get("recorded", false)
		),
		"Cleanup resolves lethal overflow and records the result exactly once"
	)
	await process_frame

	board = make_board()
	board.battle_effects.visual_settings.shield_shatter.shatter_enabled = false
	board.enemy_shields = 3
	attack(board, "player", 8)
	check(
		board.enemy_hull == 25 and board.damage_timeline.pending.is_empty(),
		"Disabled shatter uses immediate existing damage path"
	)
	board.free()
	await process_frame
	print("Shield shatter: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
