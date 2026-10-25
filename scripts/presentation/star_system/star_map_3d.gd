extends Control
# Owns destination models, projected input and ship choreography; receives all run data.
signal arrived(index: int)
signal interrupted
signal travel_started
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const Camera = preload("res://scripts/presentation/star_system/map_camera.gd")
const VisualSystem = preload("res://scripts/presentation/star_system/visual_system.gd")
const Planets = preload("res://scripts/presentation/star_system/planet_models.gd")
const Space = preload("res://scripts/presentation/star_system/space_environment.gd")
var run_seed: int = 0
var system_number: int = 1
var visual_data: Dictionary = {}
var visual_root: Node3D
var destination_root: Node3D
var background: Node3D
var planet_nodes: Dictionary = {}
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
	environment.environment.ambient_light_energy = settings.ambient_light_energy
	world.add_child(environment)
	var light := OmniLight3D.new()
	light.name = "SunLight"
	light.light_color = Color(1.0,0.88,0.70)
	light.light_energy = settings.sunlight_energy
	light.omni_range = settings.sunlight_range
	light.omni_attenuation = 0.35
	light.shadow_enabled = false
	world.add_child(light)


func configure(entries: Array, last_destination: int, duration: float, visual_seed: int = 0) -> void:
	if is_instance_valid(ship) and configured_seed == visual_seed:
		for entry in entries:
			if markers.has(entry.index):
				markers[entry.index].disabled = entry.completed
				markers[entry.index].set_label(_marker_text(entry),_marker_icon(entry),visual_data.assignments.has(entry.index))
		overview()
		return
	if motion and motion.is_valid():
		motion.kill()
	traveling = false
	configured_seed = visual_seed
	travel_duration = duration
	var cosmetic_seed: int = run_seed if run_seed != 0 else visual_seed
	visual_data = VisualSystem.generate(cosmetic_seed, system_number, entries, settings)
	for layer in [visual_root,destination_root,background]:
		if is_instance_valid(layer):
			world.remove_child(layer)
			layer.queue_free()
	for button in markers.values(): button.queue_free()
	objects.clear()
	markers.clear()
	planet_nodes.clear()
	visual_root = Node3D.new()
	visual_root.name = "GeneratedSystem"
	world.add_child(visual_root)
	destination_root = Node3D.new()
	destination_root.name = "EncounterRepresentations"
	world.add_child(destination_root)
	background = Space.new()
	background.name = "BackgroundEnvironment"
	world.add_child(background)
	camera.overview(settings, true)
	background.configure(camera,settings,VisualSystem.random_for(cosmetic_seed,system_number,"background"),VisualSystem.random_for(cosmetic_seed,system_number,"stardust"))
	for p in visual_data.planets:
		visual_root.add_child(Planets.orbit(p,settings))
		var planet: Node3D = Planets.build(p,settings)
		planet.position = p.position
		visual_root.add_child(planet)
		planet_nodes[p.index] = planet
		if p.encounter != -1: objects[p.encounter] = planet
		var label = Label3D.new()
		label.text = p.name
		label.position.y = p.radius+0.4/1.5
		label.scale = Vector3.ONE/1.5
		label.font_size = 18
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.65,0.78,0.9,0.8)
		label.visible = p.encounter == -1
		planet.add_child(label)
	var sun := QuadMesh.new()
	sun.size = Vector2(18, 18)
	var disc := Models.part(visual_root, sun, Color.WHITE)
	disc.name = "Sun"
	# Billboard vertices rotate outside the original flat quad bounds.
	disc.custom_aabb = AABB(Vector3.ONE*-9.0,Vector3.ONE*18.0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/menu_sun.gdshader")
	material.set_shader_parameter("sun_color", visual_data.star_color)
	material.set_shader_parameter("core_scale",settings.sun_core_scale)
	material.render_priority = 10
	disc.material_override = material
	objects[-100] = disc
	for entry in entries:
		var index: int = entry.index
		if not objects.has(index):
			var model := Models.build(entry, VisualSystem.random_for(cosmetic_seed,system_number,"model-%d" % index), settings.destination_scenes.get(entry.get("model_kind","")))
			var phenomenon: bool = entry.get("profile") == null and entry.get("model_kind", "") in ["radiation_nebula", "spatial_anomaly", "unstable_wormhole", "gas_giant"]
			var size_factor: float = 1.5 if phenomenon else 0.5
			model.scale *= size_factor
			if model.has_meta("radius"):
				model.set_meta("radius", float(model.get_meta("radius"))*size_factor)
			model.position = visual_data.anchors[index]
			destination_root.add_child(model)
			objects[index] = model
		var button := preload("res://scripts/presentation/star_system/poi_marker.gd").new()
		button.tooltip_text = entry.tooltip
		button.flat = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.style_tag(entry.color)
		button.set_label(_marker_text(entry),_marker_icon(entry),visual_data.assignments.has(index))
		button.disabled = entry.completed
		preload("res://scripts/audio/sfx.gd").bind_ui(button)
		button.pressed.connect(travel.bind(index))
		add_child(button)
		markers[index] = button
	if is_instance_valid(ship):
		ship.queue_free()
	ship = Models.ship(player_profile)
	ship.scale = Vector3.ONE * 0.175
	world.add_child(ship)
	ship.position = _initial_ship_position()
	orbit_index = last_destination if objects.has(last_destination) else -1
	if orbit_index != -1:
		ship.position = objects[orbit_index].position + Vector3(_orbit_radius(orbit_index), 0, 0)
	focused = false
	interactive = true


func _process(delta: float) -> void:
	if not is_instance_valid(ship):
		return
	for p in visual_data.get("planets",[]):
		planet_nodes[p.index].get_node("Surface").rotate_y(delta*p.rotation_speed)
	if traveling and travel_direction.length_squared() > 0.0:
		_face(travel_direction, delta * 7.0)
	if orbit_index != -1 and not traveling:
		orbit_angle += delta * settings.orbit_speed
		var center: Vector3 = objects[orbit_index].position
		var next: Vector3 = center + Vector3(cos(orbit_angle), 0.15, sin(orbit_angle)) * _orbit_radius(orbit_index)
		_face(next - ship.position, delta * 5)
		ship.position = next
	for index in markers:
		var button = markers[index]
		var point: Vector3 = objects[index].position
		var center: Vector2 = camera.unproject_position(point)
		button.visible = not focused and not camera.is_position_behind(point)
		button.mouse_filter = MOUSE_FILTER_STOP if interactive and not traveling and not pinching and Time.get_ticks_msec() >= gesture_block_until else MOUSE_FILTER_IGNORE
		var top: Vector2 = camera.unproject_position(point+Vector3.UP*float(objects[index].get_meta("radius",0.65)))
		button.position = top+Vector2(settings.label_offset.x,-absf(settings.label_offset.y))-Vector2(button.size.x*0.5,button.size.y)
		button.anchor_point = center-button.position
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
	var destination: Vector3 = objects[index].position + Vector3(_orbit_radius(index), 0.15, 0)
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
	camera.focus(objects[index].position, settings, float(objects[index].get_meta("radius", 0.0)))


func overview() -> void:
	if motion and motion.is_valid():
		motion.kill()
	traveling = false
	focused = false
	interactive = true
	camera.overview(settings)


func set_active(active: bool) -> void:
	if is_instance_valid(background): background.set_active(active)
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


func _orbit_radius(index: int) -> float:
	return maxf(settings.orbit_radius,float(objects[index].get_meta("radius",0.0))+1.0)

func _marker_text(entry: Dictionary) -> String:
	if visual_data.get("assignments",{}).has(entry.index):
		return visual_data.planets[visual_data.assignments[entry.index]].name
	return entry.get("name",entry.text)

func _marker_icon(entry: Dictionary) -> String:
	if entry.get("profile") != null: return "⚔"
	return {"mining_operation":"⚒","research_station":"⌬","quarantined_colony":"☣","gas_giant":"◉","trading_outpost":"⚙","derelict_starship":"▱","pirate_debris_field":"⚔","spatial_anomaly":"◇","unstable_wormhole":"◎","radiation_nebula":"✦","distress_signal":"⚑"}.get(entry.get("model_kind",""),"◇")

func _initial_ship_position() -> Vector3:
	for at in [Vector3(0,0,3),Vector3(-3,0,0),Vector3(3,0,0),Vector3(0,0,-3),Vector3(-2,0,2),Vector3(2,0,-2)]:
		if visual_data.planets.all(func(p): return at.distance_to(p.position)>p.radius*1.5+1.25):
			return at
	return Vector3(0,1.5,3)
