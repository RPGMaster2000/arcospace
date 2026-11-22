extends RefCounted
## Deterministic assignment policy for the existing fleet movement and combat simulation.

const Lattice = preload("res://scripts/expedition/warzone_lattice.gd")
const INTERVAL_MS := 3000
const COMMIT_MS := 6000
const RECOVERY_MS := 3000
const MIN_RESPONSE_STRENGTH := 3


static func assign(sector: RefCounted, emergency: bool, reassign: bool = false) -> void:
	var threats := _threats(sector)
	var committed := {}
	var available: Array[Dictionary] = []
	for fleet in sector.fleets:
		if fleet.side != "allied" or not sector.active(fleet) or fleet.get("arriving", false):
			continue
		if fleet.strength < MIN_RESPONSE_STRENGTH and _recover(sector, fleet):
			continue
		if fleet.engaged >= 0 or fleet.withdrawing: continue
		var target: int = fleet.get("intercept", -1)
		if not reassign and sector._fleet_supplied(fleet) and sector.clock_ms < fleet.get("commit_until", 0) and threats.has(target):
			committed[target] = float(committed.get(target, 0.0)) + _power(sector, fleet)
			continue
		available.append(fleet)

	# Competing assignments share a response budget, so a second formation only
	# joins when the first and any ships already engaged need the help.
	while not available.is_empty():
		var best := 0.0
		var chosen := {}
		var contact := -1
		for fleet in available:
			for id in threats:
				var threat: Dictionary = threats[id]
				var score := _score(sector, fleet, threat, float(committed.get(id, 0.0)), emergency)
				if score > best:
					best = score
					chosen = fleet
					contact = id
		if chosen.is_empty(): break
		available.erase(chosen)
		committed[contact] = float(committed.get(contact, 0.0)) + _power(sector, chosen)
		if chosen.get("intercept", -1) != contact or reassign:
			chosen.commit_until = sector.clock_ms + COMMIT_MS
		chosen.intercept = contact
		chosen.assignment = "Assisting" if threats[contact].assisting else "Intercepting"
	for fleet in available:
		clear_interception(sector, fleet)


static func clear_interception(sector: RefCounted, fleet: Dictionary) -> void:
	if not fleet.has("intercept"): return
	fleet.erase("intercept")
	fleet.erase("assignment")
	fleet.erase("commit_until")
	if sector.active(fleet) and fleet.engaged < 0:
		fleet.destination = sector._direct_target(fleet)


static func frontier_target(sector: RefCounted, fleet: Dictionary) -> int:
	var loads := {}
	var hostile_power := {}
	for formation in sector.fleets:
		if formation.id == fleet.id or not sector.active(formation) or formation.withdrawing:
			continue
		var site: int = formation.destination
		if formation.side == "allied":
			if not formation.get("arriving", false) and not formation.has("intercept"):
				loads[site] = int(loads.get(site, 0)) + 1
		else:
			# A committed defender or attacker can justify a second formation.
			hostile_power[site] = float(hostile_power.get(site, 0.0)) + _power(sector, formation)
	var best := -INF
	var target: int = fleet.at
	var own_power := _power(sector, fleet)
	for site in sector.objectives.size():
		var objective: Dictionary = sector.objectives[site]
		var final: bool = site == sector.final_command
		if objective.owner == "allied" and not final: continue
		if not sector.route_valid("allied", fleet.at, site): continue
		var assigned: int = loads.get(site, 0)
		var defenders: float = hostile_power.get(site, 0.0)
		# A single response is enough for an undefended minor objective.
		var capacity := 2 if defenders > own_power * 1.15 else 1
		if assigned >= capacity: continue
		var eta: float = (fleet.position as Vector3).distance_to(objective.position) / sector.fleet_speed(fleet)
		var neighbors := Lattice.neighbors(site, sector.links, sector.disrupted).size()
		var score := (18.0 if final else 0.0) + float(neighbors) * 1.4 - eta * 0.55 - assigned * 7.0
		if score > best:
			best = score
			target = site
	return target


static func _power(sector: RefCounted, fleet: Dictionary) -> float:
	return float(fleet.strength * sector._shot_damage(fleet))


static func _threats(sector: RefCounted) -> Dictionary:
	var result := {}
	for enemy in sector.fleets:
		if enemy.side != "hostile" or not sector.active(enemy) or enemy.withdrawing: continue
		var site: int = enemy.destination
		var objective: Dictionary = sector.objectives[site]
		var threatens_site: bool = objective.owner == "allied" and sector.route_valid("hostile", enemy.at, site)
		var victim: Dictionary = sector.fleet_at(enemy.engaged)
		var assisting: bool = sector.active(victim) and victim.side == "allied"
		var allies_present := 0.0
		if assisting:
			for fleet in sector.fleets:
				if fleet.engaged == enemy.id and sector.active(fleet):
					allies_present += _power(sector, fleet)
		var enemy_power := _power(sector, enemy)
		var seconds := INF
		var importance := 0.0
		if threatens_site:
			importance = sector.allied_site_importance(site)
			seconds = (enemy.position as Vector3).distance_to(objective.position) / sector.fleet_speed(enemy)
			seconds += sector.tuning.capture_seconds - objective.progress
		# Pursuers threaten the player's escape corridor, even if their
		# original static objective is neutral or hostile-owned. Allies can
		# proactively cross that corridor and intercept the actual ship.
		if enemy.id == sector.player_hunter:
			importance = maxf(importance, 14.0)
			seconds = minf(seconds, maxf(0.0,
				float(sector.hunter_until - sector.clock_ms) / sector.STEP_MS))
		if assisting:
			var incoming := 0
			for attacker in sector.fleets:
				if sector.active(attacker) and attacker.engaged == victim.id:
					incoming += sector._shot_damage(attacker)
			var volleys := maxi(1, ceili(float(victim.strength) / maxi(1, incoming)))
			var interval: int = sector.tuning.exchange_seconds * sector.STEP_MS
			seconds = minf(seconds, (volleys * interval - posmod(sector.clock_ms, interval)) / float(sector.STEP_MS))
		result[enemy.id] = {"enemy": enemy, "importance": importance, "seconds": seconds,
			"assisting": assisting, "need": maxf(0.0, enemy_power * 1.08 - allies_present)}
	return result


