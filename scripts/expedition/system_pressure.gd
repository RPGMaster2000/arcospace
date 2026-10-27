extends RefCounted

# Pure starting-stat transform, after established system progression. Shared profiles stay immutable.
static func bonus(pressure: int) -> float:
	return 0.3 if pressure >= 10 else (0.2 if pressure >= 8 else (0.1 if pressure >= 5 else 0.0))

static func scaled_enemy(base: Resource, pressure: int) -> Resource:
	var result: Resource = base.duplicate(false)
	var factor: float = 1.0 + bonus(pressure)
	result.hull_capacity = ceili(base.hull_capacity * factor)
	result.shields = ceili(base.shields * factor)
	return result

static func description(pressure: int) -> String:
	var percent: int = roundi(bonus(pressure) * 100.0)
	return "" if percent == 0 else "SYSTEM PRESSURE: HIGH — Enemy Hull/Shields +%d%%" % percent
