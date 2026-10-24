extends Control
# Owns destination models, projected input and ship choreography; receives all run data.
signal arrived(index: int)
signal interrupted
signal travel_started
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const Camera = preload("res://scripts/presentation/star_system/map_camera.gd")
const POINTS = [
	Vector3(-10, 0, -8), Vector3(0, 0, -11), Vector3(10, 0, -8),
	Vector3(-10, 0, 7), Vector3(0, 0, 10), Vector3(10, 0, 7)
]
@export var settings: Resource = preload("res://resources/presentation/star_system_settings.tres")
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var ship: Node3D
var objects: Dictionary = {}
var markers: Dictionary = {}
var input_allowed: Callable
var before_travel: Callable
var intercept_travel: Callable
var traveling := false
var travel_duration := 1.4
var motion: Tween
var impact_motion: Tween
var impact_layer: CanvasLayer
var orbit_index := -1
var orbit_angle := 0.0
var focused := false
var interactive := true
var player_profile: Resource
var configured_seed := 0
var travel_direction := Vector3.ZERO
var touches: Dictionary = {}
var pinch_distance: float = 0.0
var pinching: bool = false
var gesture_block_until: int = 0
var pinch_disabled: Dictionary = {}
var drag_origin := Vector2.ZERO
var mouse_down: bool = false
var dragging: bool = false


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
	camera.process_priority = -1
	camera.fov = settings.field_of_view
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
		var relative := Vector2(model.position.x / 32.0 + 0.5, model.position.z / 24.0 + 0.5)
		var bounded: Vector2 = settings.system_bounds.position + relative.clamp(Vector2.ZERO, Vector2.ONE) * settings.system_bounds.size
		model.position = Vector3(bounded.x, 0, bounded.y)
		model.rotate_y(rng.randf_range(-0.25, 0.25))
		world.add_child(model)
		objects[index] = model
		var button := preload("res://scripts/presentation/star_system/poi_marker.gd").new()
		button.text = ("✓ " if entry.completed else "") + entry.get("name", entry.text)
		button.tooltip_text = entry.tooltip
		button.flat = true
		button.custom_minimum_size = Vector2(132, 64)
		button.size = Vector2(140, 64)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.style_tag(entry.color)
		button.disabled = entry.completed
		preload("res://scripts/audio/sfx.gd").bind_ui(button)
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
	if traveling and travel_direction.length_squared() > 0.0:
		_face(travel_direction, delta * 7.0)
	if orbit_index != -1 and not traveling:
		orbit_angle += delta * settings.orbit_speed
		var center: Vector3 = objects[orbit_index].position
		var next: Vector3 = center + Vector3(cos(orbit_angle), 0.15, sin(orbit_angle)) * settings.orbit_radius
		_face(next - ship.position, delta * 5)
		ship.position = next
	for index in markers:
		var button: Button = markers[index]
		var point: Vector3 = objects[index].position
		var center: Vector2 = camera.unproject_position(point)
		button.visible = (
			not focused and not camera.is_position_behind(point)
			and Rect2(Vector2.ZERO, size).has_point(center)
			and not (camera.motion != null and camera.motion.is_running())
		)
		button.mouse_filter = MOUSE_FILTER_STOP if interactive and not traveling and not pinching and Time.get_ticks_msec() >= gesture_block_until else MOUSE_FILTER_IGNORE
		var projected: Vector2 = center - button.size * 0.5 + settings.label_offset
		var border: float = settings.screen_border
		var limit: Vector2 = (size - button.size - Vector2.ONE * border).max(Vector2.ONE * border)
		button.position = projected.clamp(Vector2.ONE * border, limit)
		if Rect2(button.position, button.size).has_point(center):
			# At the lower screen edge, put the tag above the model rather than over it.
			button.position.y = clampf(center.y - absf(settings.label_offset.y) - button.size.y * 0.5, border, limit.y)
		button.anchor_point = center - button.position
		button.queue_redraw()


