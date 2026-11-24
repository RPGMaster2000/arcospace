extends Node3D
## Standalone planetary landscape preview. No expedition state, assets or combat changes.
## Open scenes/prototypes/planet_surface_poc.tscn and press F6 in the Godot editor.

const Terrain = preload("res://scripts/prototypes/planet_surface_terrain.gd")
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const PLAYER = preload("res://ships/player/endeavour.tres")

const POIS := [
	{"name": "ANCIENT SIGNAL SPIRE", "kind": "spire", "site": Vector2(-29.0, -24.0),
		"detail": "An abandoned transmitter still pulses with an unidentified frequency."},
	{"name": "SEALED RESEARCH VAULT", "kind": "vault", "site": Vector2(29.0, -20.0),
		"detail": "A reinforced bunker with an illuminated but locked access hatch."},
	{"name": "CRASHED SURVEY PROBE", "kind": "wreck", "site": Vector2(-28.0, 27.0),
		"detail": "A damaged survey craft embedded in the sand. No life signs."},
	{"name": "GEOTHERMAL EXTRACTOR", "kind": "extractor", "site": Vector2(29.0, 27.0),
		"detail": "An inactive industrial array with two large collection towers."}
]
const FLIGHT_SPEED := 19.0
const ARRIVAL_DISTANCE := 1.5
const FLY_HEIGHT := 2.8
const CAMERA_MIN_SIZE := 32.0
const CAMERA_MAX_SIZE := 110.0

@export var landscape_seed := 2407
var hills: FastNoiseLite
var ridges: FastNoiseLite
var details: FastNoiseLite
var ship: Node3D
var camera: Camera3D
var destination := Vector2.ZERO
var moving := false
var destination_poi := -1
var poi_nodes: Array[Node3D] = []
var status_label: Label
var _camera_size := 78.0
var _touch_origin := Vector2.ZERO
var _touch_active := false
var _touch_dragged := false


func _ready() -> void:
	hills = Terrain.make_noise(landscape_seed, 0.038)
	ridges = Terrain.make_noise(landscape_seed + 133, 0.073)
	details = Terrain.make_noise(landscape_seed + 712, 0.12)
	_build_lighting()
	_build_terrain()
	_build_scenery()
	_build_pois()
	_build_ship()
	_build_hud()


func surface_height(x: float, z: float) -> float:
	return Terrain.height_at(x, z, hills, ridges)


func _build_lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#242631")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#d2bba9")
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-55.0, -32.0, 0.0)
	sunlight.light_color = Color("#ffe2bb")
	sunlight.light_energy = 1.3
	sunlight.shadow_enabled = false
	add_child(sunlight)
	camera = Camera3D.new()
	camera.name = "SurfaceCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = _camera_size
	camera.near = 0.2
	camera.far = 350.0
	camera.current = true
	add_child(camera)


func _build_terrain() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "Terrain"
	ground.mesh = Terrain.terrain_mesh(hills, ridges, details)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# Terrain ray collision makes tap-to-fly land on the actual heightmap, not a flat plane.
	ground.create_trimesh_collision()


func _build_scenery() -> void:
	var scenery := Node3D.new()
	scenery.name = "Scenery"
	add_child(scenery)
	var rng := RandomNumberGenerator.new()
	rng.seed = landscape_seed + 900
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	var mesh_instances := MultiMesh.new()
	mesh_instances.transform_format = MultiMesh.TRANSFORM_3D
	mesh_instances.use_colors = true
	mesh_instances.mesh = rock
	mesh_instances.instance_count = 100
	var placed := 0
	var tries := 0
	while placed < mesh_instances.instance_count and tries < 2500:
		tries += 1
		var x := rng.randf_range(-59.0, 59.0)
		var z := rng.randf_range(-59.0, 59.0)
		if Vector2(x, z).distance_to(Vector2(0, 6)) < 8.0:
			continue
		var near_poi := false
		for site in Terrain.POI_SITES:
			if Vector2(x, z).distance_to(site) < 8.5:
				near_poi = true
				break
		if near_poi:
			continue
		var width := rng.randf_range(1.0, 3.4)
		var height := rng.randf_range(1.2, 4.8)
		var depth := rng.randf_range(1.0, 2.8)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, depth))
		var at := Vector3(x, surface_height(x, z) + height * 0.5, z)
		mesh_instances.set_instance_transform(placed, Transform3D(basis, at))
		mesh_instances.set_instance_color(placed, Color("#7f7771").lerp(Color("#c2a17c"), rng.randf()))
		placed += 1
	var rocks := MultiMeshInstance3D.new()
	rocks.name = "ScatteredRocks"
	rocks.multimesh = mesh_instances
	var rock_mat := StandardMaterial3D.new()
	rock_mat.albedo_color = Color.WHITE
	rock_mat.roughness = 1.0
	rocks.material_override = rock_mat
	scenery.add_child(rocks)
	# Small, recognizable geological accents, assembled from Godot's native primitives.
	for i in range(17):
		var p := Vector2(rng.randf_range(-55.0, 55.0), rng.randf_range(-55.0, 55.0))
		if p.length() < 8.0:
			continue
		var crystal := PrismMesh.new()
		crystal.size = Vector3(1.0, rng.randf_range(2.4, 5.0), 1.25)
		var part := Models.part(scenery, crystal, Color("#6c9f9b"), Vector3(p.x, surface_height(p.x, p.y) + crystal.size.y * 0.45, p.y))
		part.rotation.y = rng.randf_range(0, TAU)


