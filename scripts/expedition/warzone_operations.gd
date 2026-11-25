extends RefCounted
## Facility quotes and effects. ExpeditionState owns access, currency and time.

const REPAIR_STRENGTH := 5
const EFFECT_SECONDS := 20
const COOLDOWNS := {"repair": 18, "coordinate": 28, "fortify": 16, "jam": 25, "sabotage": 42}


static func cooldown(kind: String, tuning: Resource) -> int:
	return tuning.reinforcement_cooldown if kind == "deploy" else COOLDOWNS[kind]


static func options(sector: RefCounted, index: int, salvage: int) -> Array[Dictionary]:
	if sector.complete or index < 0 or index >= sector.objectives.size(): return []
	var kind: String = sector.facility(index)
	var hostile_only := kind == "sabotage"
	var can_infiltrate := kind == "jam"
	var owner: String = sector.objectives[index].owner
	var remaining: int = sector.facility_cooldowns.get(index, 0)
	var reason := ""
	if owner != ("hostile" if hostile_only else "allied") and not (can_infiltrate and owner == "hostile"):
		reason = "Requires hostile infrastructure" if hostile_only else "Requires allied control"
	elif owner == "allied" and sector.economy != null and kind in ["repair", "deploy"] and sector.objectives[index].contested:
		reason = "Installation contested"
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
			title = "Scramble Fleet Command"
			details = "Prioritize hostile interceptions for %ds." % sector.tuning.scramble_seconds
			seconds = 2
			if reason.is_empty() and sector.clock_ms < sector.scramble_until:
				reason = "Scramble command active"
			elif reason.is_empty() and (sector.fleet_count("allied") == 0 or sector.fleet_count("hostile") == 0):
				reason = "Requires allied fleets and hostile contacts"
		"fortify":
			title = "Fortify Position"
			details = "Reduce supplied hostile volley damage against allied fleets defending this position for %ds." % cooldown(kind, sector.tuning)
			cost = 2
		"jam":
			title = "Jam Communications"
			details = ("Tap this array" if owner == "hostile" else "Transmit from this supplied array") \
				+ " to delay hostile reserves and counterattack orders for %ds." % EFFECT_SECONDS
		"sabotage":
			title = "Disrupt Logistics"
			details = "Cut this installation's supply links for %ds and force its local garrison to withdraw." % sector.tuning.sabotage_seconds
		"deploy":
			title = "Request Reinforcements"
			var remaining_requests: int = maxi(0, sector.tuning.reinforcement_budget - (sector.fleets.size() - sector.requested_first()))
			details = "Dispatch one formation from outside the sector · %d requests left." % remaining_requests
			cost = sector.tuning.reinforcement_cost
			seconds = sector.tuning.reinforcement_seconds
			if reason.is_empty(): reason = sector.reinforcement_lock()
	if reason.is_empty() and salvage < cost:
		reason = "Requires %d Salvage" % cost
	return [{"id": kind, "title": title, "details": details, "cost": cost, "seconds": seconds,
		"enabled": reason.is_empty(), "reason": reason, "remaining": remaining, "cooldown": cooldown(kind, sector.tuning)}]


static func apply(sector: RefCounted, index: int, action: Dictionary) -> void:
	var kind: String = action.id
	var key := "%s:%d" % [kind, index]
	sector.planned[key] = true
	sector.facility_cooldowns[index] = cooldown(kind, sector.tuning)
	sector.player_intervened = true
	match kind:
		"sabotage":
			sector.note_player_aggression(1)
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
				target.erase("intercept")
				target.erase("assignment")
				target.erase("commit_until")
				target.erase("recover_until")
				target.withdrawing = false
				target.position = sector.objectives[index].position
			target.strength = mini(target.strength_limit, target.strength + REPAIR_STRENGTH)
		"coordinate":
			sector.scramble(index)
		"deploy":
			sector.deploy_allied(index)
	sector._notice(action.title + " · " + sector.objective_name(index))


static func _repair_target(sector: RefCounted) -> Dictionary:
	var weakest := {}
	for fleet in sector.fleets:
		if fleet.side == "allied" and sector.active(fleet) and fleet.strength < fleet.strength_limit:
			if weakest.is_empty() or fleet.strength < weakest.strength:
				weakest = fleet
	return weakest