func _face(direction: Vector3, weight: float = 1.0) -> void:
	if direction.length_squared() < 0.00001:
		return
	var forward := direction.normalized()
	var bank: float = 0.0
	if traveling:
		bank = clampf(ship.basis.x.signed_angle_to(forward, Vector3.UP) * 0.18, -0.16, 0.16)
	var basis_to: Basis = _facing_basis(direction, bank)
	ship.quaternion = ship.quaternion.slerp(basis_to.get_rotation_quaternion(), clampf(weight, 0, 1))


func _facing_basis(direction: Vector3, bank: float = 0.0) -> Basis:
	var forward := direction.normalized()
	var side := forward.cross(Vector3.UP).normalized()
	return Basis(forward, side.cross(forward), side) * Basis(Vector3.RIGHT, bank)


func travel(index: int) -> void:
	if traveling or not interactive or pinching or Time.get_ticks_msec() < gesture_block_until or not markers.has(index) or markers[index].disabled:
		return
	if before_travel.is_valid() and not before_travel.call(index):
		return
	var intercepted: bool = intercept_travel.is_valid() and intercept_travel.call(index)
	traveling = true
	travel_started.emit()
	orbit_index = -1
	var origin := ship.position
	var destination: Vector3 = objects[index].position + Vector3(settings.orbit_radius, 0.15, 0)
	travel_direction = destination - origin
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
	_clear_impact()
	var layer := CanvasLayer.new()
	impact_layer = layer
	layer.layer = 100
	add_child(layer)
	var flash := ColorRect.new()
	flash.color = Color(1, 0, 0, 0)
	flash.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	flash.mouse_filter = MOUSE_FILTER_STOP
	layer.add_child(flash)
	var effect := create_tween()
	impact_motion = effect
	effect.tween_method(func(progress: float):
		# Retain the existing interception's two red pulses and decaying impact shake.
		var first: float = maxf(0.0, 1.0 - absf(progress - 0.06) / 0.06)
		var second: float = maxf(0.0, 1.0 - absf(progress - 0.24) / 0.06)
		flash.color.a = 0.35 * maxf(first, second)
		camera.h_offset = sin(progress * 93.0) * 0.12 * (1.0 - progress)
		camera.v_offset = sin(progress * 127.0) * 0.12 * (1.0 - progress)
	, 0.0, 1.0, 1.0)
	effect.tween_callback(_clear_impact)


func focus(index: int) -> void:
	if not objects.has(index):
		return
	_end_pinch()
	focused = true
	interactive = false
	camera.focus(objects[index].position, settings)


func overview() -> void:
	if motion and motion.is_valid():
		motion.kill()
	traveling = false
	focused = false
	interactive = true
	camera.overview(settings)


func set_active(active: bool) -> void:
	if not active:
		_end_pinch()
	visible = active
	set_process(active)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED


func depart() -> void:
	traveling = true
	orbit_index = -1
	var flyby: Vector3 = camera.position + camera.basis.x * settings.departure_side_offset
	var direction: Vector3 = (flyby - ship.position).normalized()
	travel_direction = direction
	motion = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var end: Vector3 = ship.position + direction * settings.departure_speed * settings.departure_duration
	motion.tween_property(ship, "position", end, settings.departure_duration)


func _zoom_enabled() -> bool:
	return (
		is_visible_in_tree() and interactive and not focused
		and camera.viewing == &"overview" and not (camera.motion and camera.motion.is_running())
		and (not input_allowed.is_valid() or input_allowed.call())
	)


