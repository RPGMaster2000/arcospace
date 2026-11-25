extends RefCounted
## Both factions share local station planning. Existing tactical orders take precedence.

const Stations = preload("res://scripts/expedition/warzone_stations.gd")
const Package = preload("res://scripts/combat/combat_preparation.gd")
const PRODUCTION_FOR := {"materials": "synthesizer", "energy": "reactor", "crew": "quarters"}
const PLAN_MS := 3000
const MAX_PREP_TRAVEL := 9.0
const MAX_REPAIR_TRAVEL := 24.0


static func configure_preference(fleet: Dictionary, profile: Resource) -> void:
	var weights := {}
	for key in Package.RESOURCES: weights[key] = float(profile.card_family_weights.get(key, 1.0))
	for card in profile.starting_cards: weights[card.family] = float(weights.get(card.family, 0.0)) + 1.0
	var preferred: String = Package.RESOURCES.front()
	for key: String in Package.RESOURCES:
		if weights[key] > weights[preferred]: preferred = key
	fleet.preferred_resource = preferred


static func _urgent(sector: RefCounted, fleet: Dictionary) -> bool:
	if fleet.id == sector.player_hunter or fleet.engaged >= 0 or fleet.withdrawing or fleet.has("intercept"): return true
	if fleet.side == "hostile":
		return sector.final_defense_active or (fleet.counter_target >= 0 and sector.clock_ms >= sector.jam_until)
	return sector.final_command >= 0 and fleet.destination == sector.final_command


static func plan(sector: RefCounted) -> void:
	for fleet in sector.fleets:
		if not sector.active(fleet) or fleet.get("arriving", false) or fleet.has("service_site") \
			or fleet.withdrawing or _urgent(sector, fleet): continue
		_choose(sector, fleet)


static func _choose(sector: RefCounted, fleet: Dictionary) -> void:
	var missing: int = fleet.strength_limit - fleet.strength
	var damaged: bool = missing >= 3 and fleet.strength <= maxi(3, floori(fleet.strength_limit * 0.65))
	var target: Dictionary = sector.objectives[fleet.destination]
	var position: Vector3 = fleet.position
	if target.capturing == fleet.side and target.progress > 0 and position.distance_to(target.position) <= sector.tuning.objective_radius:
		return
	var wallet: int = sector.economy.wallets[fleet.side]
	if not damaged and sector.fleets.any(func(other):
		return (other.id != fleet.id and other.side == fleet.side and sector.active(other)
			and other.get("service_site", -1) >= 0 and sector.facility(other.service_site) == "repair")):
		wallet -= 4
	if wallet < (4 if damaged else 6): return
	var package: Dictionary = sector.fleet_preparations.get(str(fleet.id), {})
	if not damaged and not package.is_empty(): return
	var best := -INF
	var chosen := -1
	for site: int in sector.supplied[fleet.side]:
		var kind: String = sector.facility(site)
		if (kind == "repair") != damaged: continue
		if not sector.route_valid(fleet.side, fleet.at, site): continue
		var distance: float = position.distance_to(sector.objectives[site].position)
		var eta: float = distance / sector.fleet_speed(fleet)
		if eta > (MAX_REPAIR_TRAVEL if damaged else MAX_PREP_TRAVEL): continue
		var quote := _quote(sector, fleet, site, package, wallet)
		if quote.is_empty(): continue
		var slots: bool = sector.fleets.any(func(other):
			return other.id != fleet.id and sector.active(other) and other.get("service_site", -1) == site)
		if slots: continue
		var onward: Vector3 = target.position - position
		var towards: Vector3 = sector.objectives[site].position - position
		# Keep healthy formations on their existing offensive axis unless
		# the installation is already local to their flight path.
		if not damaged and fleet.destination != fleet.at and distance > sector.tuning.objective_radius \
			and onward.normalized().dot(towards.normalized()) < 0.72: continue
		var score := (7.0 if kind == "repair" else 0.0) + int(quote.amount) * 0.4 - eta
		if score > best:
			best = score
			chosen = site
	if chosen < 0: return
	fleet.service_site = chosen
	fleet.destination = chosen


static func _quote(sector: RefCounted, fleet: Dictionary, site: int, package: Dictionary, wallet: int) -> Dictionary:
	var preferred: String = fleet.get("preferred_resource", "energy" if fleet.role in ["Assault", "Vanguard"] else "materials")
	var opposition := preferred
	if sector.facility(site) == "jam":
		var closest := INF
		for other in sector.fleets:
			if other.side == fleet.side or not sector.active(other): continue
			var distance: float = (fleet.position as Vector3).distance_squared_to(other.position)
			if distance < closest:
				closest = distance
				opposition = other.get("preferred_resource", "energy")
	for offer in Stations.quotes(sector, site, fleet.side, wallet, package, fleet.strength_limit - fleet.strength):
		if offer.enabled and offer.attribute in [Stations.REPAIR, "shields", preferred, PRODUCTION_FOR[preferred], "disrupt." + opposition]:
			return offer
	return {}


static func movement(sector: RefCounted, fleet: Dictionary, seconds: float) -> bool:
	if not fleet.has("service_site"): return false
	var site: int = fleet.service_site
	var package: Dictionary = sector.fleet_preparations.get(str(fleet.id), {})
	var offer := _quote(sector, fleet, site, package, sector.economy.wallets[fleet.side])
	if _urgent(sector, fleet) or not sector.route_valid(fleet.side, fleet.at, site) or offer.is_empty():
		cancel(sector, fleet)
		return false
	var point: Vector3 = sector.objectives[site].position
	fleet.position = (fleet.position as Vector3).move_toward(point, sector.fleet_speed(fleet) * seconds)
	if (fleet.position as Vector3).distance_squared_to(point) > 0.00001: return true
	fleet.at = site
	if sector.economy.spend(fleet.side, offer.cost):
		Stations.apply(sector, site, offer, package)
		if offer.attribute == Stations.REPAIR:
			fleet.strength += offer.amount
			fleet.erase("recover_until")
		else:
			sector.fleet_preparations[str(fleet.id)] = package
		sector._notice("%s %s · %s" % [fleet.side.capitalize(), offer.title, sector.objective_name(site)])
	cancel(sector, fleet)
	return true


static func cancel(sector: RefCounted, fleet: Dictionary) -> void:
	if not fleet.has("service_site"): return
	if fleet.destination == fleet.service_site: fleet.destination = sector._direct_target(fleet)
	fleet.erase("service_site")


static func status(sector: RefCounted, fleet: Dictionary) -> String:
	match sector.facility(fleet.service_site):
		"repair": return "Repairing"
		"sabotage": return "Resupplying"
		"coordinate": return "Optimizing"
		"fortify": return "Reinforcing Shields"
		_: return "Preparing Disruption"
