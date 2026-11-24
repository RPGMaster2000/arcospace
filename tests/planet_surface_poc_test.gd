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
	var preview = Preview.instantiate()
	root.add_child(preview)
	await process_frame
	check(preview.get_node_or_null("Terrain") is MeshInstance3D, "Procedural terrain exists")
	var ground := preview.get_node("Terrain") as MeshInstance3D
	check(ground.mesh.get_surface_count() == 1, "Terrain contains one surface")
	check(ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() == Surface.GRID_COUNT * Surface.GRID_COUNT * 6,
		"Expected low-poly triangle count")
	var arrays := ground.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var facing_up := true
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i])
		if normal.y <= 0.0 or normals[i].y <= 0.0 or normals[i + 1].y <= 0.0 or normals[i + 2].y <= 0.0:
			facing_up = false
			break
	check(facing_up, "Every triangle has Godot clockwise winding and upward normals")
	check(Surface.HALF_SIZE > preview.CAMERA_BOUND + preview.CAMERA_MAX_SIZE * 0.5 * 16.0 / 9.0,
		"Terrain extends beyond the panned, fully zoomed-out view")
	check(ground.get_child_count() > 0, "Ground has picking collision")
	await physics_frame
	await physics_frame
	var world: World3D = preview.get_world_3d()
	for point in [Vector2.ZERO, Vector2(-39, 42), Vector2(120, -120)]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 40, point.y), Vector3(point.x, -40, point.y))
		check(not world.direct_space_state.intersect_ray(query).is_empty(), "Terrain picks from above at %s" % point)
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
	var initial_y: float = preview.ship.position.y
	var original_center: Vector2 = preview.camera_center
	preview.pan_screen(Vector2(640, 360), Vector2(740, 360))
	check(preview.camera_center.distance_to(original_center) > 0.5, "Dragging pans the camera")
	var panned_center: Vector2 = preview.camera_center
	preview.set_process(false)
	for step in range(12):
		preview._process(0.1)
		check(is_equal_approx(preview.ship.position.y, initial_y), "Ship stays at a constant global altitude")
	check(preview.ship.position.y == preview.FLIGHT_ALTITUDE, "Ship uses the fixed flight plane")
	check(preview.camera_center == panned_center, "Camera stays panned while ship moves")
	check(preview.ship.position.y > ground.mesh.get_aabb().end.y + 5.0, "Flight plane clears the terrain")
	preview._center_ship()
	check(preview.camera_center.is_equal_approx(Vector2(preview.ship.position.x, preview.ship.position.z)), "Center control returns to ship")
	var zoom_before: float = preview._camera_size
	preview._zoom_factor(0.8)
	check(preview._camera_size < zoom_before, "Pinch-in factor zooms closer")
	preview.queue_free()
	await process_frame
	print("Planet surface PoC: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