func _build_pois() -> void:
	var group := Node3D.new()
	group.name = "SurfacePOIs"
	add_child(group)
	for i in range(POIS.size()):
		var data: Dictionary = POIS[i]
		var point: Vector2 = data.site
		var local := Node3D.new()
		local.name = data.kind
		local.position = Vector3(point.x, surface_height(point.x, point.y), point.y)
		group.add_child(local)
		poi_nodes.append(local)
		match data.kind:
			"spire": _signal_spire(local)
			"vault": _research_vault(local)
			"wreck": _survey_probe(local)
			"extractor": _extractor(local)
		_label(local, data.name, 12.2 if data.kind == "spire" else 7.3)


func _make_box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return Models.part(parent, mesh, color, at)


func _make_cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return Models.part(parent, mesh, color, at)


func _signal_spire(parent: Node3D) -> void:
	_make_cylinder(parent, 3.2, 0.7, Vector3(0, 0.35, 0), Color("#4f5766"))
	_make_cylinder(parent, 0.85, 9.3, Vector3(0, 5.2, 0), Color("#a6b7bd"))
	Models.ring(parent, 2.0, Color("#60d9e1"), Vector3(0, 9.2, 0))
	Models.beacon(parent, Vector3(0, 10.8, 0), Color("#69ecf4"), 0.5)
	_make_box(parent, Vector3(4.0, 0.55, 1.6), Vector3(2.8, 0.6, -2.1), Color("#495364"))


func _research_vault(parent: Node3D) -> void:
	_make_box(parent, Vector3(8.0, 1.0, 7.0), Vector3(0, 0.5, 0), Color("#464d5d"))
	_make_box(parent, Vector3(6.5, 3.8, 5.6), Vector3(0, 2.9, 0), Color("#7c8793"))
	_make_box(parent, Vector3(2.5, 2.7, 0.3), Vector3(0, 2.1, 2.94), Color("#52acc9"))
	Models.ring(parent, 2.3, Color("#64dbef"), Vector3(0, 5.1, 0))
	Models.beacon(parent, Vector3(-3, 4.9, 2.4), Color("#8ef5f6"), 0.35)


func _survey_probe(parent: Node3D) -> void:
	var fuselage := _make_box(parent, Vector3(6.0, 1.25, 2.7), Vector3(0, 1.2, 0), Color("#bc8667"))
	fuselage.rotation.y = -0.22
	var wing := _make_box(parent, Vector3(1.8, 0.35, 8.4), Vector3(-1.1, 1.1, 0), Color("#64727f"))
	wing.rotation.y = -0.26
	_make_box(parent, Vector3(2.1, 1.4, 1.8), Vector3(2.3, 1.35, 0.0), Color("#354e64"))
	Models.beacon(parent, Vector3(-3.5, 1.8, 0), Color("#ffb865"), 0.42)
	Models.ring(parent, 3.8, Color("#ce945d"), Vector3(0, 0.2, 0))


func _extractor(parent: Node3D) -> void:
	_make_box(parent, Vector3(9.5, 0.8, 7.0), Vector3(0, 0.4, 0), Color("#48525c"))
	for side in [-1.0, 1.0]:
		_make_cylinder(parent, 1.7, 6.5, Vector3(side * 2.5, 3.6, 0), Color("#a28b6e"))
		Models.beacon(parent, Vector3(side * 2.5, 7.0, 0), Color("#ffbd6b"), 0.35)
	_make_box(parent, Vector3(7.0, 0.5, 1.0), Vector3(0, 3.6, 0), Color("#7d99a2"))
	_make_box(parent, Vector3(3.0, 1.8, 2.4), Vector3(0, 1.3, 3.1), Color("#636e70"))


func _label(parent: Node3D, title: String, at_height: float) -> void:
	var label := Label3D.new()
	label.text = title
	label.name = "LocationLabel"
	label.position = Vector3(0, at_height, 0)
	label.font_size = 32
	label.pixel_size = 0.055
	label.outline_size = 9
	label.modulate = Color("#f5f2e8")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	parent.add_child(label)


func _build_ship() -> void:
	ship = Models.ship(PLAYER, false)
	ship.name = "PlayerShip"
	ship.position = Vector3(0, surface_height(0, 6) + FLY_HEIGHT, 6)
	ship.scale = Vector3.ONE * 1.2
	add_child(ship)
	destination = Vector2(0, 6)
	# Only for display. Do not change the shared ship scene or combat setup.


