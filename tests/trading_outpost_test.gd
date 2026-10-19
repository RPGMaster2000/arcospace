extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Repairs = preload("res://scripts/repair_rules.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		if failures < 30: push_error(message)

func fresh(ship_index: int = 0, seed_value: int = 42) -> Resource:
	var run = State.new()
	var config = Rules.duplicate(true)
	config.debug_seed = seed_value
	config.log_rolls = false
	run.start(ship_index, config)
	return run

func advance(run: Resource) -> void:
	# Isolate station scheduling while respecting the new mandatory encounter gate.
	for entry in run.encounters:
		if entry.get("mandatory_boss", false): entry.completed = true
	run.ftl_charge = run.required_ftl_charge
	check(run.generate_system(), "Charged ship may leave an ignored station")

func reach_station(run: Resource) -> void:
	while run.service.is_empty(): advance(run)

func accounting(run: Resource) -> Array:
	return [run.ftl_charge, run.required_ftl_charge, run.remaining_ftl_charge(), run.encounters.duplicate(true), run.pending_penalties.duplicate()]

func encounter_signature(run: Resource) -> Array:
	# Separate cloned configurations may own distinct Boss Resources with equal values.
	var result: Array = []
	for entry in run.encounters:
		var snapshot: Dictionary = entry.duplicate()
		if entry.kind == "battle":
			var profile: Resource = run.enemy_profile(entry)
			snapshot.erase("enemy_data")
			snapshot["enemy_stats"] = [profile.ship_name, profile.enemy_rank, profile.hull_capacity, profile.shields, profile.materials, profile.energy, profile.crew, profile.synthesizer, profile.reactor, profile.quarters, profile.interstellar_ftl_reward, profile.destruction_salvage_reward]
		result.append(snapshot)
	return result

func schedule_checks() -> void:
	var firsts: Dictionary = {}
	var gaps: Dictionary = {}
	for seed_value in range(1, 201):
		var run = fresh(seed_value % 3, seed_value)
		var twin = fresh(seed_value % 3, seed_value)
		var without = fresh(seed_value % 3, seed_value)
		without.rules.trading_outpost = null
		var previous: int = 0
		check(run.system_number == 1 and run.service.is_empty() and run.next_outpost_system in [2,3], "No system-one station; first scheduled in two or three")
		for system in range(1, 31):
			check(run.system_name == twin.system_name and encounter_signature(run) == encounter_signature(twin) and run.service == twin.service and run.next_outpost_system == twin.next_outpost_system, "Debug seed reproduces station schedule and systems")
			check(encounter_signature(run) == encounter_signature(without) and run.required_ftl_charge == without.required_ftl_charge and run.rng.state == without.rng.state, "Station stream independent of encounters and travel accounting")
			check(run.encounters.size() == 6, "Station never replaces a progression encounter")
			var poi_count: int = 0
			for entry in run.encounters:
				if entry.kind == "poi": poi_count += 1
			check(run.required_ftl_charge == poi_count + 1, "Only non-trading PoIs set travel requirement")
			if not run.service.is_empty():
				if previous == 0: firsts[system] = true
				else:
					check(system - previous in [2,3], "Every station gap is two or three")
					gaps[system - previous] = true
				previous = system
				check(run.next_outpost_system - system in [2,3], "Next station scheduled on arrival")
			advance(run)
			advance(twin)
			advance(without)
	check(firsts.size() == 2 and gaps.size() == 2, "Seed sweep covers both first stations and both gaps")
	# Spending loot RNG on cards must not move the independently scheduled stations.
	var shopping = fresh()
	var ignoring = fresh()
	for system in range(1, 31):
		check(shopping.service.is_empty() == ignoring.service.is_empty() and shopping.next_outpost_system == ignoring.next_outpost_system, "Station schedule independent of card-purchase RNG")
		if not shopping.service.is_empty():
			shopping.salvage = 100
			for n in range(2):
				if shopping.available_reward_cards().is_empty():
					check(not shopping.purchase_service(2, shopping.service_revision), "Exhausted card service cannot spend Salvage")
				else:
					check(shopping.purchase_service(2, shopping.service_revision) and shopping.choose_card(0), "Shopping consumes loot RNG independently")
					if shopping.pending_choice == "replace":
						check(shopping.decline_card() and shopping.player_pool().size() == 30, "Full-deck shopping resolves by declining before travel")
		advance(shopping)
		advance(ignoring)
	for interval in [2,3]:
		var run = fresh()
		run.rules.minimum_station_interval = interval
		run.rules.maximum_station_interval = interval
		# Start again to exercise Inspector configuration from expedition initialization.
		run.start(0, run.rules, 42)
		check(run.next_outpost_system == interval, "Fixed Inspector interval respected")
		for n in range(20):
			if not run.service.is_empty(): check(run.system_number % interval == 0, "Fixed station spacing")
			advance(run)
	var invalid = fresh()
	invalid.rules.minimum_station_interval = 99
	invalid.rules.maximum_station_interval = 99
	invalid.start(0, invalid.rules, 42)
	check(invalid.next_outpost_system == 3, "Invalid Inspector bounds cannot exceed three")

func economy_checks(ship_index: int) -> void:
	var run = fresh(ship_index)
	reach_station(run)
	var before: Array = accounting(run)
	check(run.can_visit(State.SERVICE_INDEX) and not run.can_survey(State.SERVICE_INDEX) and not run.survey(State.SERVICE_INDEX), "Broke station entry and no survey")
	for slot in range(4): check(not run.purchase_service(slot, run.service_revision, 1), "Zero Salvage purchase refused")
	check(accounting(run) == before and run.can_visit(State.SERVICE_INDEX), "Declining station is free and leaves it available")
	check(not run.resolve_approach(State.SERVICE_INDEX, 1) and not run._complete_encounter(State.SERVICE_INDEX, 99), "PoI APIs cannot complete station or grant FTL")
	run.salvage = 50
	run.hull = run.ship().hull_capacity - 18
	var revision: int = run.service_revision
	for amount in [0, -1, 19, 51]: check(not run.purchase_service(0, revision, amount), "Invalid repair amount never spends")
	check(run.salvage == 50 and run.station_repair_limit() == 18, "Limit uses missing permanent Hull and affordability")
	check(run.purchase_service(0, revision, 12) and run.hull == run.ship().hull_capacity - 6 and run.salvage == 38, "Selected twelve Hull costs exactly twelve")
	check(not run.purchase_service(0, revision, 1) and run.salvage == 38, "Duplicate repair confirmation rejected")
	check(run.purchase_service(0, run.service_revision, 5) and run.purchase_service(0, run.service_revision, 1), "Repeat repairs at same station")
	check(run.hull == run.ship().hull_capacity and run.salvage == 32 and run.station_repair_limit() == 10, "Capacity reached; next purchase can install plating")
	check(run.station_hull_unit_cost() == 2 and run.station_hull_title() == "Install Ablative Plating", "At capacity the existing repair slot becomes plating")
	run.hull -= 5
	run.salvage = 2
	check(run.station_repair_limit() == 2 and not run.purchase_service(0, run.service_revision, 3), "Cannot repair beyond available Salvage")
	check(run.purchase_service(0, run.service_revision, 2) and run.salvage == 0, "Last two Salvage repair two Hull")
	check(Repairs.RESULT_SALVAGE_PER_HULL == 2, "Post-battle repairs cost two Salvage; station repair remains one")
	run.salvage = 100
	for n in range(3):
		revision = run.service_revision
		var balance: int = run.salvage
		check(run.purchase_service(1, revision) and run.salvage == balance - 7 and run.pending_choice == "resource", "Supplies cost seven immediately")
		check(not run.purchase_service(2, run.service_revision) and not run.can_jump() and not run.can_visit(State.SERVICE_INDEX), "Pending supply choice blocks purchases, entry and travel")
		check(not run.choose_attribute("reactor") and run.pending_choice == "resource", "Invalid resource choice cannot lose purchase")
		check(run.choose_attribute("materials") and not run.choose_attribute("materials"), "Supply reward chosen exactly once")
		check(not run.purchase_service(1, revision) and run.can_visit(State.SERVICE_INDEX), "Old confirmation cannot buy twice; station remains available")
	check(run.salvage == 79 and run.modifier_value("materials") == 15 and run.production_upgrades.is_empty(), "Repeated supplies stack without changing production")
	run.salvage = 6
	revision = run.service_revision
	check(not run.purchase_service(1, revision) and run.salvage == 6 and run.service_revision == revision, "Unaffordable supply does not spend or consume confirmation")
	run.salvage = 100
	for n in range(3):
		revision = run.service_revision
		var rng_before: int = run.rng.state
		check(run.purchase_service(2, revision) and run.card_offers.size() == 3 and run.salvage == 100 - 15 * (n + 1), "Repeated card price and offers")
		check(run.rng.state != rng_before, "Every card purchase draws fresh offers; random repeats remain legal")
		check(run.card_offers[0] != run.card_offers[1] and run.card_offers[1] != run.card_offers[2] and run.card_offers[0] != run.card_offers[2], "Three distinct offers")
		check(not run.purchase_service(1, run.service_revision) and not run.generate_system(), "Card selection blocks spending and departure")
		check(not run.choose_card(3) and run.pending_choice == "card", "Invalid card choice leaves selection pending")
		check(run.choose_card(n % 3) and not run.choose_card(n % 3) and not run.purchase_service(2, revision), "Card selection and confirmation cannot duplicate")
	check(run.acquired_cards.size() == 3 and run.shared_pool().size() == 68 and run.player_pool().size() == 28, "Acquisitions extend only the ship's player pool")
	run.salvage = 14
	check(not run.purchase_service(2, run.service_revision) and run.salvage == 14, "Card affordability verified before spending")
	run.salvage = 1000
	for n in range(7):
		var price: int = [25,40,60,85,115,150,190][n]
		check(run.service_cost(3) == price, "Intended production price progression")
		var balance: int = run.salvage
		revision = run.service_revision
		check(run.purchase_service(3, revision) and run.salvage == balance - price, "Production price deducted once")
		check(not run.purchase_service(3, run.service_revision), "Pending production selection blocks next upgrade")
		check(run.choose_attribute(State.PRODUCTION[n % 3]) and not run.choose_attribute(State.PRODUCTION[n % 3]), "Combined category counter; choice exactly once")
		check(not run.purchase_service(3, revision), "Stale production confirmation cannot duplicate")
	var upgrades: Dictionary = run.production_upgrades.duplicate()
	check(upgrades.synthesizer == 3 and upgrades.reactor == 2 and upgrades.quarters == 2, "Permanent category selections applied")
	run.salvage = run.service_cost(3) - 1
	var balance: int = run.salvage
	check(not run.purchase_service(3, run.service_revision) and run.salvage == balance and run.station_production_purchases == 7, "Unaffordable upgrade changes neither balance nor price counter")
	check(accounting(run) == before and not run.service.completed, "All station purchases leave progression/penalties/completion untouched")
	revision = run.service_revision
	advance(run)
	check(run.service.is_empty() and not run.can_visit(State.SERVICE_INDEX), "Station disappears after departure")
	reach_station(run)
	check(run.service_cost(3) == 25 and run.station_production_purchases == 0 and run.production_upgrades == upgrades, "Next station resets prices but preserves permanent production")
	check(not run.purchase_service(1, revision), "Old station confirmation cannot apply at new station")
	# Inspector base price and both escalating parameters stay data-driven.
	var tuned_poi: Resource = run.service.poi.duplicate()
	tuned_poi.approaches = run.service.poi.approaches.duplicate()
	tuned_poi.approaches[3] = tuned_poi.approaches[3].duplicate(true)
	run.service.poi = tuned_poi
	run.service.poi.approaches[3].salvage_cost = 30
	run.rules.production_price_increment = 20
	run.rules.production_price_acceleration = 7
	run.station_production_purchases = 2
	check(run.service_cost(3) == 77, "Inspector base/increment/acceleration used")
	# Enter a real battle to verify purchased supplies still use additive/capped modifiers once.
	run.add_modifiers({"materials":-999})
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {"player_ship":ship_index, "enemy_ship":0, "modifier":0}
	board.expedition = run
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	check(board.player_materials == run.ship().materials + 15 - floori(run.ship().materials * 0.5) + run.production("synthesizer"), "Supply stacking and fifty-percent cap reach real battle")
	check(run.pending_bonuses.is_empty() and run.pending_penalties.is_empty(), "Purchased modifiers consumed on battle entry")
	board.free()

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	schedule_checks()
	for ship_index in range(preload("res://scripts/ship_library.gd").PLAYERS.size()): economy_checks(ship_index)
	check(Rules.trading_outpost.approaches[3].salvage_cost == 25 and Rules.production_price_increment == 15 and Rules.production_price_acceleration == 5, "Purchases and test tuning never mutate shared authored prices")
	print("Trading Outpost: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

