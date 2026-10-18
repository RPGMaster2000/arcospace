extends RefCounted
# Shared quantity/cost bounds for result repairs, field repairs and the station Hull/plating service.
const RESULT_SALVAGE_PER_HULL: int = 2

static func max_spend(hull: int, capacity: int, salvage: int) -> int:
	# The result selector counts Hull points, just like field/station quantity controls.
	return max_quantity(hull, capacity, salvage, RESULT_SALVAGE_PER_HULL)

const FIELD_SALVAGE_PER_HULL: int = 2
const PLATING_SALVAGE_PER_POINT: int = 2
const STATION_PLATING_LIMIT: int = 10

# Shared quantity/cost bounds for field repairs and the conditional station service.
static func max_quantity(hull: int, ceiling: int, salvage: int, unit_cost: int) -> int:
	return mini(maxi(0, ceiling - hull), maxi(0, salvage) / maxi(1, unit_cost))

static func quantity_cost(amount: int, unit_cost: int) -> int:
	return maxi(0, amount) * maxi(1, unit_cost)
