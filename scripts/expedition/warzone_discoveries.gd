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
	for slot in count:
		var point := _sample(bounds, anchors, sector, rng, slot == 0 and rng.randf() < 0.55)
		if not point.is_finite(): break
		var choice := rng.randi_range(0, available.size() - 1)
		var poi: Resource = available.pop_at(choice)
		state.encounter_positions[str(state.encounters.size())] = state.Defense.wire(point)
		state.encounters.append({"kind": "poi", "title": poi.title, "poi": poi, "completed": false})
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
