extends SceneTree
const Clearance = preload("res://scripts/expedition/environment_clearance.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Visual = preload("res://scripts/presentation/star_system/visual_system.gd")
const DefenseVisual = preload("res://scripts/presentation/star_system/defense_presentation.gd")
const Settings = preload("res://resources/presentation/star_system_settings.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var elongated := {"position":[0,0,0],"region":{"shape":"ellipsoid","axes":[10,1,1]}}
	check(Clearance.intersects_sphere(elongated,Vector3(10.5,0,0),0.6), "Full elongated region intersects despite distant center")
	check(not Clearance.intersects_sphere(elongated,Vector3(0,3,0),0.6), "Non-spherical geometry preserves clear polar space")
	check(is_equal_approx(Clearance.ellipsoid_distance(Vector3(12,0,0),Vector3(10,1,1)),2), "Ellipsoid external distance matches analytical axis case")
	var belt := {"position":[0,0,0],"region":{"shape":"belt","inner":5,"outer":10,"ratio":0.8,"angle":0,"half_height":0.5}}
	check(not Clearance.intersects_sphere(belt,Vector3.ZERO,1), "Annular inner hole remains clear")
	check(Clearance.intersects_sphere(belt,Vector3(9,0,0),1), "Belt occupied annulus protects sphere volume")
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	for seed_value in range(1,41):
		var state := State.new()
		state.start(0,rules,seed_value)
		var twin := State.new()
		twin.start(0,rules,seed_value)
		check(state.environmental_instances == twin.environmental_instances and state.rng.state == twin.rng.state, "Clearance generation remains deterministic")
		for item in state.environmental_instances:
			check(not Clearance.intersects_sphere(item,state.defense.home,Clearance.home_radius(rules.defense_tuning.environment_visual_margin)), "Every generated region clears complete homeworld geometry")
		var solar: float = Clearance.solar_clearance(state.environmental_instances)
		var visual := Visual.generate(state.seed_used,state.system_number,[],Settings,state.system_profile,state.layout_expansion,state.orbit_clearance,solar)
		DefenseVisual.layout(visual,state.defense.snapshot(),State.SystemLayout.planetary_indices(state.encounters),state.layout_expansion,state.orbit_clearance,State.SystemLayout.planetary_radii(state.encounters),solar)
		for planet in visual.planets:
			if planet.type == "gas_giant":
				check(planet.distance*(1.0-planet.eccentricity)-Visual.planet_extent(planet) >= solar,"Full gas giant orbit clears actual saved Solar volume")
		for index in State.SystemLayout.planetary_indices(state.encounters):
			if state.encounters[index].poi.resource_path.get_file().get_basename() == "gas_giant":
				check(state.defense.anchors[index].length()-State.SystemLayout.planetary_radius("gas_giant") >= solar,"Authoritative gas PoI orbit clears stellar volume")
		var rng_before: int = state.rng.state
		Clearance.protect_home(state,state.environmental_instances,[])
		check(state.rng.state == rng_before,"Clearance cannot consume gameplay RNG")
		var saved := Save.encode(state)
		var restored: Resource = Save.new().decode(saved,rules)
		check(restored != null and restored.environmental_instances == state.environmental_instances, "Saving/restoring never regenerates the safe layout")
		check(restored != null and restored.defense.decorative_bodies == state.defense.decorative_bodies,"Live and restored collision bodies use final saved environment layout")
	# Unmarked historical Solar records must retain their original layout.
	var old_solar := State.EnvironmentData.Solar.generate(7,1,[0,0,0],2.0)
	check(Clearance.solar_clearance([old_solar]) == 0.0,"Legacy systems never opt into new orbital placement on load")
	for seed_value in range(1,21):
		var entries := [{"index":0,"model_kind":"gas_giant","profile":null}]
		var neutral := Visual.generate(seed_value,1,entries,Settings,"industrial",1.5,0.6)
		var adjusted := Visual.generate(seed_value,1,entries,Settings,"industrial",1.5,0.6,10.0)
		check(neutral.planets.size() == adjusted.planets.size(),"Gas clearance preserves planet count")
		for i in neutral.planets.size():
			check(neutral.planets[i].radius == adjusted.planets[i].radius and neutral.planets[i].material_seed == adjusted.planets[i].material_seed,"Gas clearance preserves procedural size and material draws")
			if adjusted.solar_clear and adjusted.planets[i].type == "gas_giant":
				check(adjusted.planets[i].distance*(1.0-adjusted.planets[i].eccentricity)-Visual.planet_extent(adjusted.planets[i]) >= 10.0,"Exploration full gas orbit clears volume")
	print("Weekend environmental clearance: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
