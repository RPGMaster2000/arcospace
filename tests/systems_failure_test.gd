extends SceneTree
const Rules = preload("res://scripts/match_rules.gd")
const Failure = preload("res://scripts/combat/systems_failure.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const AI = preload("res://scripts/enemy_ai.gd")
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func state() -> Dictionary:
	return {
		"hull": 30,
		"hull_capacity": 30,
		"shields": 10,
		"materials": 100,
		"energy": 100,
		"crew": 100,
		"synthesizer": 1,
		"reactor": 1,
		"quarters": 1
	}


func card(
	effects: Dictionary, family: String = "materials", cost: int = 0, again: bool = false
) -> Resource:
	var result = preload("res://scripts/cards/card_data.gd").new()
	result.card_name = "Test action"
	result.effects = effects
	result.family = family
	result.cost = cost
	result.play_again = again
	return result


func board(expedition: RefCounted = null, profile: Resource = null) -> Control:
	var result = load("res://scenes/board_3d.tscn").instantiate()
	result.get_node("BattleEffects").enabled = false
	result.get_node("CardMotion").settings = result.get_node("CardMotion").settings.duplicate()
	result.get_node("CardMotion").settings.enabled = false
	result.get_node("ModifierDisplay").cinematic_enabled = false
	if expedition != null:
		result.expedition = expedition
		result.expedition_encounter = 0
		result.setup_settings = {"enemy_data": profile, "player_ship": 0}
	root.add_child(result)
	result.enemy_timer.stop()
	return result


func action(view: Control, side: String, effects: Dictionary, again: bool = false) -> void:
	var hand = view.hand if side == "player" else view.enemy_hand
	hand.cards[0] = card(effects, "materials", 0, again)
	await view._act(side, 0, false)
	view.enemy_timer.stop()


func run() -> void:
	# Every disabled-system combination, both ships, timing, recovery and reactivation.
	for side in ["player", "enemy"]:
		var other: String = "enemy" if side == "player" else "player"
		for mask in range(8):
			var states: Dictionary = {"player": state(), "enemy": state()}
			var clock = Failure.new()
			var count: int = 0
			for index in range(3):
				if mask & (1 << index):
					states[side][Rules.PRODUCTION[index]] = 0
					count += 1
			clock.sync(states, other, 3)
			check(clock.remaining[side] == (3 if count >= 2 else -1), "All combinations activate symmetrically at two disabled systems")
			states[side].systems_failure_remaining = 0
			check(Rules.wins(state(), states[side]) == (count >= 2), "Expiry requires two disabled systems")
			if count < 2:
				clock.end_turn(side)
				check(clock.remaining[side] == -1, "Single shutdown has no countdown")
				continue
			clock.end_turn(other)
			check(clock.remaining[side] == 3, "Opponent turns never decrement")
			for remaining in [2, 1, 0]:
				clock.end_turn(side)
				check(clock.remaining[side] == remaining, "Three affected-ship turns")
			check(Rules.offline_systems(states[side]).size() == count, "Expiry never repairs")
			for key in Rules.PRODUCTION:
				states[side][key] = 1
			states[side].reactor = 0
			clock.sync(states, other, 3)
			check(clock.remaining[side] == -1, "One remaining disabled system cancels")
			states[side].quarters = 0
			clock.sync(states, side, 3)
			clock.end_turn(side)
			check(clock.remaining[side] == 3, "Reactivation is fresh and activation turn exempt")
	var states: Dictionary = {"player": state(), "enemy": state()}
	var clock = Failure.new()
	for side in ["player", "enemy"]:
		for key in Rules.PRODUCTION:
			states[side][key] = 0
	clock.sync(states, "", 3)
	clock.end_turn("player")
	states.player.reactor = 1
	clock.sync(states, "enemy", 3)
	check(clock.remaining.player == 2 and clock.remaining.enemy == 3, "Three to two offline keeps independent countdowns")
	clock.end_turn("player")
	states.player.quarters = 1
	clock.sync(states, "player", 3)
	check(clock.remaining.player == -1 and clock.remaining.enemy == 3, "Final-turn sufficient recovery cancels only affected clock")
	states.player.quarters = 0
	clock.sync(states, "enemy", 5)
	check(clock.remaining.player == 5, "Reactivation uses configured duration")
	# Production application, including conditional and cross-family effects, never goes negative.
	for effects in [
		{"reactor": -9}, {"production_other": {"type": "reactor", "production": -9, "resource": 0}}
	]:
		var a: Dictionary = state()
		var b: Dictionary = state()
		Effects.play(card(effects), a, b)
		check(a.reactor == 0, "Direct and production_other reductions clamp at zero")
	for effects in [
		{"enemy_production": {"quarters": -9}},
		{
			"conditional":
			{
				"target": "enemy",
				"attribute": "quarters",
				"comparison": "at_least",
				"threshold": 1,
				"then": {"enemy_production": {"quarters": -9}}
			}
		}
	]:
		var a: Dictionary = state()
		var b: Dictionary = state()
		Effects.play(card(effects), a, b)
		check(b.quarters == 0, "Targeted and conditional reductions clamp at zero")
	var income: Dictionary = state()
	income.reactor = 0
	Rules.income(income)
	check(income.energy == 100 and income.materials == 101, "Offline production yields no income")
	check(not Rules.wins(state(), state()), "100/100/100 resources no longer wins")
	# Uniform random targets, including offline systems, with one combat RNG draw.
	var hits: Array[int] = [0, 0, 0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1711
	for sample in range(600):
		var a: Dictionary = state()
		var b: Dictionary = state()
		Effects.play(Cards.CARDS[18], a, b, rng)
		var changed: int = 0
		for index in range(3):
			if b[Rules.PRODUCTION[index]] == 0:
				hits[index] += 1
				changed += 1
		check(changed == 1, "System Disruption affects exactly one production system")
	for count in hits:
		check(count > 160 and count < 240, "Seeded targets are uniformly distributed")
	for level in range(3):
		var disruption: Resource = Cards.CARDS[18].with_upgrade(level)
		check(
			(
				disruption.cost == 9
				and disruption.tier == 1
				and disruption.allocation_category == "offense"
			),
			"Disruption retains identity, price, tier and allocation"
		)
		var a: Dictionary = state()
		var b: Dictionary = state()
		b.shields = 0
		rng.seed = 221
		var preview := RandomNumberGenerator.new()
		preview.seed = 221
		var selected: String = Rules.PRODUCTION[preview.randi_range(0, 2)]
		b[selected] = 0
		Effects.play(disruption, a, b, rng)
		check(
			(
				b[selected] == 0
				and Rules.offline_systems(b).size() == 1
				and rng.state == preview.state
			),
			"Zero target is legal; RNG does not retarget"
		)
		check(
			b.energy == 100 - [0, 3, 6][level] and b.hull == 30 - [0, 0, 3][level],
			"Upgrades retain energy drain and damage"
		)
		check(
			disruption.description.to_lower().contains("random"),
			"Inspection describes random target at every level"
		)
		var simulation_rng: int = Effects.combat_rng.state
		Effects.play(disruption, state(), state(), null, true)
		check(
			Effects.combat_rng.state == simulation_rng,
			"Conservative simulation consumes no combat RNG"
		)
		var target: Dictionary = state()
		Effects.play(Cards.CARDS[33].with_upgrade(level), state(), target, null, true)
		check(
			Rules.offline_systems(target).size() == 3,
			"Sabotage Commandos retains all-system reduction"
		)
	# AI: correct system, urgency, immediate Hull precedence, preserving recovery funds.
	var ai = AI.new()
	ai.tactical_variation = 0
	var a: Dictionary = state()
	var b: Dictionary = state()
	a.reactor = 0
	a.synthesizer = 0
	a.systems_failure_remaining = 1
	var restore := card({"reactor": 1}, "energy", 5)
	var irrelevant := card({"quarters": 1}, "materials", 0)
	var attack := card({"damage": 10}, "energy", 5)
	check(
		ai.choose([irrelevant, attack, restore], a, b).slot == 2,
		"AI prioritizes restoring the actual offline system on its last turn"
	)
	b.hull = 1
	b.shields = 0
	check(
		ai.choose([restore, attack], a, b).slot == 1,
		"Immediate Hull victory precedes recovery or sabotage"
	)
	b = state()
	a.energy = 4
	var move: Dictionary = ai.choose([restore, card({"damage": 4}, "energy", 3)], a, b)
	check(
		move.discard and move.slot == 1, "AI saves recovery funds and keeps the needed repair card"
	)
	a = state()
	b = state()
	var combat_before: int = Effects.combat_rng.state
	var copy_a: Dictionary = a.duplicate(true)
	var copy_b: Dictionary = b.duplicate(true)
	check(
		ai.choose([card({"damage": 1}), Cards.CARDS[18]], a, b).slot == 1,
		"AI values random production shutdown as an offensive objective"
	)
	check(
		a == copy_a and b == copy_b and Effects.combat_rng.state == combat_before,
		"AI never changes real state or consumes combat randomness"
	)
	a = state()
	a.reactor = 0
	a.quarters = 0
	a.synthesizer = 0
	a.systems_failure_remaining = 1
	check(
		(
			(
				ai
				. choose(
					[card({"quarters": 1}), card({"reactor": 1}, "materials", 0, true)], a, state()
				)
				. slot
			)
			== 1
		),
		"AI can cancel failure with a single relevant repair"
	)
	# Crossing the second-system threshold is worth more than first or third shutdown.
	var sabotage := card({"enemy_production": {"reactor": -1}})
	var first: Dictionary = state()
	var second: Dictionary = state()
	second.quarters = 0
	var third: Dictionary = second.duplicate(true)
	third.synthesizer = 0
	third.systems_failure_remaining = 2
	var scores: Array[float] = []
	for target in [first, second, third]:
		var after: Dictionary = target.duplicate(true)
		var actor: Dictionary = state()
		Effects.play(sabotage, actor, after, null, true)
		scores.append(ai._position_score(sabotage, state(), target, actor, after))
	check(scores[1] > scores[0] and scores[1] > scores[2], "AI values second shutdown without repeated failure bonus")
	a = state()
	a.reactor = 0
	a.quarters = 0
	a.systems_failure_remaining = 1
	check(ai.choose([card({"synthesizer": 3}), card({"quarters": 1})], a, state()).slot == 1, "One relevant repair cancels failure despite another offline system")
	ai.free()
	var integration_view = board()
	for key in Rules.PRODUCTION:
		integration_view.set("enemy_" + key, 1)
	integration_view.player_crew = 30
	integration_view.hand.cards[0] = Cards.CARDS[18]
	await integration_view._act("player", 0, false)
	integration_view.enemy_timer.stop()
	check(
		(
			integration_view.systems_failure.remaining.enemy == -1
			and Rules.offline_systems(integration_view.ship_snapshot("enemy")).size() == 1
		),
		"A single real Disruption shutdown does not activate failure"
	)
	integration_view.free()
	integration_view = board()
	integration_view.modifier.configure(4)
	integration_view.modifier.miss_rate = 100
	integration_view.player_crew = 30
	integration_view.hand.cards[0] = Cards.CARDS[18]
	await integration_view._act("player", 0, false)
	integration_view.enemy_timer.stop()
	check(
		(
			integration_view.systems_failure.remaining.enemy == -1
			and integration_view.player_crew == 21
		),
		"Nebula can miss random sabotage while retaining its cost"
	)
	integration_view.free()
	# Live Board: actual full turns, extra actions, recovery and logical result/reward latching.
	var view = board()
	view.current_actor = "enemy"
	view.player_synthesizer = 0
	view.player_reactor = 0
	view._check_winner()
	view._begin_turn("player")
	await action(view, "player", {"materials": 1}, true)
	check(view.systems_failure.remaining.player == 3, "Play again is not a turn ending")
	await action(view, "player", {})
	check(view.systems_failure.remaining.player == 2, "First complete affected turn decrements")
	await action(view, "enemy", {})
	check(
		view.systems_failure.remaining.player == 2, "Enemy turn does not consume player countdown"
	)
	await action(view, "player", {})
	await action(view, "enemy", {})
	check(view.systems_failure.remaining.player == 1, "Final recovery opportunity is available")
	view._select_allocation("systems")
	check(
		view.hand.allocation_mode == "systems", "Power Allocation remains available during failure"
	)
	await action(view, "player", {"reactor": 1})
	check(
		view.winner.is_empty() and view.systems_failure.remaining.player == -1,
		"Production restored on third turn survives"
	)
	check(
		(
			not view.get_node("SystemsFailureDisplay").columns.player.visible
			and view.get_node("ModifierDisplay/Flash").text.contains("RECOVERED")
		),
		"Recovery removes warning and announces restoration immediately"
	)
	view.free()
	view = board()
	await action(view, "player", {"reactor": -99, "quarters": -99})
	check(
		view.systems_failure.remaining.player == 3,
		"Own-card activation turn is exempt in real Board flow"
	)
	view.free()
	for side in ["player", "enemy"]:
		view = board()
		view.current_actor = "enemy" if side == "player" else "player"
		view.set(side + "_reactor", 0)
		view.set(side + "_quarters", 0)
		view._check_winner()
		for index in range(3):
			view._finish_turn(side)
			view.enemy_timer.stop()
			if index < 2:
				check(view.winner.is_empty(), "No early Systems Failure defeat")
		check(
			(
				view.winner == ("enemy" if side == "player" else "player")
				and view.result_cause == "systems_failure"
			),
			"Third unresolved turn defeats either ship"
		)
		view.refresh_display()
		check(
			view.get_node("MatchResult/Panel/Details").text.contains("Systems Failure"),
			"Result identifies defeat cause"
		)
		var salvage: int = view.salvage
		view.refresh_display()
		view.refresh_display()
		check(
			(
				view.salvage == salvage
				and (salvage == view.DESTRUCTION_SALVAGE if side == "enemy" else salvage == 0)
			),
			"Destruction rewards are awarded once for Systems Failure"
		)
		view.free()
	view = board()
	view.player_synthesizer = 0
	view.player_reactor = 0
	view.systems_failure.remaining.player = 0
	view.enemy_hull = 0
	view._check_winner()
	check(
		view.winner == "player" and view.result_cause == "hull",
		"Hull destruction retains precedence over failure"
	)
	view.free()
	view = board()
	view.systems_failure_turns = 1
	view.current_actor = "enemy"
	view.player_synthesizer = 0
	view.player_reactor = 0
	view._check_winner()
	view._finish_turn("player")
	view.enemy_timer.stop()
	check(view.winner == "enemy", "Board uses its Inspector countdown duration")
	view.free()
	view = board()
	view.enemy_reactor = 0
	view.enemy_quarters = 0
	view._check_winner()
	view.enemy_hand.cards.clear()
	for index in range(3):
		view._begin_turn("enemy")
		view._on_enemy_timeout()
		view.enemy_timer.stop()
	check(view.winner == "player", "An empty AI hand still consumes its recovery turns")
	view.free()
	for profile_path in ["rustjack", "marauder_vanguard", "sentinel_dreadnought"]:
		var profile: Resource = load("res://ships/enemy/" + profile_path + ".tres")
		var expedition = preload("res://scripts/expedition_state.gd").new()
		expedition.start(0, preload("res://encounters/expedition_rules.tres"), 2026)
		expedition.encounters[0] = {
			"kind": "battle",
			"enemy": 0,
			"enemy_data": profile,
			"completed": false,
			"mandatory_boss": profile.enemy_rank == 2
		}
		view = board(expedition, profile)
		view.enemy_synthesizer = 0
		view.enemy_reactor = 0
		view._check_winner()
		for index in range(3):
			view._finish_turn("enemy")
			view.enemy_timer.stop()
		check(
			view.winner == "player" and view.enemy_hull > 0 and expedition.encounters[0].completed,
			"Systems Failure completes standard/Elite/Boss without destroying Hull"
		)
		var reward: int = expedition.victory_salvage(view.battle_result())
		check(
			(
				expedition.salvage == reward
				and expedition.ftl_charge == profile.interstellar_ftl_reward
				and expedition.upgrades_remaining > 0
			),
			"Existing rank rewards and upgrades apply to Systems Failure"
		)
		view.refresh_display()
		expedition.record_battle(view.battle_result())
		check(
			(
				expedition.salvage == reward
				and expedition.ftl_charge == profile.interstellar_ftl_reward
			),
			"Expedition rewards cannot repeat"
		)
		view.free()
	# Live warning activation/cancellation for every combination, including 2 -> 1 recovery.
	view = board()
	for side in ["player", "enemy"]:
		for mask in [0, 1, 2, 4, 3, 1, 5, 4, 6, 2, 7, 3, 1]:
			var count: int = 0
			for index in range(3):
				var disabled: bool = bool(mask & (1 << index))
				view.set(side + "_" + Rules.PRODUCTION[index], 0 if disabled else 1)
				count += int(disabled)
			view._sync_systems_failure()
			view.refresh_display()
			check(view.get_node("SystemsFailureDisplay").columns[side].visible == (count >= 2), "Live warning follows threshold and sufficient recovery immediately")
	view.free()
	# Compact, independently readable warnings fit the reserved side gutters.
	view = board()
	view.current_actor = "enemy"
	for side in ["player", "enemy"]:
		for key in Rules.PRODUCTION:
			view.set(side + "_" + key, 0)
	view._check_winner()
	view.refresh_display()
	for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1680, 720)]:
		root.size = dimensions
		for frame in range(6):
			await process_frame
		view.enemy_timer.stop()
		view._fit_board_lines()
		var display: Control = view.get_node("SystemsFailureDisplay")
		for side in ["player", "enemy"]:
			var warning: Control = display.columns[side]
			check(
				warning.visible and display.offline[side].text.split("\n").size() == 3,
				"Warning identifies every offline system for either ship"
			)
			for path in [
				"PlayerHullLabel",
				"EnemyHullLabel",
				"PlayerHullBar",
				"EnemyHullBar",
				"FTLPanel/WarpButton"
			]:
				check(
					not warning.get_global_rect().intersects(view.get_node(path).get_global_rect()),
					"Warning clears " + path
				)
			check(
				warning.get_global_rect().end.y < view.get_node(view.card_slots[0]).position.y,
				"Warning clears the six-card hand"
			)
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
			root.get_texture().get_image().save_png(
				"res://.godot/testlogs/systems-failure-%d.png" % dimensions.x
			)
	view.free()
	print("Systems Failure: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