static func _score(sector: RefCounted, fleet: Dictionary, threat: Dictionary, committed: float, emergency: bool) -> float:
	if fleet.strength < MIN_RESPONSE_STRENGTH or not sector._fleet_supplied(fleet): return 0.0
	if threat.need <= committed or (threat.importance == 0.0 and not threat.assisting and not emergency): return 0.0
	var enemy: Dictionary = threat.enemy
	var intercept := interception_point(sector, fleet, enemy)
	var eta: float = maxf(0.0, (fleet.position as Vector3).distance_to(intercept) - sector.tuning.engagement_radius) / sector.fleet_speed(fleet)
	if eta > (24.0 if emergency or enemy.id == sector.player_hunter else 16.0) or eta > threat.seconds + 1.0: return 0.0
	var power := _power(sector, fleet)
	var required: float = threat.need - committed
	# Permit a risky defense of exposed critical infrastructure. For ordinary
	# pursuits, require a credible individual or combined response.
	if power + committed < threat.need * 0.38 and threat.importance < 8.0: return 0.0
	var at: Dictionary = sector.objectives[fleet.destination]
	var capture_cost := 0.0
	if at.capturing == "allied" and (fleet.position as Vector3).distance_to(at.position) <= sector.tuning.objective_radius:
		capture_cost = 4.0 + 8.0 * float(at.progress) / sector.tuning.capture_seconds
		if fleet.destination == sector.final_command: capture_cost += 4.0
	if at.owner == "allied" and fleet.at == fleet.destination and fleet.destination != enemy.destination \
		and (fleet.position as Vector3).distance_to(at.position) <= sector.tuning.objective_radius:
		capture_cost += sector.allied_site_importance(fleet.at) * 0.35
	var commitment := 0.0
	if fleet.has("intercept"):
		commitment = 2.0 if fleet.intercept == enemy.id else -2.0
	return threat.importance * 1.4 + (5.0 if threat.assisting else 0.0) \
		+ (7.0 if emergency else 0.0) + minf(3.0, 3.0 * power / required) + commitment \
		- 0.6 * eta - capture_cost


static func _recover(sector: RefCounted, fleet: Dictionary) -> bool:
	if fleet.withdrawing: return true
	var enemy: Dictionary = sector.fleet_at(fleet.engaged)
	if not sector.active(enemy) or _power(sector, fleet) >= _power(sector, enemy): return false
	var safe := -1
	var closest := INF
	for site in sector.supplied.allied:
		if not sector.route_valid("allied", fleet.at, site): continue
		var point: Vector3 = sector.objectives[site].position
		if (enemy.position as Vector3).distance_to(point) < sector.tuning.engagement_radius * 1.6: continue
		var distance: float = (fleet.position as Vector3).distance_squared_to(point)
		if distance < closest:
			closest = distance
			safe = site
	if safe < 0: return false
	clear_interception(sector, fleet)
	fleet.destination = safe
	fleet.engaged = -1
	fleet.withdrawing = true
	fleet.recover_until = sector.clock_ms + RECOVERY_MS
	return true


static func interception_point(sector: RefCounted, fleet: Dictionary, enemy: Dictionary) -> Vector3:
	var start: Vector3 = enemy.position
	var hunting: bool = enemy.id == sector.player_hunter and sector._player_position.is_finite()
	if enemy.engaged >= 0 or (not hunting and not sector.route_valid(enemy.side, enemy.at, enemy.destination)):
		return start
	var finish: Vector3 = sector._player_position if hunting else sector.objectives[enemy.destination].position
	var pursuer_speed: float = sector.fleet_speed(enemy) * (sector.tuning.hunt_speed_multiplier if hunting else 1.0)
	var velocity: Vector3 = start.direction_to(finish) * pursuer_speed
	var separation: Vector3 = start - fleet.position
	var speed: float = sector.fleet_speed(fleet)
	# Solve |separation + velocity * t| = speed * t along the ordered leg.
	var a := velocity.length_squared() - speed * speed
	var b := 2.0 * separation.dot(velocity)
	var c := separation.length_squared()
	var travel: float = start.distance_to(finish) / pursuer_speed
	var time := travel
	if absf(a) < 0.00001:
		if b < -0.00001: time = minf(time, -c / b)
	elif b * b >= 4.0 * a * c:
		var discriminant := sqrt(b * b - 4.0 * a * c)
		for root in [(-b - discriminant) / (2.0 * a), (-b + discriminant) / (2.0 * a)]:
			if root >= 0.0: time = minf(time, root)
	return start + velocity * time
