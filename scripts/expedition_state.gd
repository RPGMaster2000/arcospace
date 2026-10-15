extends Resource
class_name ExpeditionState

const Ships = preload("res://scripts/ship_library.gd")
const Cards = preload("res://scripts/card_library.gd")
const PRODUCTION = ["synthesizer", "reactor", "quarters"]
const RESOURCES = ["materials", "energy", "crew"]
const LABELS = {"synthesizer":"Fabricator", "reactor":"Reactor", "quarters":"Hangar",
	"materials":"Materials", "energy":"Energy", "crew":"Crew", "shields":"Shields",
	"ftl_charge":"FTL charge", "ftl_offline":"FTL offline turns"}
var rules: Resource
var player_ship: int = 0
var hull: int = 0
var salvage: int = 0
var battles_won: int = 0
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

func generate_system() -> bool:
	if not pending_choice.is_empty() or active_battle >= 0 or hull <= 0:
		return false
	system_number += 1
	var names = ["Arco", "Kepler", "Vela", "Orion", "Lyra", "Perseus"]
	system_name = "%s %d" % [names[rng.randi_range(0, names.size() - 1)], system_number]
	encounters.clear()
	var count: int = maxi(2, rules.encounters_per_system)
	var low: int = clampi(rules.minimum_battles, 1, count - 1)
	var high: int = clampi(rules.maximum_battles, low, count - 1)
	var battles: int = rng.randi_range(low, high)
	var available_pois: Array = rules.pois.duplicate()
	for index in range(count):
		if index < battles or rules.pois.is_empty():
			var enemy: int = rng.randi_range(0, Ships.ENEMIES.size() - 1)
			encounters.append({"kind":"battle", "enemy":enemy, "modifier":rng.randi_range(0, 5),
				"title":Ships.ENEMIES[enemy].ship_name, "completed":false})
		else:
			if available_pois.is_empty():
				available_pois = rules.pois.duplicate()
			var poi: Resource = available_pois.pop_at(rng.randi_range(0, available_pois.size() - 1))
			encounters.append({"kind":"poi", "poi":poi, "title":poi.title, "completed":false})
	# Use this expedition's RNG, not Array.shuffle's global RNG.
	for index in range(encounters.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: Dictionary = encounters[index]
		encounters[index] = encounters[other]
		encounters[other] = swap
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
	encounters[index].completed = true
	var roll: float = rng.randf() if forced_roll < 0 else forced_roll
	var success: bool = roll < approach.success_chance
	var outcome: Resource = approach.success if success else approach.failure
	# The roll and seed are printed for reproducing balance reports.
	print("Expedition seed=%d system=%d encounter=%d approach=%d roll=%.4f success=%s" % [seed_used, system_number, index, approach_index, roll, success])
	last_outcome = outcome.blurb + "\n" + describe_outcome(outcome)
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
	board.ftl.charge = clampi(modifier_value("ftl_charge"), 0, board.ftl.charge_target)
	board.ftl.disabled_turns = maxi(0, modifier_value("ftl_offline"))
	board.hand.card_pool = player_pool()
	board.enemy_hand.card_pool = shared_pool()
	pending_bonuses.clear()
	pending_penalties.clear()

func victory_salvage(board: Node) -> int:
	if board.escaped_by_ftl:
		return rules.escape_salvage
	return rules.destruction_salvage if board.enemy_hull <= 0 else rules.resource_victory_salvage

func record_battle(board: Node) -> void:
	sync_battle(board)
	if active_battle >= 0 and active_battle < encounters.size():
		encounters[active_battle].completed = true
	if board.winner == "player":
		if board.earned_tactical:
			add_modifiers({"materials":board.TACTICAL_RESOURCES, "energy":board.TACTICAL_RESOURCES, "crew":board.TACTICAL_RESOURCES})
		if board.earned_strategic:
			add_modifiers({"shields":board.STRATEGIC_SHIELDS})

func sync_battle(board: Node) -> void:
	hull = clampi(board.player_hull, 0, ship().hull_capacity)
	salvage = board.salvage
	battles_won = board.battles_won

func describe_outcome(outcome: Resource) -> String:
	var parts: Array[String] = []
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
