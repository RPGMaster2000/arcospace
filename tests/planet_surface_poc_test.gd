extends SceneTree
## Focused standalone preview check:
## godot --headless --path . --script res://tests/planet_surface_poc_test.gd

const Surface = preload("res://scripts/prototypes/planet_surface_terrain.gd")
const Preview = preload("res://scenes/prototypes/planet_surface_poc.tscn")
var failures := 0
var checks := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	root.size = Vector2i(1280, 720)
	var a := Surface.make_noise(2407, 0.038)
	var b := Surface.make_noise(2540, 0.073)
	var a_again := Surface.make_noise(2407, 0.038)
	var b_again := Surface.make_noise(2540, 0.073)
	for point in [Vector2(1.0, 2.0), Vector2(-24.0, -19.0), Vector2(32.0, 7.0)]:
		check(is_equal_approx(
			Surface.height_at(point.x, point.y, a, b),
			Surface.height_at(point.x, point.y, a_again, b_again)),
			"Fixed seed generates the same surface height")
	check(Surface.POI_SITES.size() == 4, "Exactly four non-living locations")
	var preview := Preview.instantiate()
	root.add_child(preview)
	await process_frame
	check(preview.get_node_or_null("Terrain") is MeshInstance3D, "Procedural terrain exists")
	var ground: MeshInstance3D = preview.get_node("Terrain")
	check(ground.mesh.get_surface_count() == 1, "Terrain contains one surface")
	check(ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == 64 * 64 * 6,
		"Expected low-poly triangle count")
	check(ground.get_child_count() > 0, "Ground has picking collision")
	check(preview.poi_nodes.size() == 4 and preview.get_node("SurfacePOIs").get_child_count() == 4,
		"Four recognizable PoIs are built")
	for location in preview.poi_nodes:
		check(location.get_node_or_null("LocationLabel") is Label3D, "Each location has a label")
	check(preview.ship != null and preview.camera != null, "Existing ship model and camera created")
	preview.approach_poi(1)
	check(preview.moving and preview.destination_poi == 1,
		"PoI inspection commands the ship to fly there")
	preview.approach_poi(-1)
	check(preview.destination_poi == 1, "Invalid destination does not reset current route")
	preview.queue_free()
	await process_frame
	print("Planet surface PoC: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