func _make_panel(parent: Control, right_side: bool, bottom: bool = false) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if right_side:
		panel.anchor_left = 1.0
		panel.anchor_right = 1.0
		panel.offset_left = -310.0
		panel.offset_right = -16.0
	else:
		panel.offset_left = 16.0
		panel.offset_right = 325.0
	if bottom:
		panel.anchor_top = 1.0
		panel.anchor_bottom = 1.0
		panel.offset_top = -90.0
		panel.offset_bottom = -16.0
	else:
		panel.offset_top = 16.0
		panel.offset_bottom = 0.0
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.045, 0.066, 0.10, 0.89)
	box_style.set_corner_radius_all(8)
	box_style.content_margin_left = 11
	box_style.content_margin_right = 11
	box_style.content_margin_top = 9
	box_style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", box_style)
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	return stack


func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "PreviewHUD"
	add_child(canvas)
	var ui := Control.new()
	ui.name = "FullScreenLayout"
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(ui)
	var info := _make_panel(ui, false)
	var heading := Label.new()
	heading.text = "PLANETARY EXPLORATION"
	heading.add_theme_font_size_override("font_size", 18)
	info.add_child(heading)
	var hint := Label.new()
	hint.text = "PROOF OF CONCEPT  •  NO ASSETS\nTap/click ground to fly\nMouse wheel or Zoom buttons to scale"
	info.add_child(hint)
	var controls := HBoxContainer.new()
	info.add_child(controls)
	for direction in [-1, 1]:
		var zoom_button := Button.new()
		zoom_button.text = "Zoom +" if direction < 0 else "Zoom −"
		zoom_button.pressed.connect(_zoom.bind(float(direction)))
		controls.add_child(zoom_button)
	var locations := _make_panel(ui, true)
	var title := Label.new()
	title.text = "SURFACE CONTACTS"
	title.add_theme_font_size_override("font_size", 17)
	locations.add_child(title)
	for i in range(POIS.size()):
		var button := Button.new()
		button.text = POIS[i].name.capitalize()
		button.pressed.connect(approach_poi.bind(i))
		locations.add_child(button)
	var footer := _make_panel(ui, false, true)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "Survey ship deployed. Select one of four structures, or fly freely."
	footer.add_child(status_label)


func _zoom(direction: float) -> void:
	_camera_size = clampf(_camera_size * (1.1 if direction > 0.0 else 0.9), CAMERA_MIN_SIZE, CAMERA_MAX_SIZE)


func _process(delta: float) -> void:
	if not is_instance_valid(ship):
		return
	var current := Vector2(ship.position.x, ship.position.z)
	if moving:
		var next := current.move_toward(destination, FLIGHT_SPEED * delta)
		var direction := (destination - current).normalized()
		ship.rotation.y = lerp_angle(ship.rotation.y, atan2(direction.x, direction.y), minf(1.0, delta * 5.0))
		ship.position = Vector3(next.x, surface_height(next.x, next.y) + FLY_HEIGHT, next.y)
		if next.distance_to(destination) <= ARRIVAL_DISTANCE:
			moving = false
			if destination_poi >= 0:
				var data: Dictionary = POIS[destination_poi]
				status_label.text = "%s — %s  (visual inspection only)" % [data.name, data.detail]
			else:
				status_label.text = "Survey position reached. Four structures are available to inspect."
	var target := ship.position
	var camera_at := target + Vector3(0, 68, 65)
	camera.global_position = camera.global_position.lerp(camera_at, 1.0 - exp(-5.0 * delta))
	camera.look_at(target, Vector3.UP)
	camera.size = lerpf(camera.size, _camera_size, 1.0 - exp(-8.0 * delta))


func approach_poi(index: int) -> void:
	if index < 0 or index >= POIS.size():
		return
	destination_poi = index
	var site: Vector2 = POIS[index].site
	destination = site + Vector2(3.8, 3.8)
	moving = true
	status_label.text = "Flying to %s..." % POIS[index].name


func _fly_to(screen: Vector2) -> void:
	var ray_start := camera.project_ray_origin(screen)
	var ray_end := ray_start + camera.project_ray_normal(screen) * 420.0
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var point: Vector3 = hit.position
	for i in range(POIS.size()):
		var site: Vector2 = POIS[i].site
		if Vector2(point.x, point.z).distance_to(site) < 6.5:
			approach_poi(i)
			return
	destination_poi = -1
	destination = Vector2(clampf(point.x, -60.0, 60.0), clampf(point.z, -60.0, 60.0))
	moving = true
	status_label.text = "Moving across the planetary surface..."


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_fly_to(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_active = true
			_touch_dragged = false
			_touch_origin = event.position
		elif _touch_active:
			if not _touch_dragged:
				_fly_to(event.position)
			_touch_active = false
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _touch_active:
		if event.position.distance_to(_touch_origin) > 16.0:
			_touch_dragged = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
