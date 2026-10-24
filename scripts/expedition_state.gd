extends Resource
# RESPONSIBILITY: Own expedition state, generation, rewards and battle handoff.
# DOES NOT: Create UI nodes, animate travel or resolve individual combat actions.
# EXTEND: Deck owns card transactions; this facade coordinates encounters and persistence.
class_name ExpeditionState
signal deck_changed
signal progress_committed
var run_ended: bool = false
const BattleSetup = preload("res://scripts/combat/battle_setup.gd")
const BattleResult = preload("res://scripts/combat/battle_result.gd")
const ShipState = preload("res://scripts/combat/ship_combat_state.gd")
var _recorded_results: Dictionary = {}

const Modifiers = preload("res://scripts/combat_modifier.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Repairs = preload("res://scripts/repair_rules.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const PRODUCTION = preload("res://scripts/combat/ship_combat_state.gd").PRODUCTION
const RESOURCES = preload("res://scripts/combat/ship_combat_state.gd").RESOURCES
const LABELS = {
	"synthesizer": "Synthesizer",
	"reactor": "Reactor",
	"quarters": "Quarters",
	"materials": "Materials",
	"energy": "Energy",
	"crew": "Crew",
	"shields": "Shields",
	"emp_pulse_charge": "EMP Pulse charge",
	"emp_pulse_offline": "EMP Pulse offline turns"
}
var rules: Resource
var player_ship: int = 0
var hull: int = 0
var salvage: int = 0
var battles_won: int = 0
var ftl_charge: int = 0
var required_ftl_charge: int = 0
var system_number: int = 0
var system_name: String = ""
var encounters: Array[Dictionary] = []
# Independent service visit, deliberately outside the six progression encounters.
const SERVICE_INDEX = -2
var service: Dictionary = {}
var next_outpost_system: int = 0
var station_production_purchases: int = 0
# Each confirmation carries this revision; an old confirmation can never spend twice.
var service_revision: int = 0
var station_rng := RandomNumberGenerator.new()

const Deck = preload("res://scripts/expedition/expedition_deck.gd")
var _deck := Deck.new()
# Compatibility/codec facade, never parallel state. Collection containers are copies;
# CardData definitions remain shared read-only values as in the existing battle contract.
# Normal callers mutate through choose/replace/upgrade; setters support restored fixtures.
var acquired_cards: Array[Resource]:
	get: return _deck.acquired_cards.duplicate()
	set(value): _deck.acquired_cards = value.duplicate()
var upgraded_cards: Dictionary:
	get: return _deck.upgraded_cards.duplicate()
	set(value): _deck.upgraded_cards = value.duplicate()
var removed_starting_cards: Dictionary:
	get: return _deck.removed_starting_cards.duplicate()
	set(value): _deck.removed_starting_cards = value.duplicate()
var pending_card: Resource:
	get: return _deck.pending_card
	set(value): _deck.pending_card = value
var upgrades_remaining: int:
	get: return _deck.upgrades_remaining
	set(value): _deck.upgrades_remaining = value
var upgraded_this_event: Dictionary:
	get: return _deck.upgraded_this_event.duplicate()
	set(value): _deck.upgraded_this_event = value.duplicate()
var card_offers: Array[Resource]:
	get: return _deck.card_offers.duplicate()
	set(value): _deck.card_offers = value.duplicate()
var pending_choice: String:
	get: return _deck.pending_choice
	set(value): _deck.pending_choice = value

var production_upgrades: Dictionary = {}
var pending_bonuses: Dictionary = {}
var pending_penalties: Dictionary = {}
var choice_amount: int = 0
var last_outcome: String = ""
# -1 = no rolled PoI result (station/survey/battle); 0 = worse branch; 1 = success branch.
var last_poi_success: int = -1
# In-memory travel interruption; no separate combat or persistence system.
var navigation_origin: int = -1
var travel_destination: int = -1
var pending_destination: int = -1
var chasedown_index: int = -1
var chasedowns_this_system: int = 0
var chasedown_rng := RandomNumberGenerator.new()
var field_repairs_open: bool = false  # Set only by the exploration controller while the system view is open.
var active_battle: int = -1
var rng := RandomNumberGenerator.new()
var seed_used: int = 0

#region Run setup


func encounter_at(index: int) -> Dictionary:
	return service if index == SERVICE_INDEX else encounters[index]


func start(ship_index: int, configuration: Resource, seed_override: int = 0) -> void:
	run_ended = false
	rules = configuration
	player_ship = clampi(ship_index, 0, Ships.PLAYERS.size() - 1)
	hull = ship().hull_capacity
	salvage = 0
	battles_won = 0
	system_number = 0
	ftl_charge = 0
	required_ftl_charge = 0
	next_outpost_system = 0
	station_production_purchases = 0
	service_revision += 1
	production_upgrades.clear()
	pending_bonuses.clear()
	pending_penalties.clear()
	_deck.reset()
	_recorded_results.clear()
	last_poi_success = -1
	active_battle = -1
	field_repairs_open = false
	var chosen_seed: int = seed_override if seed_override != 0 else rules.debug_seed
	if chosen_seed == 0:
		rng.randomize()
	else:
		rng.seed = chosen_seed
	seed_used = rng.seed
	# Separate stream: station frequency cannot change six-encounter generation or loot rolls.
	station_rng.seed = seed_used ^ 0x53544154494F4E
	chasedown_rng.seed = seed_used ^ 0x4348415345
	next_outpost_system = _station_interval()
	generate_system()


func ship() -> Resource:
	return Ships.PLAYERS[player_ship]


func production(key: String) -> int:
	return int(ship().get(key)) + int(production_upgrades.get(key, 0))


#endregion

#region Systems and navigation


func can_jump() -> bool:
	return (
		hull > 0
		and not run_ended
		and active_battle < 0
		and pending_destination < 0
		and pending_choice.is_empty()
		and ftl_charge >= required_ftl_charge
		and not mandatory_boss_pending()
	)


func mandatory_boss_pending() -> bool:
	var found: bool = false
	for encounter in encounters:
		if encounter.get("mandatory_boss", false):
			found = true
			if not encounter.completed:
				return true
	# Fail closed if a malformed/custom milestone loses its mandatory encounter.
	return not found and rules.progression.is_boss_system(system_number)


func difficulty_level() -> int:
	return rules.progression.difficulty_level(system_number)


func _enemy_index(items: Array) -> int:
	if difficulty_level() == 1:
		return _weighted_index(items)
	var elites: Array = []
	var others: Array = []
	for profile in items:
		if profile.enemy_rank == 1:
			elites.append(profile)
		else:
			others.append(profile)
	if elites.is_empty() or others.is_empty():
		return _weighted_index(items)
	var bucket: Array = (
		elites
		if rng.randf() < rules.progression.elite_probability(items, system_number)
		else others
	)
	return items.find(bucket[_weighted_index(bucket)])


func _weighted_index(items: Array) -> int:
	var total: float = 0.0
	for item in items:
		total += maxf(0.01, item.encounter_weight)
	var roll: float = rng.randf() * total
	for index in range(items.size()):
		roll -= maxf(0.01, items[index].encounter_weight)
		if roll <= 0:
			return index
	return items.size() - 1


func _station_interval() -> int:
	var low: int = clampi(rules.minimum_station_interval, 2, 3)
	var high: int = clampi(rules.maximum_station_interval, low, 3)
	return station_rng.randi_range(low, high)


# Generate encounters from one rules registry; both map and grid read this same array.
# Carryover and mandatory Boss replacement happen here, independently of presentation.
func generate_system() -> bool:
	if not pending_choice.is_empty() or active_battle >= 0 or hull <= 0:
		return false
	if system_number > 0 and not can_jump():
		return false
	var carried_charge: int = (
		rules.progression.carryover(ftl_charge, required_ftl_charge) if system_number > 0 else 0
	)
	var ordinary: Array = []
	var hazardous: Array = []
	for poi in rules.pois:
		if poi.hazardous:
			hazardous.append(poi)
		else:
			ordinary.append(poi)
	var enemies: Array = rules.enemy_ships.duplicate()
	if enemies.is_empty():
		enemies.assign(Ships.ENEMIES)
	var count: int = maxi(2, rules.encounters_per_system)
	var compositions: Array[Dictionary] = []
	var total_weight: float = 0.0
	for battles in range(1, count + 1):
		for hazards in range(count - battles + 1):
			var normal: int = count - battles - hazards
			if battles < rules.minimum_battles or battles > rules.maximum_battles:
				continue
			if normal < rules.minimum_ordinary or normal > rules.maximum_ordinary:
				continue
			if hazards < rules.minimum_hazardous or hazards > rules.maximum_hazardous:
				continue
			if (normal > 0 and ordinary.is_empty()) or (hazards > 0 and hazardous.is_empty()):
				continue
			var weight: float = (
				pow(maxf(.01, rules.battle_weight), battles)
				* pow(maxf(.01, rules.ordinary_weight), normal)
				* pow(maxf(.01, rules.hazardous_weight), hazards)
			)
			total_weight += weight
			compositions.append(
				{"battle": battles, "ordinary": normal, "hazardous": hazards, "weight": weight}
			)
	var composition: Dictionary
	if compositions.is_empty():
		push_warning(
			"Encounter bounds cannot fill a system. Falling back to one enemy and available PoIs (or all enemies if no PoIs exist)."
		)
		composition = {
			"battle": 1,
			"ordinary": count - 1 if not ordinary.is_empty() else 0,
			"hazardous": count - 1 if ordinary.is_empty() and not hazardous.is_empty() else 0
		}
		if ordinary.is_empty() and hazardous.is_empty():
			composition.battle = count
	else:
		var roll: float = rng.randf() * total_weight
		composition = compositions.back()
		for candidate in compositions:
			roll -= candidate.weight
			if roll <= 0:
				composition = candidate
				break
	_recorded_results.clear()
	system_number += 1
	var names = ["Arco", "Kepler", "Vela", "Orion", "Lyra", "Perseus"]
	system_name = "%s %d" % [names[rng.randi_range(0, names.size() - 1)], system_number]
	navigation_origin = -1
	travel_destination = -1
	pending_destination = -1
	chasedown_index = -1
	chasedowns_this_system = 0
	encounters.clear()
	service = {}
	if system_number >= next_outpost_system:
		if rules.trading_outpost != null:
			service = {
				"kind": "service",
				"poi": rules.trading_outpost,
				"title": rules.trading_outpost.title,
				"completed": false
			}
			station_production_purchases = 0
		next_outpost_system = system_number + _station_interval()
	service_revision += 1
	ftl_charge = carried_charge
	required_ftl_charge = int(composition.ordinary) + int(composition.hazardous) + 1
	var boss_system: bool = rules.progression.is_boss_system(system_number)
	var boss_added: bool = false
	# Milestones have one Boss, replacing an existing enemy slot, never a PoI.
	if boss_system:
		var ordinary_enemies: Array = []
		for profile in enemies:
			if profile.enemy_rank != 2:
				ordinary_enemies.append(profile)
		if not ordinary_enemies.is_empty():
			enemies = ordinary_enemies
	for category in ["ordinary", "hazardous", "battle"]:
		var library: Array = (
			enemies if category == "battle" else (ordinary if category == "ordinary" else hazardous)
		)
		var available: Array = library.duplicate()
		for slot in range(int(composition[category])):
			if available.is_empty():
				available = library.duplicate()
			var mandatory: bool = category == "battle" and boss_system and not boss_added
			var entry: Resource
			if mandatory:
				entry = rules.progression.mandatory_boss_profile()
				boss_added = true
			else:
				entry = available.pop_at(
					_enemy_index(available) if category == "battle" else _weighted_index(available)
				)
			if category == "battle":
				encounters.append(
					{
						"kind": "battle",
						"enemy": maxi(0, Ships.ENEMIES.find(entry)),
						"enemy_data": entry,
						"system_number": system_number,
						"mandatory_boss": mandatory,
						"modifier": _roll_battle_modifier(),
						"title": entry.ship_name,
						"completed": false,
						"charge_awarded": false
					}
				)
			else:
				encounters.append(
					{
						"kind": "poi",
						"poi": entry,
						"title": entry.title,
						"completed": false,
						"charge_awarded": false
					}
				)
	for index in range(encounters.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Dictionary = encounters[index]
		encounters[index] = encounters[other]
		encounters[other] = swap
	progress_committed.emit()
	return true


# One authoritative uniform roll; overridable only for historical-distribution trace fixtures.
func _roll_battle_modifier() -> int:
	return Modifiers.roll_encounter(rng)


func enemy_profile(encounter: Dictionary) -> Resource:
	var base: Resource = encounter.get("enemy_data", Ships.ENEMIES[int(encounter.get("enemy", 0))])
	return rules.progression.scaled_enemy(base, int(encounter.get("system_number", system_number)))


func encounter_charge(index: int) -> int:
	if index == SERVICE_INDEX:
		return 0
	if encounters[index].get("chasedown", false):
		return 1
	return (
		1
		if encounters[index].kind == "poi"
		else maxi(1, enemy_profile(encounters[index]).interstellar_ftl_reward)
	)


# Single completion gate: award travel charge once, shared by PoI resolution and battle results.
func _complete_encounter(index: int, extra_charge: int = 0) -> bool:
	if index == SERVICE_INDEX:
		return false
	if index < 0 or index >= encounters.size() or encounters[index].get("charge_awarded", false):
		return false
	encounters[index].completed = true
	encounters[index].charge_awarded = true
	ftl_charge += encounter_charge(index) + maxi(0, extra_charge)
	return true


## Conservative remaining charge: ignores optional wormhole bonuses.
func remaining_ftl_charge() -> int:
	var result: int = 0
	for index in range(encounters.size()):
		if not encounters[index].completed and not encounters[index].get("charge_awarded", false):
			result += encounter_charge(index)
	return result


func can_survey(index: int) -> bool:
	if not can_visit(index) or index == SERVICE_INDEX or encounters[index].kind != "poi":
		return false
	for approach in encounters[index].poi.approaches:
		if not locked_reason(approach).is_empty():
			continue
		var worst: int = approach.success.hull
		if approach.success_chance < 1:
			worst = mini(worst, approach.failure.hull)
		if hull + worst > 0:
			return false
	return true


func survey(index: int) -> bool:
	if not can_survey(index):
		return false
	last_poi_success = -1
	_complete_encounter(index)
	add_modifiers(rules.survey_penalty)
	last_outcome = (
		"Navigation survey completed. +1 FTL Drive charge. No Salvage or other rewards. Next battle: "
		+ describe_modifiers(rules.survey_penalty)
	)
	progress_committed.emit()
	return true


func can_visit(index: int) -> bool:
	if travel_destination != -1 and pending_destination < 0 and index != travel_destination:
		return false
	if run_ended or hull <= 0 or active_battle >= 0 or not pending_choice.is_empty():
		return false
	if pending_destination >= 0 and index != chasedown_index:
		if chasedown_unresolved() or index != pending_destination:
			return false
	if index == chasedown_index and chasedown_unresolved() and encounters[index].response < 0:
		return false
	if index == SERVICE_INDEX:
		return not service.is_empty()
	return index >= 0 and index < encounters.size() and not encounters[index].completed


# Roll once at actual movement initiation; arrival, menus and battle returns never call this.
# Independent RNG leaves authored encounter generation and PoI outcome rolls unchanged.
func begin_travel(destination: int, forced_roll: float = -1.0) -> bool:
	if not can_visit(destination): return false
	if travel_destination == destination: return false
	var intercepted: bool = try_chasedown(destination, forced_roll)
	travel_destination = destination
	progress_committed.emit()
	return intercepted


func try_chasedown(destination: int, forced_roll: float = -1.0) -> bool:
	if not can_visit(destination) or destination < 0 or encounters[destination].kind != "poi":
		return false
	if pending_destination >= 0 or navigation_origin < 0 or navigation_origin == destination:
		return false
	if navigation_origin >= encounters.size() or encounters[navigation_origin].kind != "poi":
		return false
	if chasedowns_this_system >= maxi(0, rules.chasedown_limit):
		return false
	var pool: Array = []
	for profile in rules.enemy_ships:
		if profile.enemy_rank == 0:
			pool.append(profile)
	if pool.is_empty():
		for profile in Ships.ENEMIES:
			if profile.enemy_rank == 0:
				pool.append(profile)
	if pool.is_empty():
		return false
	var chance: float = clampf(rules.chasedown_chance, 0.0, 1.0)
	if chance <= 0:
		return false
	var roll: float = chasedown_rng.randf() if forced_roll < 0 else forced_roll
	if roll >= chance:
		return false
	var total: float = 0.0
	for profile in pool:
		total += maxf(0.01, profile.encounter_weight)
	var selection: float = chasedown_rng.randf() * total
	var enemy: Resource = pool.back()
	for profile in pool:
		selection -= maxf(0.01, profile.encounter_weight)
		if selection <= 0:
			enemy = profile
			break
	pending_destination = destination
	chasedowns_this_system += 1
	chasedown_index = encounters.size()
	# Existing encounter/result pipeline awards exactly one unit; this entry has no map marker.
	encounters.append(
		{
			"kind": "battle",
			"enemy": maxi(0, Ships.ENEMIES.find(enemy)),
			"enemy_data": enemy,
			"system_number": system_number,
			"modifier": 0,
			"mandatory_boss": false,
			"chasedown": true,
			"response": -1,
			"title": "Sublight Chasedown",
			"completed": false,
			"charge_awarded": false
		}
	)
	return true


func chasedown_unresolved() -> bool:
	return (
		chasedown_index >= 0
		and chasedown_index < encounters.size()
		and not encounters[chasedown_index].completed
	)


func choose_chasedown_response(choice: int) -> bool:
	if (
		hull <= 0
		or not chasedown_unresolved()
		or active_battle >= 0
		or not pending_choice.is_empty()
	):
		return false
	var encounter: Dictionary = encounters[chasedown_index]
	if encounter.response >= 0 or choice < 0 or choice >= rules.chasedown_responses.size():
		return false
	var response: Dictionary = rules.chasedown_responses[choice]
	encounter.response = choice
	add_modifiers(response.get("modifiers", {}))
	hull = maxi(1, hull + int(response.get("hull", 0)))
	progress_committed.emit()
	return true


func arrive_destination(index: int) -> void:
	navigation_origin = index
	if index == travel_destination: travel_destination = -1
	if index == pending_destination and not chasedown_unresolved():
		pending_destination = -1
	progress_committed.emit()


#endregion

#region Approaches and modifiers


func locked_reason(approach: Resource) -> String:
	if (
		not approach.requirement.is_empty()
		and production(approach.requirement) < approach.minimum_production
	):
		return (
			"Requires %s ≥%d (you have %d)"
			% [
				LABELS[approach.requirement],
				approach.minimum_production,
				production(approach.requirement)
			]
		)
	if salvage < approach.salvage_cost:
		return "Requires %d Salvage (you have %d)" % [approach.salvage_cost, salvage]
	if approach.success.hull > 0 and hull >= ship().hull_capacity:
		return "Hull already full"
	return ""


# Validate/pay the approach, roll its outcome and complete the PoI before applying rewards.
# forced_roll is a deterministic test hook; normal play uses this expedition's RNG.
func resolve_approach(index: int, approach_index: int, forced_roll: float = -1.0) -> bool:
	if index == SERVICE_INDEX or not can_visit(index) or encounter_at(index).kind != "poi":
		return false
	var poi: Resource = encounter_at(index).poi
	if approach_index < 0 or approach_index >= poi.approaches.size():
		return false
	var approach: Resource = poi.approaches[approach_index]
	if not locked_reason(approach).is_empty():
		return false
	salvage -= approach.salvage_cost
	var roll: float = rng.randf() if forced_roll < 0 else forced_roll
	var success: bool = roll < approach.success_chance
	var outcome: Resource = approach.success if success else approach.failure
	if not _complete_encounter(index, outcome.extra_ftl_charge):
		return false
	last_poi_success = 1 if success else 0
	# The roll and seed are printed for reproducing balance reports.
	if rules.log_rolls:
		print(
			(
				"Expedition seed=%d system=%d encounter=%d approach=%d roll=%.4f success=%s"
				% [seed_used, system_number, index, approach_index, roll, success]
			)
		)
	last_outcome = outcome.blurb + "\n" + describe_outcome(outcome)
	last_outcome += "\n+%d FTL Drive charge." % (1 + outcome.extra_ftl_charge)
	if approach.salvage_cost > 0:
		last_outcome += "\nSpent %d Salvage." % approach.salvage_cost
	_apply_outcome(outcome)
	progress_committed.emit()
	return true


# Apply immediate Hull/Salvage and queue next-battle modifiers plus at most one choice type.
# EXTEND: New reward fields also need EncounterOutcome, describe_outcome and expedition UI/test coverage.
func _apply_outcome(outcome: Resource) -> void:
	salvage += outcome.salvage
	# Combined Hull model: neutral outcomes preserve purchased plating. Positive PoI repairs
	# cannot add plating; damaging PoIs reduce the combined total (agreed single-value rule).
	if outcome.hull < 0:
		hull = maxi(0, hull + outcome.hull)
	elif outcome.hull > 0 and hull < ship().hull_capacity:
		hull = mini(ship().hull_capacity, hull + outcome.hull)
	add_modifiers(outcome.next_battle)
	if outcome.card_reward:
		last_outcome += _deck.start_card_reward(ship(), rules, rng, outcome.minimum_card_tier)
	elif outcome.upgrade_card:
		if upgrade_candidates().is_empty():
			salvage += rules.unavailable_upgrade_salvage
			last_outcome += (
				"\nAll cards fully upgraded: +%d Salvage instead."
				% rules.unavailable_upgrade_salvage
			)
		else:
			start_upgrade_event(1)
	elif outcome.resource_choice > 0:
		pending_choice = "resource"
		choice_amount = outcome.resource_choice
	elif outcome.production_choice > 0:
		pending_choice = "production"
		choice_amount = outcome.production_choice


func add_modifiers(values: Dictionary) -> void:
	for key in values:
		var amount: int = int(values[key])
		# Temporary production modifiers are unsupported; outpost upgrades use their own ledger.
		if key in PRODUCTION:
			continue
		if key == "emp_pulse_offline":
			pending_bonuses[key] = maxi(int(pending_bonuses.get(key, 0)), amount)
		elif amount > 0:
			pending_bonuses[key] = int(pending_bonuses.get(key, 0)) + amount
		elif amount < 0:
			pending_penalties[key] = int(pending_penalties.get(key, 0)) + amount


func modifier_value(key: String) -> int:
	return int(pending_bonuses.get(key, 0)) + int(pending_penalties.get(key, 0))


## Resource penalties cap against unmodified ship starts, before normal turn income.
func starting_value(profile: Resource, key: String) -> int:
	var base: int = int(profile.get(key))
	var penalty: int = absi(int(pending_penalties.get(key, 0)))
	if key in RESOURCES:
		penalty = mini(penalty, floori(base * 0.5))
	return maxi(0, base + int(pending_bonuses.get(key, 0)) - penalty)


func describe_modifiers(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key in values:
		parts.append("%+d %s" % [values[key], LABELS.get(key, key)])
	return " · ".join(parts)


func describe_outcome(outcome: Resource) -> String:
	var parts: Array[String] = []
	if outcome.extra_ftl_charge > 0:
		parts.append("+%d extra FTL Drive charge" % outcome.extra_ftl_charge)
	if outcome.salvage != 0:
		parts.append("%+d Salvage" % outcome.salvage)
	if outcome.hull != 0:
		parts.append("%+d permanent Hull" % outcome.hull)
	for key in outcome.next_battle:
		parts.append("%+d %s next battle" % [outcome.next_battle[key], LABELS.get(key, key)])
	if outcome.card_reward:
		parts.append(
			(
				"Choose 1 of 3 %scards"
				% ("uncommon-or-better " if outcome.minimum_card_tier > 1 else "")
			)
		)
	if outcome.upgrade_card:
		parts.append("Upgrade one player card")
	if outcome.resource_choice > 0:
		parts.append("+%d starting resource of choice next battle" % outcome.resource_choice)
	if outcome.production_choice > 0:
		parts.append("+%d production of choice for expedition" % outcome.production_choice)
	return " · ".join(parts)


func pending_description() -> String:
	var parts: Array[String] = []
	var keys: Array = pending_bonuses.keys()
	for key in pending_penalties:
		if not keys.has(key):
			keys.append(key)
	for key in keys:
		var positive: int = int(pending_bonuses.get(key, 0))
		var negative: int = int(pending_penalties.get(key, 0))
		if positive > 0:
			parts.append("+%d %s" % [positive, LABELS.get(key, key)])
		if negative < 0:
			parts.append("%d %s" % [negative, LABELS.get(key, key)])
	return "None" if parts.is_empty() else " · ".join(parts)


#endregion

#region Repairs and services


func field_repair_limit() -> int:
	if not field_repairs_open or active_battle >= 0 or not pending_choice.is_empty() or hull <= 0:
		return 0
	return Repairs.max_quantity(hull, ship().hull_capacity, salvage, Repairs.FIELD_SALVAGE_PER_HULL)


# A confirmation is consumed once. A second purchase requires a fresh revision/selection.
func field_repair(amount: int, revision: int) -> bool:
	if revision != service_revision or amount <= 0 or amount > field_repair_limit():
		return false
	salvage -= Repairs.quantity_cost(amount, Repairs.FIELD_SALVAGE_PER_HULL)
	hull += amount
	service_revision += 1
	progress_committed.emit()
	return true


func station_plating_mode() -> bool:
	return hull >= ship().hull_capacity


func station_hull_ceiling() -> int:
	return ship().hull_capacity + (Repairs.STATION_PLATING_LIMIT if station_plating_mode() else 0)


func station_hull_unit_cost() -> int:
	return Repairs.PLATING_SALVAGE_PER_POINT if station_plating_mode() else 1


func station_hull_title() -> String:
	if not station_plating_mode():
		return "Repair Hull"
	return "Ablative Plating Full" if hull >= station_hull_ceiling() else "Install Ablative Plating"


## Shared quantity bounds; damaged Hull uses 1:1 repairs, full Hull uses 2:1 plating.
func station_repair_limit() -> int:
	return Repairs.max_quantity(hull, station_hull_ceiling(), salvage, station_hull_unit_cost())


func service_is_repair(slot: int) -> bool:
	return (
		not service.is_empty()
		and slot >= 0
		and slot < service.poi.approaches.size()
		and service.poi.approaches[slot].success.hull > 0
	)


func service_cost(slot: int, repair_amount: int = 1) -> int:
	if service.is_empty() or slot < 0 or slot >= service.poi.approaches.size():
		return 0
	var approach: Resource = service.poi.approaches[slot]
	if approach.success.hull > 0:
		return Repairs.quantity_cost(repair_amount, station_hull_unit_cost())
	if approach.success.production_choice > 0:
		var bought: int = station_production_purchases
		return (
			approach.salvage_cost
			+ rules.production_price_increment * bought
			+ rules.production_price_acceleration * bought * (bought - 1) / 2
		)
	return approach.salvage_cost


func service_locked_reason(slot: int) -> String:
	if not can_visit(SERVICE_INDEX):
		return "Station unavailable or resolve pending choice first"
	if slot < 0 or slot >= service.poi.approaches.size():
		return "Unknown service"
	var approach: Resource = service.poi.approaches[slot]
	if (
		approach.success.card_reward
		and available_reward_cards(approach.success.minimum_card_tier).is_empty()
	):
		return "No unowned cards meet this reward's minimum tier"
	if approach.success.hull > 0 and hull >= station_hull_ceiling():
		return "Ablative Plating Full"
	var cost: int = service_cost(slot)
	if salvage < cost:
		return "Requires %d Salvage (you have %d)" % [cost, salvage]
	return ""


# Use a confirmation revision to reject stale purchases; services never complete a progression PoI.
func purchase_service(slot: int, revision: int, repair_amount: int = 0) -> bool:
	if revision != service_revision or not service_locked_reason(slot).is_empty():
		return false
	var outcome: Resource = service.poi.approaches[slot].success
	if outcome.hull > 0 and (repair_amount <= 0 or repair_amount > station_repair_limit()):
		return false
	var cost: int = service_cost(slot, repair_amount)
	if cost < 0 or cost > salvage:
		return false
	# Validate everything before spending; consume confirmation before applying any reward.
	last_poi_success = -1
	salvage -= cost
	service_revision += 1
	last_outcome = "Spent %d Salvage. " % cost
	if outcome.hull > 0:
		var plating: bool = station_plating_mode()
		hull += repair_amount
		last_outcome += (
			("Installed %d Ablative Plating." if plating else "Repaired %d permanent Hull.")
			% repair_amount
		)
	else:
		if outcome.production_choice > 0:
			station_production_purchases += 1
		last_outcome += describe_outcome(outcome)
		_apply_outcome(outcome)
	progress_committed.emit()
	return true


#endregion

#region Owned cards and rewards


## Compatibility name: always the unmodified enemy library, never expedition acquisitions.
func shared_pool() -> Array[Resource]:
	var pool: Array[Resource] = []
	pool.assign(Cards.CARDS)
	return pool


# Build owned identities with player-only upgrade copies; shared_pool remains the enemy base library.
func player_pool() -> Array[Resource]:
	return _deck.player_pool(ship())


func acquired_draw_weights() -> Dictionary:
	return _deck.acquired_draw_weights(rules)


func available_reward_cards(minimum_tier: int = 1) -> Array[Resource]:
	return _deck.available_reward_cards(ship(), minimum_tier)


func random_card_offers(minimum_tier: int = 1) -> Array[Resource]:
	return _deck.random_card_offers(ship(), rules, rng, minimum_tier)


func choose_card(index: int) -> bool:
	return _commit_deck_choice(_deck.choose_card(index, ship(), rules))


func deck_limit() -> int:
	return _deck.deck_limit(ship(), rules)


# A successful card transaction notifies live hands before the existing autosave boundary.
func _commit_deck_choice(result: Dictionary) -> bool:
	if result.is_empty():
		return false
	last_outcome += result.message
	if result.deck_changed:
		deck_changed.emit()
	progress_committed.emit()
	return true


func deck_snapshot() -> Dictionary:
	return _deck.snapshot()


# Save codec has already validated registry references and the version-1 payload.
func restore_deck(data: Dictionary, cards: Dictionary) -> void:
	_deck.restore(data, cards)


func replace_card(key: String) -> bool:
	return _commit_deck_choice(_deck.replace_card(key, ship(), rules))


func decline_card() -> bool:
	return _commit_deck_choice(_deck.decline_card())


func choose_attribute(key: String) -> bool:
	if pending_choice == "resource" and key in RESOURCES:
		add_modifiers({key: choice_amount})
		last_outcome += "\nNext battle: +%d %s." % [choice_amount, LABELS[key]]
	elif pending_choice == "production" and key in PRODUCTION:
		production_upgrades[key] = int(production_upgrades.get(key, 0)) + choice_amount
		last_outcome += "\nExpedition: +%d %s." % [choice_amount, LABELS[key]]
	else:
		return false
	pending_choice = ""
	progress_committed.emit()
	return true


#endregion

#region Upgrade events


func upgrade_candidates() -> Array[Resource]:
	return _deck.upgrade_candidates(ship())


func choose_upgrade(key: String) -> bool:
	return _commit_deck_choice(_deck.choose_upgrade(key, ship()))


func battle_upgrade_count(result: BattleResult) -> int:
	if result.winner != "player" or result.escaped_by_ftl:
		return 0
	if active_battle < 0 or active_battle >= encounters.size():
		return 0
	var encounter: Dictionary = encounters[active_battle]
	if encounter.get("chasedown", false):
		return maxi(0, rules.chasedown_upgrades)
	var rank: int = enemy_profile(encounter).enemy_rank
	return maxi(
		0, [rules.standard_upgrades, rules.elite_upgrades, rules.boss_upgrades][clampi(rank, 0, 2)]
	)


# One event upgrades each identity at most once; a later event may upgrade it again.
func start_upgrade_event(count: int) -> void:
	last_outcome += _deck.start_upgrade_event(count, ship())


func finish_upgrades() -> void:
	if _deck.finish_upgrades(ship()):
		progress_committed.emit()


#endregion

#region Battle handoff


# Produce one encounter's data, consuming temporary bonuses once at entry.
func prepare_battle(index: int = -1, enemy_data: Resource = null) -> BattleSetup:
	last_poi_success = -1
	active_battle = index
	field_repairs_open = false
	var setup = BattleSetup.new()
	setup.encounter_index = index
	setup.system_number = system_number
	setup.player_ship = player_ship
	setup.player_profile = ship()
	setup.enemy_profile = enemy_data
	if index >= 0 and index < encounters.size():
		var encounter: Dictionary = encounters[index]
		if encounter.kind == "battle":
			setup.enemy_ship = int(encounter.get("enemy", 0))
			if enemy_data == null:
				setup.enemy_profile = enemy_profile(encounter)
		setup.modifier = encounter.get("modifier", 0)
		setup.chasedown_charge_cap = encounter.get("chasedown", false) and encounter.get("response", -1) == 1
	setup.player_state = ShipState.new()
	setup.player_state.configure_profile(ship())
	setup.player_state.hull = hull
	for key in PRODUCTION:
		setup.player_state.set(key, maxi(0, production(key)))
	for key in RESOURCES + ["shields"]:
		setup.player_state.set(key, starting_value(ship(), key))
	if setup.enemy_profile != null:
		setup.enemy_state = ShipState.new()
		setup.enemy_state.configure_profile(setup.enemy_profile)
	setup.salvage = salvage
	setup.battles_won = battles_won
	setup.emp_charge = modifier_value("emp_pulse_charge")
	setup.emp_offline = maxi(0, modifier_value("emp_pulse_offline"))
	setup.player_cards = player_pool()
	setup.identity_weights = acquired_draw_weights()
	setup.enemy_cards = (
		setup.enemy_profile.starting_cards.duplicate()
		if setup.enemy_profile != null and not setup.enemy_profile.starting_cards.is_empty()
		else shared_pool()
	)
	pending_bonuses.clear()
	pending_penalties.clear()
	return setup


func victory_salvage(result: BattleResult) -> int:
	if result.escaped_by_ftl:
		return 0
	var destruction: int = rules.destruction_salvage
	if (
		active_battle >= 0
		and active_battle < encounters.size()
		and encounters[active_battle].kind == "battle"
	):
		destruction = enemy_profile(encounters[active_battle]).destruction_salvage_reward
	var reward: int = destruction
	return reward * rules.elite_salvage_multiplier if _elite_defeated(result) else reward


func _elite_defeated(result: BattleResult) -> bool:
	return (
		result.winner == "player"
		and not result.escaped_by_ftl
		and active_battle >= 0
		and active_battle < encounters.size()
		and encounters[active_battle].kind == "battle"
		and enemy_profile(encounters[active_battle]).enemy_rank == 1
	)


func elite_resource_reward(result: BattleResult) -> int:
	return rules.elite_resource_bonus if _elite_defeated(result) else 0


# Persist a result and complete the encounter once; escape resolves Boss navigation too.
# Board._record_result calculates Salvage first; escape and destruction keep distinct reward rules.
func record_battle(result: BattleResult) -> void:
	if _recorded_results.has(result.result_id):
		return
	if result.system_number != system_number or result.encounter_index != active_battle:
		return
	# Reject a stale/reopened result before copying its currency or queuing another reward.
	if (
		active_battle >= 0
		and active_battle < encounters.size()
		and encounters[active_battle].get("charge_awarded", false)
	):
		return
	_recorded_results[result.result_id] = true
	sync_battle(result, false)
	if result.winner != "player":
		run_ended = true
		progress_committed.emit()
		return
	if active_battle >= 0 and active_battle < encounters.size():
		if result.winner == "player":
			# Escape and destruction both complete navigation; Salvage remains separate.
			if not _complete_encounter(active_battle):
				return
			encounters[active_battle].resolution = "escaped" if result.escaped_by_ftl else "defeated"
		else:
			return
	if result.winner == "player":
		var elite_bonus: int = elite_resource_reward(result)
		if elite_bonus > 0:
			add_modifiers({"materials": elite_bonus, "energy": elite_bonus, "crew": elite_bonus})
		if result.earned_tactical:
			add_modifiers(
				{
					"materials": result.tactical_resources,
					"energy": result.tactical_resources,
					"crew": result.tactical_resources
				}
			)
		if result.earned_strategic:
			add_modifiers({"shields": result.strategic_shields})
		var count: int = battle_upgrade_count(result)
		if count > 0:
			last_outcome = "Combat victory — upgrade %d different cards." % count
			start_upgrade_event(count)

	progress_committed.emit()


func sync_battle(result: BattleResult, notify: bool = true) -> void:
	hull = clampi(result.player_hull, 0, ship().hull_capacity)
	salvage = result.salvage
	battles_won = result.battles_won
	if notify:
		progress_committed.emit()

#endregion
