extends SceneTree
const Regions = preload("res://scripts/expedition/asteroid_regions.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Renderer = preload("res://scripts/presentation/star_system/asteroid_fields.gd")
class WorldIdentity extends Resource:
	var seed_used: int = 1
	var system_number: int = 3
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var gameplay := RandomNumberGenerator.new()
	gameplay.seed = 1234
	var before: int = gameplay.state
	var types := {}
	for seed_value in range(128):
		var fields: Array = Regions.generate(seed_value, 3, [[12.0, 0.0, 0.0]])
		check(fields == Regions.generate(seed_value, 3, [[12.0, 0.0, 0.0]]), "Same seeds and world anchors reproduce compact regions")
		check(fields.size() == 1, "Exactly one formation per new system")
		check(Regions.contains(fields[0], [12.0, 0.0, 0.0]), "Every formation intersects a real exploration encounter")
		for item in fields:
			var snapshot: Dictionary = EnvironmentData.evaluate(WorldIdentity.new(), [12.0,0.0,0.0], [item], 0)
			check(EnvironmentData.modifier_id(snapshot) == 1, "Every formation activates existing modifier 1 by spatial detection")
			check(Regions.valid(item), "Generated region validates")
			types[item.configuration.subtype] = true
			var rng := RandomNumberGenerator.new()
			rng.seed = int(item.visual.seed)
			for sample_index in range(40):
				var point: Vector3 = Regions.sample(item, rng)
				check(Regions.contains(item, [point.x, point.y, point.z]), "Visual asteroid centers use the exact containment geometry")
				check(Vector2(point.x, point.z).length() <= 28.0, "Generated scenery remains in the meaningful system area")
	check(types.size() == 3, "Belts, localized clusters and extended remnants generated across seeds")
	check(gameplay.state == before, "Generation/render sampling does not consume external RNG")
	var belt: Dictionary = Regions.generate(1, 1, [])[0]
	belt.region = {"shape": "belt", "inner": 8.0, "outer": 12.0, "ratio": 0.5, "angle": 0.0, "half_height": 1.0}
	for point in [[8,0,0], [12,0,0], [0,0,4], [0,0,6], [10,1,0]]:
		check(Regions.contains(belt, point), "Annular and vertical boundaries are inclusive")
	for point in [[], [7.99,0,0], [12.01,0,0], [0,0,3.99], [0,0,6.01], [10,1.01,0], [NAN,0,0]]:
		check(not Regions.contains(belt, point), "Outside/unknown/invalid coordinates are neutral")
	belt.region.angle = PI * 0.5
	check(Regions.contains(belt, [0,0,10]) and not Regions.contains(belt, [10,0,0]), "Ellipse rotation changes containment axes")
	var cluster: Dictionary = belt.duplicate(true)
	cluster.region = {"shape": "pockets", "angle": 0.0, "half_height": 1.0, "pockets": [
		{"offset": [-2.0,0.0], "axes": [2.0,1.0], "angle": 0.0},
		{"offset": [2.0,0.0], "axes": [2.0,1.0], "angle": 0.0}]}
	check(Regions.contains(cluster, [-3,0,0]) and Regions.contains(cluster, [3,0,0]) and not Regions.contains(cluster, [0,0,2]), "Union of ellipse pockets, not a second annulus")
	cluster.region.pockets[0].axes[0] = 0
	check(not Regions.valid(cluster) and not Regions.contains(cluster, [0,0,0]), "Degenerate data fails safely")
	var fields: Array = Regions.generate(25, 2, [])
	var exclusions: Array = [{"position": Vector3(12,0,0), "radius": 2.0}, {"position": Vector3.ZERO, "radius": 2.6}]
	var fixture: Dictionary = Regions.generate(1,3,[[12,0,0]])[0]
	var layout: Array = Renderer.sample_layout(fixture, false, exclusions)
	var reduced_layout: Array = Renderer.sample_layout(fixture, true, exclusions)
	check(not layout.is_empty(), "Clearance preserves formation visibility")
	check(layout == Renderer.sample_layout(fixture, false, exclusions), "CPU mesh layout reconstructs exactly")
	check(layout.slice(0,reduced_layout.size()) == reduced_layout, "Android accepted mesh positions are a desktop prefix")
	for rock in layout:
		var transform: Transform3D = rock.transform
		var scale: Vector3 = transform.basis.get_scale()
		check(Renderer.clear_position(transform.origin, maxf(scale.x,maxf(scale.y,scale.z)) - 0.00001, exclusions), "Complete asteroid mesh clears celestial surfaces and margin")
		check(scale.length() < 0.3, "Asteroids remain smaller than map objects")
	check(Renderer.sample_layout(fixture,false,[{"position": Vector3.ZERO,"radius": 100.0}]).is_empty(), "Fully excluded formation has no origin placeholders")
	var desktop: Node3D = Renderer.build(fields, false)
	var mobile: Node3D = Renderer.build(fields, true)
	var repeat: Node3D = Renderer.build(fields, false)
	check(desktop.get_child_count() == fields.size(), "One MultiMesh per region")
	for index in range(desktop.get_child_count()):
		var full: MultiMesh = desktop.get_child(index).multimesh
		var reduced: MultiMesh = mobile.get_child(index).multimesh
		var again: MultiMesh = repeat.get_child(index).multimesh
		check(reduced.instance_count < full.instance_count, "Android reduces visual counts")
		for instance_index in range(reduced.instance_count):
			check(full.get_instance_transform(instance_index) == reduced.get_instance_transform(instance_index), "Android is a deterministic prefix of the same layout")
			check(full.get_instance_transform(instance_index) == again.get_instance_transform(instance_index), "Visual reconstruction is deterministic")
	check(desktop.find_children("*", "CollisionObject3D", true, false).is_empty(), "Asteroids cannot intercept navigation raycasts")
	desktop.free()
	mobile.free()
	repeat.free()
	print("Asteroid regions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
