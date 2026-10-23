extends Control
# Owns destination models, projected input and ship choreography; receives all run data.
signal arrived(index: int)
signal interrupted
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const Camera = preload("res://scripts/presentation/star_system/map_camera.gd")
const POINTS = [Vector3(-10, 0, -8), Vector3(0, 0, -11), Vector3(10, 0, -8), Vector3(-10, 0, 7), Vector3(0, 0, 10), Vector3(10, 0, 7)]
@export var settings: Resource = preload("res://scripts/presentation/star_system/map_settings.gd").new()
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var ship: Node3D
var objects: Dictionary = {}
var markers: Dictionary = {}
var before_travel: Callable
var intercept_travel: Callable
var traveling := false
var travel_duration := 1.4
var motion: Tween
var orbit_index := -1
var orbit_angle := 0.0
var focused := false
var interactive := true
var player_profile: Resource
var configured_seed := 0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	camera = Camera.new()
	camera.fov = 48
	camera.far = 220
	world.add_child(camera)
	camera.overview(settings, true)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("020611")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("92afcf")
	environment.environment.ambient_light_energy = 0.75
	world.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -25, 0)
	light.light_energy = 1.6
	world.add_child(light)
	var sky := SphereMesh.new()
	sky.radius = 150
	sky.height = 300
	sky.radial_segments = 24
	sky.rings = 12
	var space := Models.part(world, sky, Color.WHITE)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/space_background.gdshader")
	material.set_shader_parameter("star_density", 0.20)
	material.set_shader_parameter("cloud_intensity", 0.25)
	space.material_override = material

func configure(entries: Array, last_destination: int, duration: float, visual_seed: int = 0) -> void:
	if is_instance_valid(ship) and configured_seed == visual_seed:
		for entry in entries:
			if markers.has(entry.index):
				markers[entry.index].disabled = entry.completed
				markers[entry.index].text = ("✓ " if entry.completed else "") + entry.get("name", entry.text)
		overview()
		return
	if motion and motion.is_valid():
		motion.kill()
	traveling = false
	configured_seed = visual_seed
	travel_duration = duration
	var rng := RandomNumberGenerator.new()
	rng.seed = visual_seed
	for node in objects.values():
		node.queue_free()
	for button in markers.values():
		button.queue_free()
	objects.clear()
	markers.clear()
	var sun := QuadMesh.new()
	sun.size = Vector2(12, 12)
	var disc := Models.part(world, sun, Color.WHITE)
	disc.name = "Sun"
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/menu_sun.gdshader")
	material.set_shader_parameter("sun_color", Color.from_hsv(rng.randf_range(0.02, 0.16), 0.5, 1.0))
	disc.material_override = material
	objects[-100] = disc
	for entry in entries:
		var index: int = entry.index
		var model := Models.build(entry, rng)
		model.position = POINTS[index] if index >= 0 and index < POINTS.size() else Vector3(15, 0, 0)
		model.position += Vector3(rng.randf_range(-0.5, 0.5), 0, rng.randf_range(-0.5, 0.5))
		model.rotate_y(rng.randf_range(-0.25, 0.25))
		world.add_child(model)
		objects[index] = model
		var button := Button.new()
		button.text = ("✓ " if entry.completed else "") + entry.get("name", entry.text)
		button.tooltip_text = entry.tooltip
		button.flat = true
		button.custom_minimum_size = Vector2(132, 64)
		button.size = Vector2(160, 64)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_override("font", preload("res://assets/fonts/emoji_ui.tres"))
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", entry.color.lightened(0.3))
		button.add_theme_color_override("font_outline_color", Color("020611"))
		button.add_theme_constant_override("outline_size", 5)
		button.disabled = entry.completed
		button.pressed.connect(travel.bind(index))
		add_child(button)
		markers[index] = button
	if is_instance_valid(ship):
		ship.queue_free()
	ship = Models.ship(player_profile)
	ship.scale = Vector3.ONE * 0.35
	world.add_child(ship)
	ship.position = Vector3(0, 0, 3)
	orbit_index = last_destination if objects.has(last_destination) else -1
	if orbit_index != -1:
		ship.position = objects[orbit_index].position + Vector3(settings.orbit_radius, 0, 0)
	camera.overview(settings, true)
	focused = false
	interactive = true

func _process(delta: float) -> void:
	if not is_instance_valid(ship):
		return
	if orbit_index != -1 and not traveling:
		orbit_angle += delta * settings.orbit_speed
		var center: Vector3 = objects[orbit_index].position
		var next: Vector3 = center + Vector3(cos(orbit_angle), 0.15, sin(orbit_angle)) * settings.orbit_radius
		_face(next - ship.position, delta * 5)
		ship.position = next
	for index in markers:
		var button: Button = markers[index]
		var point: Vector3 = objects[index].position
		button.visible = not focused and not camera.is_position_behind(point)
		button.mouse_filter = MOUSE_FILTER_STOP if interactive and not traveling else MOUSE_FILTER_IGNORE
		button.position = camera.unproject_position(point) - button.size * 0.5 + Vector2(0, 28)

func _face(direction: Vector3, weight: float = 1.0) -> void:
	if direction.length_squared() < 0.00001:
		return
	var forward := direction.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	var basis_to := Basis(forward, side.cross(forward), side)
	ship.quaternion = ship.quaternion.slerp(basis_to.get_rotation_quaternion(), clampf(weight, 0, 1))

func travel(index: int) -> void:
	if traveling or not interactive or not markers.has(index) or markers[index].disabled:
		return
	if before_travel.is_valid() and not before_travel.call(index):
		return
	var intercepted: bool = intercept_travel.is_valid() and intercept_travel.call(index)
	traveling = true
	orbit_index = -1
	var origin := ship.position
	var destination: Vector3 = objects[index].position + Vector3(settings.orbit_radius, 0.15, 0)
	_face(destination - origin)
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if intercepted:
		# Same stop time as the existing map. Never emit the original arrival.
		var fraction := minf(0.5 / maxf(travel_duration, 0.6), 0.8)
		motion.tween_property(ship, "position", origin.lerp(destination, fraction), 0.5)
		motion.tween_callback(_impact)
		motion.tween_interval(1.0)
		motion.tween_callback(func(): traveling = false; interrupted.emit())
	else:
		motion.tween_property(ship, "position", destination, travel_duration)
		motion.tween_callback(func():
			traveling = false
			orbit_index = index
			orbit_angle = 0.0
			arrived.emit(index))

func _impact() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 0.12, 0.08, 0.35)
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(flash)
	var effect := create_tween()
	effect.tween_property(flash, "color:a", 0.0, 1.0)
	effect.tween_callback(flash.queue_free)

func focus(index: int) -> void:
	if not objects.has(index):
		return
	focused = true
	interactive = false
	camera.focus(objects[index].position, settings)

func overview() -> void:
	focused = false
	interactive = true
	camera.overview(settings)

func set_active(active: bool) -> void:
	visible = active
	set_process(active)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
