extends RefCounted
## Optional expeditions off the lattice reuse normal PoI approaches and rewards.

const Layout = preload("res://scripts/expedition/system_layout.gd")
const POIS := [
	preload("res://encounters/derelict_starship.tres"),
	preload("res://encounters/pirate_debris_field.tres"),
	preload("res://encounters/research_station.tres"),
	preload("res://encounters/spatial_anomaly.tres"),
]
const MAX_DISCOVERIES := 3
const DETOURS := ["Nearby", "Moderate", "Remote"]
const DETOUR_SALVAGE := [12, 20, 28]
const CLEARANCE := 4.75


static func populate(state: Resource) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:warzone-discoveries:v1" % [state.seed_used, state.system_number])
	if rng.randf() < 0.12: return
	var sector: RefCounted = state.warzone
	var count := rng.randi_range(1, MAX_DISCOVERIES if sector.objectives.size() > 10 else 2)
	var bounds := Layout.bounds(state.layout_expansion).grow(-3.0)
	var anchors: Array[Vector3] = [sector.outpost_position(state.layout_expansion)]
	for node in sector.objectives: anchors.append(node.position)
	for fleet in sector.fleets:
		if sector.active(fleet): anchors.append(fleet.position)
	var available := POIS.duplicate()
	var reference := reference_route(sector)
	var edges: Array[float] = []
	for edge: Vector2i in sector.links:
		edges.append(sector.objectives[edge.x].position.distance_to(sector.objectives[edge.y].position))
	edges.sort()
	var middle := edges.size() / 2
	var median := edges[middle] if edges.size() % 2 else (edges[middle - 1] + edges[middle]) * 0.5
	for slot in count:
		var point := _sample(bounds, anchors, sector, rng, slot == 0 and rng.randf() < 0.55)
		if not point.is_finite(): break
		var choice := rng.randi_range(0, available.size() - 1)
		var poi: Resource = available.pop_at(choice)
		state.encounter_positions[str(state.encounters.size())] = state.Defense.wire(point)
		state.encounters.append({"kind": "poi", "title": poi.title, "poi": poi, "completed": false, "warzone_detour": detour(point, reference, median)})
		anchors.append(point)


static func _sample(bounds: Rect2, anchors: Array[Vector3], sector: RefCounted,
		rng: RandomNumberGenerator, near_front: bool) -> Vector3:
	var selected := Vector3.INF
	var best := -INF
	for attempt in 72:
		var point := Vector3(rng.randf_range(bounds.position.x, bounds.end.x), 0,
			rng.randf_range(bounds.position.y, bounds.end.y))
		if anchors.any(func(anchor): return point.distance_squared_to(anchor) < CLEARANCE * CLEARANCE): continue
		var clearance := INF
		for edge: Vector2i in sector.links:
			var start: Vector3 = sector.objectives[edge.x].position
			var finish: Vector3 = sector.objectives[edge.y].position
			clearance = minf(clearance, point.distance_to(Geometry3D.get_closest_point_to_segment(point, start, finish)))
		if clearance < 3.0: continue
		var distance: float = point.distance_to(sector.start_position(1.0))
		var score := -absf(distance - (10.0 if near_front else 23.0)) + rng.randf_range(0.0, 4.0)
		if score > best:
			best = score
			selected = point
	return selected


# Shortest distance through the initial lattice to the same deep command
# candidate used by the offensive. Discovery placement cannot change this path.
static func reference_route(sector: RefCounted) -> Array[Vector3]:
	var origin: int = sector.root("allied")
	var target: int = sector.offensive_command_candidate()
	var distance := {origin: 0.0}
	var previous := {}
	var unsettled: Array[int] = [origin]
	while not unsettled.is_empty():
		unsettled.sort_custom(func(a, b): return a < b if distance[a] == distance[b] else distance[a] < distance[b])
		var site: int = unsettled.pop_front()
		if site == target: break
		for next in sector.Lattice.neighbors(site, sector.links):
			var next_distance: float = distance[site] + sector.objectives[site].position.distance_to(sector.objectives[next].position)
			if next_distance >= distance.get(next, INF): continue
			distance[next] = next_distance
			previous[next] = site
			if next not in unsettled: unsettled.append(next)
	var route: Array[Vector3] = [sector.objectives[target].position]
	while previous.has(target):
		target = previous[target]
		route.push_front(sector.objectives[target].position)
	return route


static func detour(point: Vector3, route: Array[Vector3], median: float) -> int:
	var extra := INF
	for i in range(1, route.size()):
		var start := route[i - 1]
		var finish := route[i]
		extra = minf(extra, start.distance_to(point) + point.distance_to(finish) - start.distance_to(finish))
	return 0 if extra <= median else (1 if extra <= 2.0 * median else 2)


static func risky(approach: Resource) -> bool:
	if approach.success_chance >= 1.0 or approach.success_chance <= 0.0 or approach.failure == null: return false
	var failure: Resource = approach.failure
	return approach.salvage_cost > 0 or failure.hull < 0 or failure.salvage < 0 \
		or failure.next_battle.values().any(func(amount): return amount < 0)


static func payout(tier: int, hazardous: bool, approach: Resource, success: bool) -> int:
	return DETOUR_SALVAGE[tier] + (6 * int(risky(approach)) + 4 * int(hazardous) if success else 0)
