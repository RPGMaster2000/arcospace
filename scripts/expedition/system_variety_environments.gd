extends RefCounted
## New-system parameter adapter; existing physical records remain authoritative.
const Variation = preload("res://scripts/expedition/system_variation.gd")
const Weather = preload("res://scripts/expedition/extreme_weather.gd")
const Storms = preload("res://scripts/expedition/storm_regions.gd")
const Routes = preload("res://scripts/expedition/route_environments.gd")


static func solar_range(state: Resource) -> Vector2:
	if state.system_variation.is_empty():
		return state.rules.solar_influence_radius_range
	var band: Array = state.system_variation.solar_range
	return Vector2(band[0], band[1])


static func storms(state: Resource, candidates: Array, existing: Array) -> Array:
	var result: Array = []
	var profile: Dictionary = state.system_variation
	var varied := not profile.is_empty()
	if profile.has("weather"):
		return Weather.fronts(state, profile.weather, Variation.rng_for(state.seed_used, state.system_number, "extreme-fronts"))
	var count: int = int(profile.storm_count) if varied else 1
	for index in count:
		var seed_value: int = (
			state.seed_used
			if index == 0
			else hash("%d:%d:extra-storm:v1" % [state.seed_used, index])
		)
		var chance: float = state.rules.space_storm_chance
		if varied and profile.archetype == "storm_dominated" and chance > 0:
			chance = 1.0
		elif profile.get("version") == 2 and profile.archetype in ["unstable", "chaotic"]:
			chance = minf(1.0, chance * 1.35)
		var storm := Storms.generate(
			seed_value,
			state.system_number,
			chance,
			candidates,
			existing + result,
			state.layout_expansion
		)
		if storm.is_empty():
			continue
		if varied:
			var rng := Variation.rng_for(
				state.seed_used, state.system_number, "storm-shape-%d" % index
			)
			var band: Array = profile.storm_range
			storm.id = "storm-%d-%d" % [state.system_number, index]
			storm.region.axes = [
				rng.randf_range(band[0], band[1]),
				rng.randf_range(2.4, 4.0),
				rng.randf_range(band[0], band[1])
			]
			storm.region.angle = rng.randf_range(0, TAU)
			storm.intensity = rng.randf_range(0.55, 0.9)
			storm.generation.extended = true
		if profile.get("version") == 2:
			var base := preserve_approaches(state, existing + result)
			storm = _place_later_storm(state, storm, candidates, base)
		elif state.is_defense() and state.defense.v2:
			storm = Routes.storm(storm, state.defense, candidates, existing + result)
		if not storm.is_empty():
			result.append(JSON.parse_string(JSON.stringify(storm)))
	return result

# Sample each approach and its neighboring space. Keep placement bounded so
# the other flank remains a genuine alternative even in the strongest storms.
static func _place_later_storm(state: Resource, storm: Dictionary, candidates: Array, accepted: Array) -> Dictionary:
	var fleet: RefCounted = state.defense
	var clearance = preload("res://scripts/expedition/environment_clearance.gd")
	var layout = preload("res://scripts/expedition/system_layout.gd")
	var bounds := layout.bounds(state.layout_expansion) as Rect2
	var home_radius: float = clearance.home_radius(fleet.tuning.environment_visual_margin)
	var axes := Vector2(storm.region.axes[0], storm.region.axes[2])
	var angle: float = storm.region.angle
	var extent := Vector2(absf(cos(angle)) * axes.x + absf(sin(angle)) * axes.y,
		absf(sin(angle)) * axes.x + absf(cos(angle)) * axes.y)
	var offsets := [Vector3.ZERO, Vector3(7, 0, 0), Vector3(0, 0, 7), Vector3(-7, 0, 0), Vector3(0, 0, -7)]
	var positions := [clearance.point(storm.position)]
	for offset in offsets:
		for location in candidates:
			positions.append(clearance.point(location) + offset)
	for at in positions:
		var plane := Vector2(at.x, at.z)
		if plane.length() < 12.0 or not bounds.encloses(Rect2(plane - extent, extent * 2.0)): continue
		storm.position = fleet.wire(at)
		if clearance.intersects_sphere(storm, fleet.home, home_radius) or not Routes.relevant(storm, fleet): continue
		if preserve_approaches(state, accepted + [storm]).has(storm): return storm
	return {}


## Keep the player start, at least one nearby preparation site and one opening
## interception on a clean route. The encounter's existing modifier resolves it.
static func preserve_approaches(state: Resource, records: Array) -> Array:
	var fleet: RefCounted = state.defense
	var clearance = preload("res://scripts/expedition/environment_clearance.gd")
	var layout = preload("res://scripts/expedition/varied_system_layout.gd")
	var opportunities: Array = []
	for index in fleet.anchors:
		var at: Vector3 = fleet.anchors[index]
		if index >= 0 and state.encounters[index].poi.resource_path.get_file().get_basename() not in layout.PREPARATION: continue
		if at.distance_to(fleet.start) * fleet.tuning.seconds_per_distance <= 3.0:
			opportunities.append(at)
	var opening: Array = []
	for unit in fleet.units:
		if unit.mothership or unit.reinforcement: continue
		opening.append(fleet.intercept_point(unit.encounter, fleet.start))
	var result: Array = []
	for item in records:
		if clearance.intersects_sphere(item, fleet.start, 0.25): continue
		var clean: Array = opportunities.filter(func(at): return not Routes.intersects(item, fleet.start, at))
		if clean.is_empty() and not opportunities.is_empty(): continue
		var intercepts: Array = opening.filter(func(at): return not Routes.intersects(item, fleet.start, at))
		if intercepts.is_empty(): continue
		if item.type == Storms.TYPE:
			var center := clearance.point(item.position)
			if result.any(func(other): return other.type == Storms.TYPE and clearance.point(other.position).distance_to(center) < 9.0):
				continue
		opportunities = clean
		opening = intercepts
		result.append(item)
	return result
