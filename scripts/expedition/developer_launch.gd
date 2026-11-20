extends RefCounted
## Session-only launch settings and enemy selection. Never advances campaign RNG.

const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const MODES = ["warzone", "defense", "exploration"]
const MODE_LABELS = ["Warzone", "Starfront Defense", "Exploration"]
const MAX_STAGE = 10


static func configuration(mode: String, stage: int, rank: int) -> Dictionary:
	if mode not in MODES or stage < 1 or stage > MAX_STAGE or rank < -1 or rank > 2:
		return {}
	return {"mode": mode, "stage": stage, "rank": rank}


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
