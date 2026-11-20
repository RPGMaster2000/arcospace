extends RefCounted
## Facility quotes and effects. ExpeditionState owns access, currency and time.

const Lattice = preload("res://scripts/expedition/warzone_lattice.gd")
const REPAIR_STRENGTH := 5
const EFFECT_SECONDS := 20
const TYPES := ["repair", "coordinate", "fortify", "jam", "fortify", "sabotage",
	"coordinate", "coordinate", "deploy", "sabotage", "fortify", "sabotage"]
const COOLDOWNS := {"repair": 18, "coordinate": 28, "fortify": 16, "jam": 25, "sabotage": 42, "deploy": 35}


static func operation_kind(index: int) -> String:
	return TYPES[index]


static func cooldown(kind: String) -> int:
	return COOLDOWNS[kind]


static func options(sector: RefCounted, index: int, salvage: int) -> Array[Dictionary]:
	if sector.complete or index < 0 or index >= sector.objectives.size(): return []
	var kind := operation_kind(index)
	var hostile_only := kind == "sabotage"
	var can_infiltrate := kind == "jam"
	var owner: String = sector.objectives[index].owner
	var remaining: int = sector.facility_cooldowns.get(index, 0)
	var reason := ""
	if owner != ("hostile" if hostile_only else "allied") and not (can_infiltrate and owner == "hostile"):
		reason = "Requires hostile infrastructure" if hostile_only else "Requires allied control"
	elif owner == "allied" and not sector.is_supplied(index):
		reason = "Requires allied supply"
	elif remaining > 0:
		reason = "Recharging · %ds" % remaining
	var title := ""
	var details := ""
	var cost := 0
	var seconds := 4
	match kind:
		"repair":
			title = "Repair Allied Fleet"
			details = "Restore up to %d strength to the weakest damaged allied formation. If none survive, recover one emergency formation." % REPAIR_STRENGTH
			var emergency: bool = not sector.recovered and sector.fleet_count("allied") == 0
			cost = 0 if emergency else sector.tuning.repair_cost
			if reason.is_empty() and not emergency and _repair_target(sector).is_empty():
				reason = "No damaged allied formation"
		"coordinate":
			title = "Coordinate Offensive"
			details = "Direct supplied fleets toward an exposed objective and strengthen allied volleys near it for %ds." % EFFECT_SECONDS
			if reason.is_empty() and (sector.clock_ms < sector.offensive_until or _rally_target(sector, index) < 0):
				reason = "No available offensive"
		"fortify":
			title = "Fortify Position"
			details = "Reduce supplied hostile volley damage against allied fleets defending this position for %ds." % cooldown(kind)
			cost = 2
		"jam":
			title = "Jam Communications"
			details = ("Tap this array" if owner == "hostile" else "Transmit from this supplied array") \
				+ " to delay hostile reserves and counterattack orders for %ds." % EFFECT_SECONDS
		"sabotage":
			title = "Disrupt Logistics"
			details = "Cut this installation's supply links for %ds and force its local garrison to withdraw." % sector.tuning.sabotage_seconds
		"deploy":
			title = "Deploy Reinforcements"
			details = "Dispatch a replacement formation from outside the sector. Requires a vacant allied fleet slot."
			cost = sector.tuning.repair_cost
			seconds = 6
			if reason.is_empty() and not sector.can_deploy_allied():
				reason = "No available fleet slot"
	if reason.is_empty() and salvage < cost:
		reason = "Requires %d Salvage" % cost
	return [{"id": kind, "title": title, "details": details, "cost": cost, "seconds": seconds,
		"enabled": reason.is_empty(), "reason": reason, "remaining": remaining, "cooldown": cooldown(kind)}]


static func apply(sector: RefCounted, index: int, action: Dictionary) -> void:
	var kind: String = action.id
	var key := "%s:%d" % [kind, index]
	sector.planned[key] = true
	sector.facility_cooldowns[index] = cooldown(kind)
	sector.player_intervened = true
	match kind:
		"sabotage":
			var previously_supplied: Array = sector.supplied.hostile.duplicate()
			sector.disrupted[index] = int(sector.tuning.sabotage_seconds)
			sector._refresh_supply()
			var cut: int = previously_supplied.size() - sector.supplied.hostile.size()
			if cut > 0:
				sector._award("cut:%d" % index, mini(8, cut + 3), "Severed hostile supply")
			sector._scatter_garrison(index)
		"jam":
			sector.jam_until = sector.clock_ms + EFFECT_SECONDS * sector.STEP_MS
		"repair":
			var target := _repair_target(sector)
			if target.is_empty():
				sector.recovered = true
				target = sector.fleets[0]
				target.at = index
				target.destination = index
				target.counter_target = -1
				target.withdrawing = false
				target.position = sector.objectives[index].position
			target.strength = mini(target.strength_limit, target.strength + REPAIR_STRENGTH)
		"coordinate":
			sector.offensive_target = _rally_target(sector, index)
			sector.offensive_until = sector.clock_ms + EFFECT_SECONDS * sector.STEP_MS
			for fleet in sector.fleets:
				if fleet.side == "allied" and sector.active(fleet) and fleet.engaged < 0 and not fleet.get("arriving", false) \
					and sector.route_valid("allied", fleet.at, sector.offensive_target):
					fleet.destination = sector.offensive_target
		"deploy":
			sector.deploy_allied()
	sector._notice(action.title + " · " + sector.objective_name(index))


static func _repair_target(sector: RefCounted) -> Dictionary:
	var weakest := {}
	for fleet in sector.fleets:
		if fleet.side == "allied" and sector.active(fleet) and fleet.strength < fleet.strength_limit:
			if weakest.is_empty() or fleet.strength < weakest.strength:
				weakest = fleet
	return weakest


static func _rally_target(sector: RefCounted, index: int) -> int:
	if sector.fleet_count("allied") == 0: return -1
	if sector.final_command >= 0 and sector.route_valid("allied", index, sector.final_command):
		return sector.final_command
	for site in sector.supplied.allied:
		for neighbor in Lattice.neighbors(site, sector.links, sector.disrupted):
			if sector.objectives[neighbor].owner != "allied":
				return neighbor
	return -1
