extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Library = preload("res://scripts/cards/card_library.gd")
const Hand = preload("res://scripts/cards/card_hand.gd")
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func fresh(ship_index: int = 0) -> Resource:
	var run = State.new()
	run.start(ship_index, Rules, 123456)
	return run

func put_poi(run: Resource, poi: Resource) -> void:
	run.encounters.assign([{"kind":"poi", "poi":poi, "title":poi.title, "completed":false}])

func make_board(run: Resource):
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {"player_ship":run.player_ship, "modifier":0, "enemy_ship":1}
	board.expedition = run
	board.expedition_encounter = 0
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
	board.get_node("CardMotion").settings.enabled = false
	root.add_child(board)
	return board

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var run = fresh()
	var other = fresh()
	check(run.system_name == other.system_name and run.encounters == other.encounters, "Seed reproduces initial system")
	for system in range(50):
		var battles: int = 0
		var pois: int = 0
		for encounter in run.encounters:
			if encounter.kind == "battle": battles += 1
			else: pois += 1
		check(run.encounters.size() == 6 and battles >= 1 and battles <= 2 and pois >= 4, "Every system has six encounters and accessible battles/PoIs")
		check(not run.generate_system(), "Uncharged drive blocks travel")
		# This long-run generation fixture simulates completing each mandatory battle.
		for entry in run.encounters:
			if entry.get("mandatory_boss", false): entry.completed = true
		run.ftl_charge = run.required_ftl_charge
		check(run.generate_system(), "Charged drive permits travel")
	check(run.system_number == 51 and run.salvage == 0, "Repeated charged jumps")
	# Every authored outcome is exercised, including both sides of risk rolls.
	for poi in Rules.pois:
		check(poi.approaches.size() == 4, "Four approaches per PoI")
		for slot in range(4):
			var approach: Resource = poi.approaches[slot]
			for roll in [0.0, 0.9999]:
				run = fresh()
				run.salvage = 30
				run.hull = 10
				for key in State.PRODUCTION: run.production_upgrades[key] = 3
				put_poi(run, poi)
				var expected: Resource = approach.success if roll < approach.success_chance else approach.failure
				var positive: bool = run.encounter_charge(0) >= 1 # Every PoI grants navigation progress.
				for amount in expected.next_battle.values(): positive = positive or amount > 0
				check(positive, "Every authored success/failure grants a reward")
				check(run.resolve_approach(0, slot, roll), "Accessible approach resolves")
				check(run.salvage == 30 - approach.salvage_cost + expected.salvage, "Exact Salvage payment/reward")
				check(run.hull == clampi(10 + expected.hull, 0, run.ship().hull_capacity), "Exact permanent Hull outcome")
				check(run.encounters[0].completed and not run.resolve_approach(0, slot, roll), "Cannot repeat or double-charge encounter")
				check(not run.last_outcome.is_empty(), "Outcome text")
				if expected.card_reward:
					check(run.card_offers.size() == 3, "Every card reward offers three distinct choices")
					check(run.card_offers[0] != run.card_offers[1] and run.card_offers[1] != run.card_offers[2] and run.card_offers[0] != run.card_offers[2], "No duplicate offers")
					for card in run.card_offers: check(card.tier >= expected.minimum_card_tier, "Rarity floor")
					check(not run.generate_system(), "Cannot lose a paid choice by jumping")
					check(run.choose_card(1) and not run.choose_card(1), "Select exactly once")
					check(run.shared_pool().size() == Library.CARDS.size(), "Acquisition never changes enemy pool")
				elif expected.upgrade_card:
					var card: Resource = run.upgrade_candidates()[0]
					var before_cost: int = card.cost
					check(run.choose_upgrade(card.identity_key()), "Choose upgrade")
					check(card.cost == before_cost and run.upgraded_cards[card.identity_key()].cost == before_cost, "Upgrade never mutates library")
				elif expected.resource_choice > 0:
					check(run.choose_attribute("energy") and run.modifier_value("energy") == expected.resource_choice, "Supply choice applied")
				elif expected.production_choice > 0:
					var before: int = run.production("quarters")
					check(run.choose_attribute("quarters") and run.production("quarters") == before + 1, "Shipyard production choice applied")
				run.ftl_charge = run.required_ftl_charge
				check(run.generate_system(), "Ready drive permits jump")
	# Thresholds depend on production, including expedition improvements, never ship names.
	run = fresh()
	var industrial: Resource = Rules.pois[0].approaches[2]
	check(not run.locked_reason(industrial).is_empty(), "Production two locks specialization")
	run.production_upgrades.synthesizer = 1
	check(run.locked_reason(industrial).is_empty(), "Production three unlocks specialization")
	run.production_upgrades.reactor = 1
	check(run.locked_reason(Rules.pois[1].approaches[2]).is_empty(), "Multiple specializations can coexist")
	run.add_modifiers({"synthesizer":5})
	run.production_upgrades.synthesizer = 0
	check(not run.locked_reason(industrial).is_empty(), "Next-battle production does not unlock permanent approaches")
	run.salvage = 3
	check(not run.locked_reason(Rules.trading_outpost.approaches[1]).is_empty(), "Insufficient Salvage locks paid services")
	run.salvage = 30
	check(not run.locked_reason(Rules.trading_outpost.approaches[0]).is_empty(), "Full Hull cannot waste a repair purchase")
	# Multiple PoIs add resources and Shields; production is unaffected.
	run = fresh(1)
	run.hull = 17
	run.salvage = 11
	run.production_upgrades.quarters = 2
	run.add_modifiers({"energy":3, "reactor":1, "emp_pulse_charge":999, "emp_pulse_offline":2, "shields":-4})
	run.add_modifiers({"energy":5, "reactor":2, "shields":-3})
	run.add_modifiers({"energy":-999, "synthesizer":-999, "crew":-999})
	check(run.modifier_value("reactor") == 0 and run.modifier_value("shields") == -7, "Production ignored; Shields accumulate")
	var board = make_board(run)
	check(board.player_hull == 17 and board.salvage == 11, "Battle uses persistent Hull and Salvage")
	check(board.enemy_ship_data.ship_name == "Sentinel", "Selected encounter enemy is honored")
	check(board.player_energy == run.ship().energy - floori(run.ship().energy * 0.5) + 8 + board.player_reactor and board.player_crew == run.ship().crew - floori(run.ship().crew * 0.5) + board.player_quarters and board.player_synthesizer == run.production("synthesizer"), "Half-base penalty cap before first-turn income; production intact")
	check(board.ftl.charge == board.ftl.charge_target and board.ftl.disabled_turns == 2 and not board.ftl.can_warp(), "FTL bonus capped; two-turn offline blocks warp")
	board.ftl.begin_player_turn()
	check(board.ftl.disabled_turns == 1, "Second player turn offline")
	board.ftl.begin_player_turn()
	check(board.ftl.disabled_turns == 0 and board.ftl.can_warp(), "Third player turn online")
	check(run.pending_bonuses.is_empty() and run.pending_penalties.is_empty(), "Modifiers consumed exactly once")
	board.player_hull = board.player_hull_capacity + 12
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	var after_reward: int = board.salvage
	board.refresh_display()
	check(board.salvage == 11 + run.victory_salvage(board.battle_result()) and after_reward == board.salvage, "Combat Salvage once")
	check(run.hull == run.ship().hull_capacity and run.salvage == board.salvage, "Plating stripped at result; Salvage synced")
	board.player_hull = 20
	board.repair_spend = 5
	board._repair_with_salvage()
	check(run.hull == 25 and run.salvage == after_reward - 10, "Victory repair uses same expedition currency and Hull")
	board.free()
	run.pending_bonuses.clear() # Isolate next encounter from earned tactical/strategic bonuses.
	run.pending_penalties.clear()
	board = make_board(run)
	check(board.player_energy == run.ship().energy + board.player_reactor and board.player_reactor == run.production("reactor"), "Temporary modifiers do not leak into second battle")
	check(board.player_quarters == run.ship().quarters + 2, "Shipyard production persists")
	board.ftl.charge = board.ftl.charge_target
	board._warp_out()
	check(board.salvage == after_reward - 10, "FTL escape grants no combat Salvage")
	board.free()
	run = fresh()
	board = make_board(run)
	board.enemy_quarters = 0
	board.enemy_reactor = 0
	board._sync_systems_failure()
	board.systems_failure.remaining.enemy = 0
	board._check_winner()
	board.refresh_display()
	check(run.salvage == Rules.destruction_salvage, "Systems Failure uses destruction Salvage")
	board.free()
	# Pool weights and upgraded identities still enforce two identical cards per hand.
	run = fresh()
	var base: Resource = Library.CARDS[2]
	for n in range(15): run.acquired_cards.append(base)
	run.pending_choice = "upgrade"
	check(run.choose_upgrade(base.identity_key()), "Upgrade acquired card")
	var hand = Hand.new()
	hand.card_pool = run.player_pool()
	hand.rng.seed = 55
	hand.current_round = 6
	hand.deal(6)
	for n in range(1000):
		hand.replace_card(n % 6)
		var counts: Dictionary = {}
		for card in hand.cards:
			check(card != null, "No empty draw with expedition pool")
			counts[card.identity_key()] = int(counts.get(card.identity_key(), 0)) + 1
			check(counts[card.identity_key()] <= 2, "Maximum two identical cards including upgraded copies")
	check(run.shared_pool()[2] == base and base.upgrade_level == 0, "Enemy pool never receives player upgrade")
	hand.free()
	run.active_battle = -1
	run.ftl_charge = run.required_ftl_charge
	check(run.generate_system() and run.acquired_cards.size() == 15 and run.upgraded_cards.size() == 1, "Cards and upgrades persist across systems")
	# Upgrade caps remain effective after repeated Resource duplication.
	for n in range(1):
		run.pending_choice = "upgrade"
		check(run.choose_upgrade(base.identity_key()), "Upgrade up to configured limit")
	check(run.upgraded_cards[base.identity_key()].upgrade_level == 2, "Upgrade level accumulates")
	run.pending_choice = "upgrade"
	check(not run.choose_upgrade(base.identity_key()), "Upgrade cap enforced")
	run.pending_choice = ""
	# All-upgraded fallback guarantees research is still rewarding.
	for candidate in run.player_pool():
		var capped: Resource = candidate.duplicate(true)
		capped.set_meta("card_identity", candidate.identity_key())
		capped.upgrade_level = capped.max_upgrades
		run.upgraded_cards[candidate.identity_key()] = capped
	put_poi(run, Rules.pois[3])
	var before_fallback: int = run.salvage
	check(run.resolve_approach(0, 1, 0.0), "Research resolves with exhausted upgrade pool")
	check(run.salvage == before_fallback + 5 + Rules.unavailable_upgrade_salvage and run.pending_choice.is_empty(), "Research fallback grants Salvage")
	# Pending effects survive travel and harmless PoIs, and strong penalties coexist with bonuses.
	run = fresh()
	run.add_modifiers({"energy":5, "emp_pulse_offline":1})
	run.add_modifiers({"energy":-3})
	put_poi(run, Rules.pois[0])
	run.resolve_approach(0, 0, 0.0)
	run.ftl_charge = run.required_ftl_charge
	run.generate_system()
	check(run.modifier_value("energy") == 2 and run.modifier_value("emp_pulse_offline") == 1, "Travel and PoI do not consume temporary modifiers")
	board = make_board(run)
	check(board.player_energy == run.ship().energy + 2 + board.player_reactor, "Opposing modifiers apply together")
	check(board.ftl.disabled_turns == 1 and board.ftl.charge == 0, "One-turn offline blocks first-turn charging")
	board.ftl.begin_player_turn()
	check(board.ftl.disabled_turns == 0 and board.ftl.charge == 1, "One-turn offline expires on second turn")
	board.free()
	# Low-Hull risk is real; no negative Hull, repeated charge or accidental resurrection.
	run = fresh()
	run.hull = 1
	put_poi(run, load("res://encounters/pirate_debris_field.tres"))
	check(run.resolve_approach(0, 1, 0.99) and run.hull == 0 and run.salvage == 2, "Fatal PoI still grants its reward and clamps Hull")
	check(not run.generate_system() and not run.can_visit(0), "Destroyed expedition cannot travel")
	run = fresh()
	run.hull -= 2
	run.salvage = 5
	while run.service.is_empty():
		run.ftl_charge = run.required_ftl_charge
		run.generate_system()
	check(run.purchase_service(0, run.service_revision, 2) and run.hull == run.ship().hull_capacity and run.salvage == 3, "Outpost repairs selected Hull with exact one-to-one price")
	# Live scene flow: opening battle -> result -> list -> PoI -> list -> chosen battle.
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = Rules.duplicate(true)
	host.rules.debug_seed = 345
	root.add_child(host)
	current_scene = host
	check(host.view_kind == "system" and host.battle == null, "No mandatory opening battle")
	for index in range(host.state.encounters.size()):
		if host.state.encounters[index].kind == "battle":
			host.state.encounters[index].enemy_data = load("res://ships/enemy/marauder.tres")
			host.visit(index)
			check(host.view_kind == "preview" and host.battle == null, "Enemy preview precedes battle")
			host.view.get_child(3).pressed.emit()
			break
	var battle = host.battle
	battle.battle_effects.enabled = false
	if battle.battle_effects.busy: await battle.battle_effects.finished
	battle.player_hull = 20
	battle.enemy_hull = 0
	battle._check_winner()
	battle.refresh_display()
	battle._continue_encounter()
	check(host.state.pending_choice == "upgrade", "Victory offers card upgrades before returning")
	host.state.finish_upgrades()
	host.show_system()
	await process_frame
	check(host.view_kind == "system" and host.state.hull == 20 and host.state.salvage == 10, "Victory Continue returns to list")
	host.state.encounters[5] = {"kind":"poi", "poi":Rules.pois[0], "title":"Mining Operation", "completed":false}
	host.visit(5)
	await host._approach(5, 0)
	check(host.view_kind == "outcome" and host.state.salvage == 13, "PoI reachable out of order with immediate rewards")
	host.show_system()
	check(host.state.encounters[5].completed, "Completed list row remains unavailable")
	var old_system: int = host.state.system_number
	host.state.ftl_charge = host.state.required_ftl_charge
	host._jump()
	check(host.state.system_number == old_system + 1 and host.state.hull == 20 and host.state.salvage == 13, "Charged jump preserves expedition state")
	for index in range(host.state.encounters.size() - 1, -1, -1):
		if host.state.encounters[index].kind == "battle":
			host.visit(index)
			check(host.view_kind == "preview" and host.battle == null, "Enemy preview precedes battle")
			host.view.get_child(3).pressed.emit()
			check(host.view_kind == "battle" and host.battle.player_hull == 20, "Choose arbitrary battle from new system")
			break
	host.free()
	await process_frame
	print("Expedition checks: %d failures" % failures)
	quit(1 if failures else 0)
