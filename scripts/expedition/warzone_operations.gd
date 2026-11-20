extends RefCounted
## PoI quotes and operation effects; ExpeditionState owns proximity, currency and time.
const Lattice = preload("res://scripts/expedition/warzone_lattice.gd")
const OPERATION_SECONDS := 4
const REPAIR_STRENGTH := 5


static func _operation_id(index: int, kind: String) -> String:
	return "%s:%d" % [kind, index]


static func options(sector: RefCounted, index: int, salvage: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if sector.complete or index < 0 or index >= sector.objectives.size(): return result
	var site: Dictionary = sector.objectives[index]
	if site.owner == "hostile" and index in [3, 5, 7, 8, 10, 11]:
		result.append(_action(sector, index, "sabotage", "Sabotage infrastructure",
			"Break connected corridors at %s for %ds and scatter its garrison." % [sector.objective_name(index), sector.tuning.sabotage_seconds], 0))
	if site.owner == "allied" and index in [0, 1, 2]:
		result.append(_action(sector, index, "repair", "Repair allied formations",
			"Restore allied fleet strength. Relaunch one reserve if both fleets were lost.", sector.tuning.repair_cost, salvage))
	if not sector.convoy.is_empty() and sector.convoy.side == "hostile" and index in [sector.convoy.origin, sector.convoy.target]:
		result.append(_action(sector, index, "intercept", "Intercept the supply convoy",
			"Stop deliveries from %s to %s." % [sector.objective_name(sector.convoy.origin), sector.objective_name(sector.convoy.target)], 0))
	if site.owner == "hostile" and index in sector.COMMANDS:
		result.append(_action(sector, index, "breach", "Disrupt command defenses",
			"Push the local garrison off the command point so it can be captured.", 0))
	if sector.wreckage.has(index):
		result.append(_action(sector, index, "salvage", "Salvage fleet wreckage",
			"Recover 4 Salvage before the wreck disperses.", 0))
	if site.owner == "hostile" and index == 5:
		result.append(_action(sector, index, "raid", "Raid depot stores",
			"Recover 5 Salvage. Nearby hostiles reassess the depot once their current fight ends.", 0))
	return result


static func _action(sector: RefCounted, index: int, kind: String, title: String, details: String, cost: int, salvage: int = 0) -> Dictionary:
	var enabled: bool = salvage >= cost and not sector.planned.has(_operation_id(index, kind))
	if kind == "repair":
		var damaged: bool = sector.fleets.any(func(fleet):
			return fleet.side == "allied" and sector.active(fleet) and fleet.strength < fleet.strength_limit)
		var reserve: bool = not sector.recovered and sector.fleet_count("allied") == 0
		enabled = enabled and (damaged or reserve)
	return {"id": kind, "title": title, "details": details, "cost": cost, "seconds": OPERATION_SECONDS,
		"effort": 0 if kind in ["raid", "salvage"] else sector.tuning.operation_effort, "enabled": enabled,
		"repair_strength": REPAIR_STRENGTH if kind == "repair" else 0}


static func apply(sector: RefCounted, index: int, action: Dictionary) -> int:
	var kind: String = action.id
	var key := _operation_id(index, kind)
	sector.planned[key] = true
	if kind == "sabotage":
		var previously_supplied: int = sector.supplied.hostile.size()
		sector.disrupted[index] = int(sector.tuning.sabotage_seconds)
		sector._refresh_supply()
		if sector.supplied.hostile.size() < previously_supplied:
			sector._award("cut:%d" % index, 5, "Severed hostile supply")
	if kind == "sabotage" or kind == "breach":
		sector._scatter_garrison(index)
	if kind == "repair":
		for fleet in sector.fleets:
			if sector.active(fleet) and fleet.side == "allied":
				fleet.strength = mini(fleet.strength_limit, fleet.strength + REPAIR_STRENGTH)
		if sector.fleet_count("allied") == 0 and not sector.recovered:
			sector.recovered = true
			var reserve: Dictionary = sector.fleets[0]
			reserve.strength = mini(reserve.strength_limit, REPAIR_STRENGTH)
			reserve.at = index
			reserve.destination = index
			reserve.counter_target = -1
			reserve.withdrawing = false
			reserve.position = sector.objectives[index].position
	if kind == "intercept":
		sector.planned[_operation_id(sector.convoy.origin, kind)] = true
		sector.planned[_operation_id(sector.convoy.target, kind)] = true
		sector.convoy.clear()
	if kind == "salvage":
		sector.wreckage.erase(index)
		sector._notice("Recovered 4 Salvage from the wreckage.")
		return 4
	if kind == "raid":
		for fleet in sector.fleets:
			if sector.active(fleet) and fleet.side == "hostile" and fleet.engaged < 0 and fleet.at in Lattice.neighbors(index, sector.links):
				fleet.counter_target = index
		sector._notice("Recovered depot stores. Hostile patrols are responding.")
	else:
		sector._award(key, action.effort, action.title)
	return 5 if kind == "raid" else 0
