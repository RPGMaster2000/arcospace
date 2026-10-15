extends RefCounted
# Shared by victory repairs and station repairs; excess battle plating is never repaired.
const HULL_PER_SALVAGE: int = 1

static func max_spend(hull: int, capacity: int, salvage: int) -> int:
	return mini(maxi(0, salvage), maxi(0, capacity - hull) / HULL_PER_SALVAGE)
