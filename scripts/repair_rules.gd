extends RefCounted
# Shared quantity/cost bounds for result repairs, field repairs and the station Hull/plating service.
const HULL_PER_SALVAGE: int = 1

static func max_spend(hull: int, capacity: int, salvage: int) -> int:
	# Result UI selects Salvage units; convert the shared Hull quantity back to that unit.
	return max_quantity(hull, capacity, maxi(0, salvage) * HULL_PER_SALVAGE, 1) / HULL_PER_SALVAGE

const FIELD_SALVAGE_PER_HULL: int = 2
const PLATING_SALVAGE_PER_POINT: int = 2
const STATION_PLATING_LIMIT: int = 10

# Shared quantity/cost bounds for field repairs and the conditional station service.
static func max_quantity(hull: int, ceiling: int, salvage: int, unit_cost: int) -> int:
	return mini(maxi(0, ceiling - hull), maxi(0, salvage) / maxi(1, unit_cost))

static func quantity_cost(amount: int, unit_cost: int) -> int:
	return maxi(0, amount) * maxi(1, unit_cost)