func _unhandled_input(event: InputEvent) -> void:
	if not _zoom_enabled():
		return
	if event is InputEventMouseButton and event.pressed and get_global_rect().has_point(event.position):
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step: float = 1.0 + settings.wheel_zoom_step
			camera.zoom_by(step if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / step)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture and get_global_rect().has_point(event.position):
		camera.zoom_by(event.factor)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _zoom_enabled():
		_end_pinch()
		return
	if event is InputEventScreenTouch:
		if event.pressed and get_global_rect().has_point(event.position):
			if touches.is_empty():
				drag_origin = event.position
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
		if touches.size() == 2 and not pinching:
			pinching = true
			pinch_distance = _touch_distance()
			_block_markers()
		if pinching or dragging:
			gesture_block_until = Time.get_ticks_msec() + 180
			get_viewport().set_input_as_handled()
			if touches.is_empty():
				_end_pinch()
	elif event is InputEventScreenDrag and touches.has(event.index):
		var previous: Vector2 = touches[event.index]
		touches[event.index] = event.position
		if pinching:
			var distance: float = _touch_distance()
			if distance > 1.0 and pinch_distance > 1.0:
				camera.zoom_by(distance / pinch_distance)
			pinch_distance = distance
			get_viewport().set_input_as_handled()
		elif touches.size() == 1:
			_drag_map(previous, event.position)
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and get_global_rect().has_point(event.position):
			mouse_down = true
			drag_origin = event.position
		elif not event.pressed:
			mouse_down = false
			if dragging:
				get_viewport().set_input_as_handled()
				_end_pinch()
	elif event is InputEventMouseMotion and event.device != -1 and mouse_down:
		_drag_map(event.position - event.relative, event.position)


func _drag_map(previous: Vector2, current: Vector2) -> void:
	if not dragging and current.distance_to(drag_origin) < settings.pan_drag_threshold:
		return
	if not dragging:
		dragging = true
		_block_markers()
		previous = drag_origin
	camera.pan_screen(previous - global_position, current - global_position)
	gesture_block_until = Time.get_ticks_msec() + 180
	get_viewport().set_input_as_handled()


func _block_markers() -> void:
	for index in markers:
		if not pinch_disabled.has(index):
			pinch_disabled[index] = markers[index].disabled
		markers[index].disabled = true


func _touch_distance() -> float:
	var points: Array = touches.values()
	return points[0].distance_to(points[1]) if points.size() == 2 else 0.0


func _end_pinch() -> void:
	for index in pinch_disabled:
		if markers.has(index):
			markers[index].disabled = pinch_disabled[index]
	pinch_disabled.clear()
	touches.clear()
	pinching = false
	dragging = false
	mouse_down = false
	pinch_distance = 0.0


# Cinematic execution stays with the map/camera; the controller owns legality/checkpoints.
func battle_entry(curtain: CanvasLayer) -> bool:
	curtain.block()
	interactive = false
	traveling = true
	camera.close_ship(ship.position, settings.battle_zoom_duration, &"battle")
	if not await curtain.pause(maxf(0.0, settings.battle_zoom_duration - settings.white_fade_duration)):
		return false
	return await curtain.fade(1.0, settings.white_fade_duration)


func ftl_departure(curtain: CanvasLayer) -> bool:
	curtain.block()
	interactive = false
	traveling = true
	orbit_index = -1
	travel_direction = Vector3.ZERO
	var view: Transform3D = camera.ship_view(ship.position)
	var facing: Quaternion = _facing_basis(view.origin + view.basis.x * settings.departure_side_offset - ship.position).get_rotation_quaternion()
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(ship, "quaternion", facing, settings.departure_turn_duration)
	if not await curtain.pause(settings.departure_turn_duration):
		return false
	ship.quaternion = facing
	camera.close_ship(ship.position, settings.camera_duration, &"ftl")
	if not await curtain.pause(settings.camera_duration + 0.15):
		return false
	depart()
	if not await curtain.pause(maxf(0.0, settings.departure_duration - settings.white_fade_duration)):
		return false
	return await curtain.fade(1.0, settings.white_fade_duration)


func cancel_presentation() -> void:
	if motion and motion.is_valid():
		motion.kill()
	if is_instance_valid(camera):
		camera.cancel()
	_clear_impact()
	traveling = false
	travel_direction = Vector3.ZERO
	_end_pinch()


func _clear_impact() -> void:
	if impact_motion and impact_motion.is_valid():
		impact_motion.kill()
	if is_instance_valid(impact_layer):
		impact_layer.queue_free()
	impact_layer = null
	if is_instance_valid(camera):
		camera.h_offset = 0
		camera.v_offset = 0


func _exit_tree() -> void:
	cancel_presentation()
