extends SceneTree
const Catalog = preload("res://scripts/expedition/defense_poi_approaches.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	for id in ["mining_operation","research_station","spatial_anomaly","gas_giant","distress_signal","derelict_starship","radiation_nebula","pirate_debris_field","raider_cache","quarantined_colony","fuel_depot","sensor_relay","ancient_navigation_array","unstable_wormhole"]:
		var original: Resource = load("res://encounters/"+id+".tres")
		var before: Array = []
		for approach in original.approaches: before.append([approach.success_chance,approach.success,approach.failure])
		var rows: Array = Catalog.definitions(id)
		check(not rows.is_empty(), id+" has Defense approaches")
		check(rows.any(func(row): return row.approach.requirement.is_empty()), id+" has an ungated approach")
		for row in rows:
			check(row.approach.success_chance == 1.0 and row.seconds > 0, "Guaranteed explicit time cost")
			check(not row.reward.is_empty() and not row.description.is_empty(), "Outcome and preview defined")
		for index in original.approaches.size():
			var approach: Resource = original.approaches[index]
			check(before[index] == [approach.success_chance,approach.success,approach.failure], "Exploration resource unchanged")
		rows[0].approach.title = "detached"
		check(Catalog.definitions(id)[0].approach.title != "detached", "Catalogue callers do not share mutable resources")
	check(Catalog.definitions("trading_outpost").is_empty(), "Trading service is not an ordinary PoI")
	print("Defense PoI catalogue: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
