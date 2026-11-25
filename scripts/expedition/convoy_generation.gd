extends RefCounted
## Independent geography and assignment rolls. No expedition RNG is consumed.
const Convoy = preload("res://scripts/expedition/evacuation_convoy.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
const Variation = preload("res://scripts/expedition/system_variation.gd")
const Factions = preload("res://scripts/expedition/faction_catalog.gd")
const Warfare = preload("res://scripts/expedition/defense_warfare.gd")


static func generate(state: Resource) -> void:
	var fleet: RefCounted = state.defense
	if state.system_number < 3 or not fleet.v2 or not fleet.tuning.convoy_enabled: return
	var faction := Factions.find(state.rules, state.faction_id)
	var elites := Factions.defense_elites(faction, state.system_number)
	if elites.is_empty(): return
	var rng := Variation.rng_for(state.seed_used, state.system_number, "civilian-evacuation")
	var options: Dictionary = state.developer_test if state.system_number == state.developer_test.get("stage") else {}
	var convoy := Convoy.new()
	convoy.setup(state.system_number, fleet.tuning, options.get("convoy_integrity", 0))
	var role := "vanguard" if rng.randf() < 0.6 else "disruptor"
	var enemy := Warfare._choose_ship(elites, role, faction, rng)
	convoy.punitive_entry = Convoy.enemy_entry(enemy, state.system_number)
	Warfare.configure_entry(state, convoy.punitive_entry, enemy, role, 0)
	var reserves: Array = fleet.units.filter(func(unit): return unit.reinforcement)
	convoy.entry_point = reserves.front().route_origin if not reserves.is_empty() else fleet.unit_for(fleet.mothership_index()).route_origin
	var path := _search(fleet, convoy, rng, options.get("convoy_force_pursuit", false))
	if path.is_empty(): return
	convoy.route.assign(path.route)
	for index in path.pursuers:
		convoy.pursuers.append(index)
	fleet.convoy = convoy


static func _search(fleet: RefCounted, convoy: RefCounted, rng: RandomNumberGenerator, force: bool) -> Dictionary:
	var bounds := Layout.bounds(fleet.layout_expansion).grow(-2.1)
	var duration: Vector2 = fleet.tuning.convoy_route_seconds
	var blockers: Array = [[fleet.home, 3.65]]
	var sizes := Layout.planetary_radii(fleet.encounter_ledger, fleet.geometry.get("planet_scales", {}))
	for index in fleet.anchors:
		blockers.append([fleet.anchors[index], maxf(1.9, float(sizes.get(index, 1.0)) + 0.85)])
	for site in fleet.construction_sites.values():
		blockers.append([fleet.point(site.position), 1.75])
	for body in fleet.decorative_bodies:
		blockers.append([body.position, float(body.radius) * 1.553 + 0.8])
	var original: Array = fleet.units.filter(func(unit): return not unit.mothership and not unit.reinforcement)
	var limit := mini(convoy.pursuer_limit, maxi(1, (original.size() - 1) / 2))
	# Stay inside a strict majority of Homeworld-bound opening ships.
	var chosen := {}
	var best := -INF
	for attempt in 900:
		if attempt == 420 and not chosen.is_empty() and not chosen.pursuers.is_empty(): break
		var bearing := rng.randf_range(0.0, TAU)
		var origin: Vector3 = fleet.home + Vector3(cos(bearing), 0, sin(bearing)) * rng.randf_range(4.7, 9.5)
		if not bounds.has_point(Vector2(origin.x, origin.z)) or origin.distance_to(fleet.start) < 3.5: continue
		if original.any(func(unit): return origin.distance_to(unit.position) < 3.7): continue
		var heading := rng.randf_range(0.0, TAU)
		var travel := rng.randf_range(duration.x, duration.y)
		var points: Array[Vector3] = [origin]
		var leg_duration := travel
		var leg_origin := origin
		if attempt >= 420:
			leg_duration = travel * rng.randf_range(0.55, 0.70)
			leg_origin = origin + Vector3(cos(heading), 0, sin(heading)) * leg_duration * convoy.speed
			points.append(leg_origin)
			heading += rng.randf_range(0.6, 2.2) * (-1 if rng.randf() < 0.5 else 1)
		var final_duration := travel if attempt < 420 else travel - leg_duration
		var finish: Vector3 = leg_origin + Vector3(cos(heading), 0, sin(heading)) * final_duration * convoy.speed
		points.append(finish)
		if finish.distance_to(fleet.home) < 16 or not _clear_route(points, bounds, fleet.stellar_clearance() + 0.75, blockers): continue
		convoy.route.assign(points)
		var candidates: Array = []
		for unit in original:
			var role: String = fleet.deployment(unit).get("role", "vanguard")
			var rank: int = fleet.ship_profile(unit).enemy_rank
			if rank == 2 or (not force and role not in ["raider", "vanguard", "disruptor"]): continue
			var eta: float = convoy.pursuit_time(unit.position, fleet._speed(unit))
			if eta < 11 or eta > minf(leg_duration - 0.5, travel - 5.0): continue
			var cross: Vector3 = convoy.guidance(unit.position, fleet._speed(unit))
			if not Layout.clear_stellar_segment(unit.position, cross, fleet.stellar_clearance()): continue
			var player: Vector3 = fleet._intercept(unit.position, cross, fleet._speed(unit), fleet.start)
			if fleet.start.distance_to(player) * fleet.tuning.seconds_per_distance + fleet.tuning.battle_seconds + 3.0 >= eta: continue
			candidates.append({"id":unit.encounter, "eta":eta, "score":absf(eta - 19.0) + (2 if role == "disruptor" else 0)})
		candidates.sort_custom(func(a, b): return a.score < b.score)
		var selected: Array = []
		if not candidates.is_empty():
			selected.append(candidates.front().id)
			for candidate in candidates.slice(1):
				if selected.size() >= limit: break
				if absf(candidate.eta - candidates.front().eta) < 3.0: continue
				selected.append(candidate.id)
		var score: float = float(selected.size()) * 18.0 + finish.length() * 0.10 - absf(travel - 47.0) * 0.06
		if not candidates.is_empty(): score -= float(candidates.front().score) * 0.25
		if score > best:
			best = score
			chosen = {"route":points, "pursuers":selected}
		# Use the first strong candidate after allowing meaningful alternatives.
		if attempt >= 50 and selected.size() >= limit: break
	return chosen



static func _clear_route(points: Array[Vector3], bounds: Rect2, stellar: float, blockers: Array) -> bool:
	for index in range(1, points.size()):
		var previous := points[index - 1]
		var at := points[index]
		if not bounds.has_point(Vector2(at.x, at.z)) or not Layout.clear_stellar_segment(previous, at, stellar):
			return false
		for blocker in blockers:
			if Geometry3D.get_closest_point_to_segment(blocker[0], previous, at).distance_to(blocker[0]) < blocker[1]:
				return false
	return true
