extends RefCounted
## Quotes local station service. The caller owns range and the correct wallet.

const Preparation = preload("res://scripts/combat/combat_preparation.gd")
const REPAIR := "hull"
const SERVICES := {
	"repair": ["Emergency Repairs", 4, 5, 18, [REPAIR]],
	"sabotage": ["Combat Resupply", 7, 5, 20, Preparation.RESOURCES],
	"fortify": ["Shield Reinforcement", 6, 6, 24, ["shields"]],
	"coordinate": ["Production Optimization", 12, 1, 30, Preparation.PRODUCTION],
	"jam": ["Signal Disruption", 8, 4, 25, ["disrupt.materials", "disrupt.energy", "disrupt.crew"]],
}


static func cooldown(sector: RefCounted, index: int) -> int:
	if sector.facility(index) == "repair": return int(sector.facility_cooldowns.get(index, 0))
	return maxi(0, ceili((int(sector.service_ready.get(str(index), 0)) - sector.clock_ms) / 1000.0))


static func access(sector: RefCounted, site: int, side: String) -> String:
	if sector.complete or sector.objectives[site].owner != side: return "Requires %s control" % side
	if not sector.is_supplied(site): return "Installation isolated"
	if sector.objectives[site].contested: return "Installation contested"
	var remaining := cooldown(sector, site)
	return "Recharging · %ds" % remaining if remaining > 0 else ""


static func quotes(sector: RefCounted, site: int, side: String, salvage: int,
		package: Dictionary, missing_hull: int) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var kind: String = sector.facility(site)
	if sector.economy == null or not SERVICES.has(kind): return choices
	var service: Array = SERVICES[kind]
	for attribute: String in service[4]:
		var reason := access(sector, site, side)
		var amount: int = mini(service[2], missing_hull) if attribute == REPAIR else Preparation.benefit(package, attribute, service[2])
		if reason.is_empty() and amount <= 0: reason = "No damage to repair" if attribute == REPAIR else "Preparation at limit"
		if reason.is_empty() and salvage < int(service[1]): reason = "Requires %d Salvage" % int(service[1])
		var details := "+%d %s for next combat" % [amount, attribute.capitalize()]
		if attribute == REPAIR: details = "Restore %d integrity now" % amount
		elif attribute.begins_with("disrupt."): details = "−%d opposing %s next combat" % [amount, attribute.get_slice(".", 1).capitalize()]
		choices.append({"id": "prepare:" + attribute, "attribute": attribute, "title": service[0],
			"details": details, "cost": service[1], "amount": amount, "seconds": 4,
			"enabled": reason.is_empty(), "reason": reason, "recharge": service[3]})
	return choices


static func apply(sector: RefCounted, site: int, action: Dictionary, package: Dictionary) -> void:
	if action.attribute == REPAIR:
		sector.facility_cooldowns[site] = action.recharge
	else:
		Preparation.add(package, action.attribute, action.amount)
		sector.service_ready[str(site)] = sector.clock_ms + action.recharge * sector.STEP_MS
