extends Resource
class_name ExpeditionState

const Ships = preload("res://scripts/ship_library.gd")
const Cards = preload("res://scripts/card_library.gd")
const PRODUCTION = ["synthesizer", "reactor", "quarters"]
const RESOURCES = ["materials", "energy", "crew"]
const LABELS = {"synthesizer":"Fabricator", "reactor":"Reactor", "quarters":"Hangar",
	"materials":"Materials", "energy":"Energy", "crew":"Crew", "shields":"Shields",
	"emergency_jump_charge":"Emergency Jump charge", "emergency_jump_offline":"Emergency Jump offline turns"}
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
var production_upgrades: Dictionary = {}
var pending_bonuses: Dictionary = {}
var pending_penalties: Dictionary = {}
var acquired_cards: Array[Resource] = []
var upgraded_cards: Dictionary = {}
var pending_choice: String = ""
var choice_amount: int = 0
var card_offers: Array[Resource] = []
var last_outcome: String = ""
var active_battle: int = -1
var rng := RandomNumberGenerator.new()
var seed_used: int = 0

func start(ship_index: int, configuration: Resource, seed_override: int = 0) -> void:
	rules = configuration
	player_ship = clampi(ship_index, 0, Ships.PLAYERS.size() - 1)
	hull = ship().hull_capacity
	salvage = 0
	battles_won = 0
	system_number = 0
	production_upgrades.clear()
	pending_bonuses.clear()
	pending_penalties.clear()
	acquired_cards.clear()
	upgraded_cards.clear()
	pending_choice = ""
	card_offers.clear()
	active_battle = -1
	var chosen_seed: int = seed_override if seed_override != 0 else rules.debug_seed
	if chosen_seed == 0:
		rng.randomize()
	else:
		rng.seed = chosen_seed
	seed_used = rng.seed
	generate_system()

func ship() -> Resource:
	return Ships.PLAYERS[player_ship]

func production(key: String) -> int:
	return int(ship().get(key)) + int(production_upgrades.get(key, 0))

func can_jump() -> bool:
	return hull > 0 and active_battle < 0 and pending_choice.is_empty() and ftl_charge >= required_ftl_charge

func _weighted_index(items: Array) -> int:
	var total: float = 0.0
	for item in items: total += maxf(0.01, item.encounter_weight)
	var roll: float = rng.randf() * total
	for index in range(items.size()):
		roll -= maxf(0.01, items[index].encounter_weight)
		if roll <= 0: return index
	return items.size() - 1

