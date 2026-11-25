extends RefCounted
## Session-only launch settings and enemy selection. Never advances campaign RNG.

const Variation = preload("res://scripts/expedition/system_variation.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const MODES = ["warzone", "defense", "exploration"]
const MODE_LABELS = ["Warzone", "Starfront Defense", "Exploration"]
const MAX_STAGE = 10


static func configuration(mode: String, stage: int, rank: int, formation: String = "", faction: String = "", geography: Dictionary = {}) -> Dictionary:
	if mode not in MODES or stage < 1 or stage > MAX_STAGE or rank < -1 or rank > 2:
		return {}
	var result := {"mode": mode, "stage": stage, "rank": rank}
	if mode == "defense":
		if preload("res://scripts/expedition/defense_warfare.gd").available_formation(formation, stage):
			result.formation = formation
		if not faction.is_empty(): result.faction = faction
		if stage >= 3:
			for key in ["environment", "size_class", "home_region"]:
				var choices: Array = {"environment":Variation.ARCHETYPES, "size_class":Variation.SIZE_CLASSES,
					"home_region":Variation.HOME_REGIONS}[key]
				if geography.get(key) in choices: result[key] = geography[key]
			if geography.get("binary") is int and geography.binary in [0, 1]: result.binary = geography.binary
	var seed_text := str(geography.get("seed", "")).strip_edges()
	if seed_text.is_valid_int() and int(seed_text) != 0:
		result.seed = seed_text
	return result


static func enemy(state: Resource, original: Resource, slot: int, faction: Resource = null) -> Resource:
	var rank: int = state.developer_enemy_rank()
	if rank < 0 or original.enemy_rank == rank:
		return original
	var pool: Array = []
	if faction != null:
		match rank:
			0: pool = Factions.roster(faction, state.system_number)
			1: pool = _matching(faction.elite_roster, rank)
			2: pool = _matching([faction.mothership], rank)
	if pool.is_empty():
		pool = _matching(state.rules.enemy_ships + Ships.ENEMIES + Factions.ships(state.rules)
			+ [state.rules.progression.mandatory_boss_profile()], rank)
	if pool.is_empty():
		return original
	var key := "%d:%d:%d:developer-enemy" % [state.seed_used, state.system_number, slot]
	return pool[posmod(hash(key), pool.size())]


static func _matching(ships: Array, rank: int) -> Array:
	var matching: Array = []
	for ship in ships:
		if ship is ShipData and ship.enemy_rank == rank and not matching.has(ship):
			matching.append(ship)
	return matching
