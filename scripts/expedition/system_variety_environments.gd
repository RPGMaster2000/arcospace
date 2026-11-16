extends RefCounted
## New-system parameter adapter; existing physical records remain authoritative.
const Variation = preload("res://scripts/expedition/system_variation.gd")
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
		if state.is_defense() and state.defense.v2:
			storm = Routes.storm(storm, state.defense, candidates, existing + result)
		if not storm.is_empty():
			result.append(JSON.parse_string(JSON.stringify(storm)))
	return result