func generate_system() -> bool:
	if not pending_choice.is_empty() or active_battle >= 0 or hull <= 0:
		return false
	if system_number > 0 and not can_jump(): return false
	var ordinary: Array = []
	var hazardous: Array = []
	for poi in rules.pois:
		if poi.hazardous: hazardous.append(poi)
		else: ordinary.append(poi)
	var enemies: Array = rules.enemy_ships.duplicate()
	if enemies.is_empty(): enemies.assign(Ships.ENEMIES)
	var count: int = maxi(2, rules.encounters_per_system)
	var compositions: Array[Dictionary] = []
	var total_weight: float = 0.0
	for battles in range(1, count + 1):
		for hazards in range(count - battles + 1):
			var normal: int = count - battles - hazards
			if battles < rules.minimum_battles or battles > rules.maximum_battles: continue
			if normal < rules.minimum_ordinary or normal > rules.maximum_ordinary: continue
			if hazards < rules.minimum_hazardous or hazards > rules.maximum_hazardous: continue
			if (normal > 0 and ordinary.is_empty()) or (hazards > 0 and hazardous.is_empty()): continue
			var weight: float = pow(maxf(.01, rules.battle_weight), battles) * pow(maxf(.01, rules.ordinary_weight), normal) * pow(maxf(.01, rules.hazardous_weight), hazards)
			total_weight += weight
			compositions.append({"battle":battles, "ordinary":normal, "hazardous":hazards, "weight":weight})
	var composition: Dictionary
	if compositions.is_empty():
		push_warning("Encounter bounds cannot fill a system. Falling back to one enemy and available PoIs (or all enemies if no PoIs exist).")
		composition = {"battle":1, "ordinary":count - 1 if not ordinary.is_empty() else 0, "hazardous":count - 1 if ordinary.is_empty() and not hazardous.is_empty() else 0}
		if ordinary.is_empty() and hazardous.is_empty(): composition.battle = count
	else:
		var roll: float = rng.randf() * total_weight
		composition = compositions.back()
		for candidate in compositions:
			roll -= candidate.weight
			if roll <= 0:
				composition = candidate
				break
	system_number += 1
	var names = ["Arco", "Kepler", "Vela", "Orion", "Lyra", "Perseus"]
	system_name = "%s %d" % [names[rng.randi_range(0, names.size() - 1)], system_number]
	encounters.clear()
	ftl_charge = 0
	required_ftl_charge = int(composition.ordinary) + int(composition.hazardous) + 1
	for category in ["ordinary", "hazardous", "battle"]:
		var library: Array = enemies if category == "battle" else (ordinary if category == "ordinary" else hazardous)
		var available: Array = library.duplicate()
		for slot in range(int(composition[category])):
			if available.is_empty(): available = library.duplicate()
			var entry: Resource = available.pop_at(_weighted_index(available))
			if category == "battle":
				encounters.append({"kind":"battle", "enemy":maxi(0, Ships.ENEMIES.find(entry)), "enemy_data":entry, "modifier":rng.randi_range(0, 5), "title":entry.ship_name, "completed":false, "charge_awarded":false})
			else:
				encounters.append({"kind":"poi", "poi":entry, "title":entry.title, "completed":false, "charge_awarded":false})
	for index in range(encounters.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Dictionary = encounters[index]
		encounters[index] = encounters[other]
		encounters[other] = swap
	return true

func enemy_profile(encounter: Dictionary) -> Resource:
	return encounter.get("enemy_data", Ships.ENEMIES[int(encounter.get("enemy", 0))])

func encounter_charge(index: int) -> int:
	return 1 if encounters[index].kind == "poi" else maxi(1, enemy_profile(encounters[index]).interstellar_ftl_reward)

func _complete_encounter(index: int, extra_charge: int = 0) -> bool:
	if index < 0 or index >= encounters.size() or encounters[index].get("charge_awarded", false): return false
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
	if not can_visit(index) or encounters[index].kind != "poi": return false
	for approach in encounters[index].poi.approaches:
		if not locked_reason(approach).is_empty(): continue
		var worst: int = approach.success.hull
		if approach.success_chance < 1: worst = mini(worst, approach.failure.hull)
		if hull + worst > 0: return false
	return true

func survey(index: int) -> bool:
	if not can_survey(index): return false
	_complete_encounter(index)
	add_modifiers(rules.survey_penalty)
	last_outcome = "Navigation survey completed. +1 FTL Drive charge. No Salvage or other rewards. Next battle: " + describe_modifiers(rules.survey_penalty)
	return true

func can_visit(index: int) -> bool:
	return hull > 0 and active_battle < 0 and pending_choice.is_empty() and index >= 0 and index < encounters.size() and not encounters[index].completed

func locked_reason(approach: Resource) -> String:
	if not approach.requirement.is_empty() and production(approach.requirement) < approach.minimum_production:
		return "Requires %s ≥%d (you have %d)" % [LABELS[approach.requirement], approach.minimum_production, production(approach.requirement)]
	if salvage < approach.salvage_cost:
		return "Requires %d Salvage (you have %d)" % [approach.salvage_cost, salvage]
	if approach.success.hull > 0 and hull >= ship().hull_capacity:
		return "Hull already full"
	return ""

func resolve_approach(index: int, approach_index: int, forced_roll: float = -1.0) -> bool:
	if not can_visit(index) or encounters[index].kind != "poi":
		return false
	var poi: Resource = encounters[index].poi
	if approach_index < 0 or approach_index >= poi.approaches.size():
		return false
	var approach: Resource = poi.approaches[approach_index]
	if not locked_reason(approach).is_empty():
		return false
	salvage -= approach.salvage_cost
	var roll: float = rng.randf() if forced_roll < 0 else forced_roll
	var success: bool = roll < approach.success_chance
	var outcome: Resource = approach.success if success else approach.failure
	_complete_encounter(index, outcome.extra_ftl_charge)
	# The roll and seed are printed for reproducing balance reports.
	if rules.log_rolls: print("Expedition seed=%d system=%d encounter=%d approach=%d roll=%.4f success=%s" % [seed_used, system_number, index, approach_index, roll, success])
	last_outcome = outcome.blurb + "\n" + describe_outcome(outcome) + "\n+%d FTL Drive charge." % (1 + outcome.extra_ftl_charge)
	if approach.salvage_cost > 0:
		last_outcome += "\nSpent %d Salvage." % approach.salvage_cost
	salvage += outcome.salvage
	hull = clampi(hull + outcome.hull, 0, ship().hull_capacity)
	add_modifiers(outcome.next_battle)
	if outcome.card_reward:
		pending_choice = "card"
		card_offers = random_card_offers(outcome.minimum_card_tier)
	elif outcome.upgrade_card:
		if upgrade_candidates().is_empty():
			salvage += rules.unavailable_upgrade_salvage
			last_outcome += "\nAll cards fully upgraded: +%d Salvage instead." % rules.unavailable_upgrade_salvage
		else:
			pending_choice = "upgrade"
	elif outcome.resource_choice > 0:
		pending_choice = "resource"
		choice_amount = outcome.resource_choice
	elif outcome.production_choice > 0:
		pending_choice = "production"
		choice_amount = outcome.production_choice
	return true

func add_modifiers(values: Dictionary) -> void:
	for key in values:
		var amount: int = int(values[key])
		if amount > 0:
			pending_bonuses[key] = maxi(int(pending_bonuses.get(key, 0)), amount)
		elif amount < 0:
			pending_penalties[key] = mini(int(pending_penalties.get(key, 0)), amount)

func modifier_value(key: String) -> int:
	return int(pending_bonuses.get(key, 0)) + int(pending_penalties.get(key, 0))

func shared_pool() -> Array[Resource]:
	var pool: Array[Resource] = []
	pool.assign(Cards.CARDS)
	pool.append_array(acquired_cards)
	return pool

func player_pool() -> Array[Resource]:
	var result: Array[Resource] = []
	for card in shared_pool():
		result.append(upgraded_cards.get(card.identity_key(), card))
	return result

func random_card_offers(minimum_tier: int = 1) -> Array[Resource]:
	var candidates: Array[Resource] = []
	for card in Cards.CARDS:
		if card.tier >= minimum_tier:
			candidates.append(card)
	var offers: Array[Resource] = []
	for slot in range(mini(3, candidates.size())):
		var index: int = rng.randi_range(0, candidates.size() - 1)
		offers.append(candidates.pop_at(index))
	return offers

func choose_card(index: int) -> bool:
	if pending_choice != "card" or index < 0 or index >= card_offers.size():
		return false
	var chosen: Resource = card_offers[index]
	acquired_cards.append(chosen)
	last_outcome += "\nAcquired %s: added to the shared draw pool." % chosen.card_name
	pending_choice = ""
	card_offers.clear()
	return true

func upgrade_candidates() -> Array[Resource]:
	var result: Array[Resource] = []
	var seen: Dictionary = {}
	for card in player_pool():
		var key: String = card.identity_key()
		if not seen.has(key) and card.upgrade_level < card.max_upgrades and card.upgrade_cost_reduction > 0 and card.cost > 1:
			result.append(card)
			seen[key] = true
	return result

func choose_upgrade(key: String) -> bool:
	if pending_choice != "upgrade":
		return false
	for card in upgrade_candidates():
		if card.identity_key() != key:
			continue
		var copy: Resource = card.duplicate(true)
		copy.set_meta("card_identity", key)
		# Resource.duplicate copies exported fields, not this runtime counter.
		copy.upgrade_level = card.upgrade_level + 1
		copy.cost = maxi(1, card.cost - card.upgrade_cost_reduction)
		upgraded_cards[key] = copy
		last_outcome += "\nUpgraded %s: cost %d → %d (player only)." % [card.card_name, card.cost, copy.cost]
		pending_choice = ""
		return true
	return false

func choose_attribute(key: String) -> bool:
	if pending_choice == "resource" and key in RESOURCES:
		add_modifiers({key:choice_amount})
		last_outcome += "\nNext battle: +%d %s." % [choice_amount, LABELS[key]]
	elif pending_choice == "production" and key in PRODUCTION:
		production_upgrades[key] = int(production_upgrades.get(key, 0)) + choice_amount
		last_outcome += "\nExpedition: +%d %s." % [choice_amount, LABELS[key]]
	else:
		return false
	pending_choice = ""
	return true

func begin_battle(board: Node, index: int = -1) -> void:
	active_battle = index
	board.player_hull = hull
	board.salvage = salvage
	board.battles_won = battles_won
	for key in PRODUCTION:
		board.set("player_" + key, maxi(0, production(key) + modifier_value(key)))
	for key in RESOURCES + ["shields"]:
		board.set("player_" + key, maxi(0, int(ship().get(key)) + modifier_value(key)))
	board.ftl.charge = clampi(modifier_value("emergency_jump_charge"), 0, board.ftl.charge_target)
	board.ftl.disabled_turns = maxi(0, modifier_value("emergency_jump_offline"))
	board.hand.card_pool = player_pool()
	board.enemy_hand.card_pool = shared_pool()
	pending_bonuses.clear()
	pending_penalties.clear()

func victory_salvage(board: Node) -> int:
	if board.escaped_by_ftl:
		return 0
	var destruction: int = rules.destruction_salvage
	if active_battle >= 0 and active_battle < encounters.size() and encounters[active_battle].kind == "battle":
		destruction = enemy_profile(encounters[active_battle]).destruction_salvage_reward
	return destruction if board.enemy_hull <= 0 else rules.resource_victory_salvage

func record_battle(board: Node) -> void:
	sync_battle(board)
	if active_battle >= 0 and active_battle < encounters.size():
		if board.winner == "player":
			# Escape and destruction both complete navigation; Salvage remains separate.
			if not _complete_encounter(active_battle): return
		else:
			return
	if board.winner == "player":
		if board.earned_tactical:
			add_modifiers({"materials":board.TACTICAL_RESOURCES, "energy":board.TACTICAL_RESOURCES, "crew":board.TACTICAL_RESOURCES})
		if board.earned_strategic:
			add_modifiers({"shields":board.STRATEGIC_SHIELDS})

func sync_battle(board: Node) -> void:
	hull = clampi(board.player_hull, 0, ship().hull_capacity)
	salvage = board.salvage
	battles_won = board.battles_won

func describe_modifiers(values: Dictionary) -> String:
	var parts: Array[String] = []
	for key in values:
		parts.append("%+d %s" % [values[key], LABELS.get(key, key)])
	return " · ".join(parts)

func describe_outcome(outcome: Resource) -> String:
	var parts: Array[String] = []
	if outcome.extra_ftl_charge > 0: parts.append("+%d extra FTL Drive charge" % outcome.extra_ftl_charge)
	if outcome.salvage != 0: parts.append("%+d Salvage" % outcome.salvage)
	if outcome.hull != 0: parts.append("%+d permanent Hull" % outcome.hull)
	for key in outcome.next_battle:
		parts.append("%+d %s next battle" % [outcome.next_battle[key], LABELS.get(key, key)])
	if outcome.card_reward:
		parts.append("Choose 1 of 3 %scards" % ("uncommon-or-better " if outcome.minimum_card_tier > 1 else ""))
	if outcome.upgrade_card: parts.append("Upgrade one player card")
	if outcome.resource_choice > 0: parts.append("+%d starting resource of choice next battle" % outcome.resource_choice)
	if outcome.production_choice > 0: parts.append("+%d production of choice for expedition" % outcome.production_choice)
	return " · ".join(parts)

func pending_description() -> String:
	var parts: Array[String] = []
	var keys: Array = pending_bonuses.keys()
	for key in pending_penalties:
		if not keys.has(key): keys.append(key)
	for key in keys:
		var positive: int = int(pending_bonuses.get(key, 0))
		var negative: int = int(pending_penalties.get(key, 0))
		if positive > 0: parts.append("+%d %s" % [positive, LABELS.get(key, key)])
		if negative < 0: parts.append("%d %s" % [negative, LABELS.get(key, key)])
	return "None" if parts.is_empty() else " · ".join(parts)
