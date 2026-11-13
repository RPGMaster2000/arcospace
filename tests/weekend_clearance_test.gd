extends SceneTree
const Clearance = preload("res://scripts/expedition/environment_clearance.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
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
		var saved := Save.encode(state)
		var restored: Resource = Save.new().decode(saved,rules)
		check(restored != null and restored.environmental_instances == state.environmental_instances, "Saving/restoring never regenerates the safe layout")
	print("Weekend environmental clearance: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
