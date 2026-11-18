extends RefCounted

# Shared quantity and cost bounds for field and station repairs.
const FIELD_HULL_PER_SALVAGE: int = 2
const PLATING_SALVAGE_PER_POINT: int = 2
const STATION_PLATING_LIMIT: int = 10


# Shared quantity/cost bounds for field repairs and the conditional station service.
static func max_quantity(hull: int, ceiling: int, salvage: int, unit_cost: int) -> int:
	return mini(maxi(0, ceiling - hull), maxi(0, salvage) / maxi(1, unit_cost))


static func quantity_cost(amount: int, unit_cost: int, points_per_unit: int = 1) -> int:
	return ceili(float(maxi(0, amount)) / points_per_unit) * maxi(1, unit_cost)
