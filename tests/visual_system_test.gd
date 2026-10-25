extends SceneTree
const Data = preload("res://scripts/presentation/star_system/visual_system.gd")
const Settings = preload("res://scripts/presentation/star_system/map_settings.gd")
var checks: int = 0
var failures: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var settings = Settings.new()
	var entries: Array = []
	for i in range(6): entries.append({"index":i,"model_kind":["mining_operation","research_station","gas_giant","quarantined_colony","derelict_starship","battle"][i]})
	var source: String = var_to_str(entries)
	var counts: Dictionary = {}
	var names: Dictionary = {}
	for n in range(1,101): names[Data.Names.system_name(4411,n)] = true
	check(names.size()==100 and Data.Names.NAMES.size()==100,"100 unique verified names without expedition repeats")
	for seed_value in range(300):
		var a: Dictionary = Data.generate(seed_value, 3, entries, settings)
		check(a == Data.generate(seed_value, 3, entries, settings),"Deterministic visual reconstruction")
		check(a.anchors.size()==6,"Exactly existing encounter indices")
		check(a.planets.size()>=2 and a.planets.size()<=4,"Planet count bounded")
		counts[a.planets.size()] = counts.get(a.planets.size(),0)+1
		var assignments: Dictionary = {}
		for p in a.planets:
			check(p.position.is_equal_approx(Data.orbit_point(p,p.phase)),"Planet lies on inclined ellipse")
			check(p.eccentricity>=0 and p.eccentricity<=0.25 and abs(p.inclination)<=deg_to_rad(15),"Orbit parameter bounds")
			check(p.distance*(1-p.eccentricity)-p.radius*1.5>2.1,"Star clearance")
			for other in a.planets:
				if other.index==p.index+1:
					check(other.distance*(1-other.eccentricity)-other.radius*1.5-(p.distance*(1+p.eccentricity)+p.radius*1.5)>=settings.minimum_orbit_spacing-0.0001,"Shell clearance")
			if p.encounter>=0:
				check(p.encounter<4 and not assignments.has(p.encounter),"Suitable encounters assigned at most once")
				assignments[p.encounter]=true
				check(a.anchors[p.encounter]==p.position,"Assigned encounter uses planet anchor")
	check(counts.size()==3,"All counts from two through four represented")
	check(var_to_str(entries)==source,"Generation never mutates encounter input")
	print("Visual system: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
