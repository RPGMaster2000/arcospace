extends Control
# Owns destination models, projected input and ship choreography; receives all run data.
signal arrived(index: int)
signal interrupted
signal travel_started
signal inspect_requested(index: int)
signal inspection_dismissed
signal free_move_requested(point: Vector3)
signal free_arrived
const Models = preload("res://scripts/presentation/star_system/destination_models.gd")
const Camera = preload("res://scripts/presentation/star_system/map_camera.gd")
const VisualSystem = preload("res://scripts/presentation/star_system/visual_system.gd")
const Planets = preload("res://scripts/presentation/star_system/planet_models.gd")
const Space = preload("res://scripts/presentation/star_system/space_environment.gd")
const SunLensEffects = preload("res://scripts/presentation/star_system/sun_lens_effects.gd")
var sun_lens = SunLensEffects.new()
var run_seed: int = 0
var system_number: int = 1
var system_profile: String = "industrial"
var visual_data: Dictionary = {}
var visual_root: Node3D
var destination_root: Node3D
var background: Node3D
var planet_nodes: Dictionary = {}
var orbit_nodes: Dictionary = {}
@export var settings: Resource = preload("res://resources/presentation/star_system_settings.tres")
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var hud_regions: Array[Rect2] = []
var external_zoom_controls := false
var introducing := false
var zoom_controls: HBoxContainer
var feedback: Node3D
var ship: Node3D
var objects: Dictionary = {}
var markers: Dictionary = {}
var input_allowed: Callable
var inspection_active: bool = false
var inspection_area: Callable
var hold_index: int = -1
var hold_started: int = 0
var hold_fired: bool = false
enum Gesture { IDLE, PRESS, HOLD, DRAG, PINCH, CONSUMED }
var gesture: Gesture = Gesture.IDLE
var selected_touch_index: int = -1
var last_touch_msec: int = 0
var double_tap_msec: int = 350
var touch_confirmation_required: bool = false
var hold_threshold_msec: int = 400
const MOTHERSHIP_MODEL_SCALE: float = 2.5
var destination_for: Callable
var before_travel: Callable
var intercept_travel: Callable
var before_free_travel: Callable
var intercept_free_travel: Callable
var interception_pending := false
var traveling := false
var travel_duration := 1.4
var defense_view: Dictionary = {}
var physical_speed: float = 0.0
var defense_effects: Node3D
var motion: Tween
var impact_motion: Tween
var impact_layer: CanvasLayer
var selected_index := -1
var orbit_index := -1
var orbit_angle := 0.0
var focused := false
var tactical_snapshot: Dictionary = {}
var tactical_enemy: Node3D
var tactical_temporary := false
var tactical_light: OmniLight3D
var focus_orbit_enabled := false
var orbit_pointer := -2
var orbit_velocity := Vector2.ZERO
var focus_target := Vector3.ZERO
var focus_offset := Vector3.ZERO
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
	clip_contents = true
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(container)
	viewport = SubViewport.new()
	viewport.size = Vector2i(size.max(Vector2.ONE))
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
	sun_lens.attach(environment)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): sun_lens.disable())
	var light := OmniLight3D.new()
	light.name = "SunLight"
	light.light_color = Color(1.0,0.88,0.70)
	light.light_energy = settings.sunlight_energy
	light.omni_range = settings.sunlight_range
	light.omni_attenuation = 0.35
	light.shadow_enabled = false
	world.add_child(light)
	zoom_controls = HBoxContainer.new()
	zoom_controls.set_anchors_and_offsets_preset(PRESET_BOTTOM_RIGHT)
	zoom_controls.grow_horizontal = GROW_DIRECTION_BEGIN
	zoom_controls.grow_vertical = GROW_DIRECTION_BEGIN
	zoom_controls.offset_left = -112
	zoom_controls.offset_top = -68
	zoom_controls.offset_right = -8
	zoom_controls.offset_bottom = -8
	zoom_controls.z_index = 50
	zoom_controls.add_theme_constant_override("separation",8)
	add_child(zoom_controls)
	for closer in [false,true]:
		var button := Button.new()
		button.text = "+" if closer else "−"
		button.tooltip_text = "Zoom in" if closer else "Zoom out"
		button.custom_minimum_size = Vector2(48,48)
		button.add_theme_font_size_override("font_size",26)
		preload("res://scripts/ui/encounter_presentation.gd").action(button)
		button.pressed.connect(func():
			if _zoom_enabled(): camera.zoom_by(1.15 if closer else 1.0/1.15))
		zoom_controls.add_child(button)


func configure(entries: Array, last_destination: int, duration: float, visual_seed: int = 0) -> void:
	if is_instance_valid(ship) and configured_seed == visual_seed:
		for entry in entries:
			if markers.has(entry.index):
				markers[entry.index].disabled = entry.completed
				markers[entry.index].set_state(entry.completed,false,false)
				markers[entry.index].set_label(_marker_text(entry),_marker_icon(entry),visual_data.assignments.has(entry.index) or entry.get("profile") != null)
				markers[entry.index].set_objective(entry.get("objective_marker",""))
		if not defense_view.is_empty(): sync_defense(defense_view)
		overview()
		return
	if motion and motion.is_valid():
		motion.kill()
	traveling = false
	selected_index = -1
	configured_seed = visual_seed
	travel_duration = duration
	var cosmetic_seed: int = run_seed if run_seed != 0 else visual_seed
	visual_data = VisualSystem.generate(cosmetic_seed, system_number, entries, settings, system_profile)
	if not defense_view.is_empty():
		preload("res://scripts/presentation/star_system/defense_presentation.gd").layout(visual_data, defense_view)
	for layer in [visual_root,destination_root,background]:
		if is_instance_valid(layer):
			world.remove_child(layer)
			layer.queue_free()
	for button in markers.values(): button.queue_free()
	objects.clear()
	markers.clear()
	planet_nodes.clear()
	orbit_nodes.clear()
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
	background.configure(camera,settings,VisualSystem.random_for(cosmetic_seed,system_number,"background"),VisualSystem.random_for(cosmetic_seed,system_number,"stardust"),visual_data.atmosphere_strength)
	for p in visual_data.planets:
		var orbit: MeshInstance3D = Planets.orbit(p,settings)
		visual_root.add_child(orbit)
		orbit_nodes[p.index] = orbit
		var planet: Node3D = Planets.build(p,settings)
		planet.position = p.position
		visual_root.add_child(planet)
		planet_nodes[p.index] = planet
		if p.encounter != -1: objects[p.encounter] = planet
		var label = Label3D.new()
		label.text = p.name
		label.position.y = p.radius+0.4/1.5
		label.scale = Vector3.ONE/1.5
		label.font_size = 24
		label.pixel_size = 0.012
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(0.65,0.78,0.9,0.8)
		label.name = "OverviewName"
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
			if entry.get("mothership", false): size_factor *= MOTHERSHIP_MODEL_SCALE
			model.scale *= size_factor
			if model.has_meta("radius"):
				model.set_meta("radius", float(model.get_meta("radius"))*size_factor)
			if not model.has_meta("radius"):
				model.set_meta("radius",visual_data.placement[index].radius * (MOTHERSHIP_MODEL_SCALE if entry.get("mothership", false) else 1.0))
			model.position = visual_data.anchors[index]
			destination_root.add_child(model)
			objects[index] = model
		var button := preload("res://scripts/presentation/star_system/poi_marker.gd").new()
		button.tooltip_text = entry.tooltip
		button.flat = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.contrast = not defense_view.is_empty() and entry.get("profile") != null
		button.style_tag(entry.color)
		button.set_label(_marker_text(entry),_marker_icon(entry),visual_data.assignments.has(index) or entry.get("profile") != null)
		button.set_objective(entry.get("objective_marker",""))
		button.hit_allowed = func(point): return not point_is_reserved(point)
		button.nearest_hit = func(point): return nearest_marker(point) == index
		button.disabled = entry.completed
		button.set_state(entry.completed,false,false)
		preload("res://scripts/audio/sfx.gd").bind_ui(button)
		button.pressed.connect(travel.bind(index))
		add_child(button)
		markers[index] = button
	if is_instance_valid(ship):
		ship.queue_free()
	ship = Models.ship(player_profile)
	ship.scale = Vector3.ONE * 0.175
	world.add_child(ship)
	if is_instance_valid(feedback): feedback.queue_free()
	feedback = preload("res://scripts/presentation/star_system/map_feedback.gd").new()
	feedback.canvas = self
	feedback.camera = camera
	feedback.ship = ship
	world.add_child(feedback)
	ship.position = _initial_ship_position() if defense_view.is_empty() else _defense_point(defense_view.start)
	orbit_index = last_destination if objects.has(last_destination) else -1
	if orbit_index != -1:
		ship.position = objects[orbit_index].position + Vector3(_orbit_radius(orbit_index), 0, 0)
	if not defense_view.is_empty():
		if is_instance_valid(defense_effects):
			world.remove_child(defense_effects)
			defense_effects.queue_free()
		defense_effects = preload("res://scripts/presentation/star_system/defense_presentation.gd").new()
		world.add_child(defense_effects)
		defense_effects.configure(self)
		sync_defense(defense_view)
	focused = false
	interactive = true


func _process(delta: float) -> void:
	if gesture == Gesture.PRESS and hold_index >= 0 and not hold_fired and Time.get_ticks_msec() - hold_started >= hold_threshold_msec:
		hold_fired = true
		gesture = Gesture.HOLD
		inspect_requested.emit(hold_index)
	if not defense_view.is_empty() and interactive and traveling and motion and motion.is_valid():
		if input_allowed.is_valid() and not input_allowed.call(): motion.pause()
		elif not motion.is_running(): motion.play()
	if focus_orbit_enabled and camera.viewing == &"destination" and not (camera.motion and camera.motion.is_running()):
		if orbit_velocity.length_squared() > 0.000001:
			var offset: Vector3 = focus_offset
			offset = offset.rotated(Vector3.UP,orbit_velocity.x*delta)
			var axis: Vector3 = offset.cross(Vector3.UP).normalized()
			var pitched: Vector3 = offset.rotated(axis,orbit_velocity.y*delta)
			if pitched.normalized().y > 0.12 and pitched.normalized().y < 0.85: offset = pitched
			# Preserve the existing left-side screen composition while orbiting.
			var right: Vector3 = -offset.cross(Vector3.UP).normalized()
			var shift: Vector3 = right*offset.length()*tan(deg_to_rad(camera.fov*0.5))*viewport.size.x/viewport.size.y*0.52
			focus_offset = offset
			camera.position = focus_target+offset+shift
			camera.look_at(focus_target+shift,Vector3.UP)
			orbit_velocity *= exp(-7.0*delta)
	sun_lens.update(is_visible_in_tree(), viewport, camera, objects.get(-100), visual_data.get("star_color", Color.WHITE))
	if not is_instance_valid(ship):
		return
	zoom_controls.visible = _zoom_enabled() and not external_zoom_controls
	for p in visual_data.get("planets",[]):
		planet_nodes[p.index].get_node("OverviewName").visible = p.encounter == -1 and not focused and not introducing
		planet_nodes[p.index].get_node("Surface").rotate_y(delta*p.rotation_speed)
	if traveling and travel_direction.length_squared() > 0.0:
		_face(travel_direction, delta * 7.0)
	if orbit_index != -1 and not traveling and defense_view.is_empty():
		orbit_angle += delta * settings.orbit_speed
		var center: Vector3 = objects[orbit_index].position
		var next: Vector3 = center + Vector3(cos(orbit_angle), 0.15, sin(orbit_angle)) * _orbit_radius(orbit_index)
		_face(next - ship.position, delta * 5)
		ship.position = next
	for index in markers:
		var button = markers[index]
		var point: Vector3 = objects[index].position
		var center: Vector2 = camera.unproject_position(point)
		button.visible = not focused and not introducing and not camera.is_position_behind(point) and objects[index].visible
		var blocked: bool = not interactive or interception_pending or pinching or dragging or Time.get_ticks_msec()<gesture_block_until
		button.set_state(button.completed,blocked,index==selected_index)
		button.mouse_filter = MOUSE_FILTER_IGNORE if blocked else MOUSE_FILTER_STOP
		var top: Vector2 = camera.unproject_position(point+Vector3.UP*float(objects[index].get_meta("radius",0.65)))
		button.position = top+Vector2(settings.label_offset.x,-absf(settings.label_offset.y))-Vector2(button.size.x*0.5,button.size.y)
		for rect in hud_regions:
			if rect.intersects(button.get_global_rect().grow(14)):
				if button.contrast and rect.position.y < get_viewport_rect().size.y * 0.5:
					button.position.y = rect.end.y + 15.0
				else:
					button.visible = false
		if inspection_active and inspection_area.is_valid() and inspection_area.call().intersects(button.get_global_rect().grow(14)):
			button.visible = false
		button.anchor_point = center-button.position
		button.queue_redraw()
	# Keep the two high-priority enemy names readable when their projections overlap.
	var placed_enemies: Array[Control] = []
	for index in markers:
		var button = markers[index]
		if not button.visible or not button.contrast: continue
		for other in placed_enemies:
			if button.get_global_rect().intersects(other.get_global_rect().grow(4)):
				button.position.x = other.position.x + other.size.x + 5.0
				button.anchor_point = camera.unproject_position(objects[index].position) - button.position
		placed_enemies.append(button)
	# Fixed positions, bounded O(n²) border emphasis only; no layout reconstruction.
	for index in markers:
		var button = markers[index]
		var behind := false
		for other_index in markers:
			if other_index==index: continue
			var other = markers[other_index]
			if other.visible and button.get_rect().intersects(other.get_rect()) and (other.priority()>button.priority() or (other.priority()==button.priority() and other.get_index()>button.get_index())):
				behind = true
				break
		button.set_secondary(behind)


func _select_destination(index: int) -> void:
	selected_index = index
	var planet: int = visual_data.get("assignments",{}).get(index,-1)
	for key in orbit_nodes:
		var color: Color = settings.orbit_color
		if key==planet:
			color = color.lightened(0.2)
			color.a = 0.7
		orbit_nodes[key].material_override.set_shader_parameter("line_color",color)
		orbit_nodes[key].material_override.set_shader_parameter("line_width",settings.orbit_line_width*(1.25 if key==planet else 1.0))
	for key in markers:
		var marker = markers[key]
		marker.set_state(marker.completed,marker.unavailable,key==index)


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
	if not interactive or interception_pending or pinching or Time.get_ticks_msec() < gesture_block_until or not markers.has(index) or markers[index].disabled:
		return
	if before_travel.is_valid() and not before_travel.call(index):
		return
	var intercepted: bool = intercept_travel.is_valid() and intercept_travel.call(index)
	if not interactive or focused: return
	_select_destination(index)
	feedback.acknowledge(objects[index].position,float(objects[index].get_meta("radius",0.65)),markers[index].accent)
	var destination: Vector3 = objects[index].position + (Vector3(_orbit_radius(index), 0.15, 0) if defense_view.is_empty() or not _defense_hostile(index) else Vector3.ZERO)
	if destination_for.is_valid(): destination = destination_for.call(index, ship.position, destination)
	_start_journey(destination, index, intercepted)


# Free movement uses exactly the same presentation and interception path as PoI travel.
# The coordinator authorizes intent; this map never changes expedition state.
func travel_to_position(point: Vector3, check_eligibility: bool = true) -> void:
	if not interactive or interception_pending or focused:
		return
	if check_eligibility and before_free_travel.is_valid() and not before_free_travel.call(point):
		return
	var intercepted: bool = check_eligibility and intercept_free_travel.is_valid() and intercept_free_travel.call(point)
	if not interactive or focused: return
	_select_destination(-1)
	feedback.acknowledge(point,0.45,Color("8de8ff"))
	_start_journey(point, -3, intercepted)


func _start_journey(destination: Vector3, index: int, intercepted: bool) -> void:
	if motion and motion.is_valid(): motion.kill()
	if not traveling: feedback.set_travel(true)
	traveling = true
	interception_pending = intercepted
	travel_started.emit()
	orbit_index = -1
	var origin: Vector3 = ship.position
	travel_direction = destination - origin
	var seconds: float = origin.distance_to(destination) / physical_speed if physical_speed > 0 else travel_duration
	motion = create_tween().set_trans(Tween.TRANS_LINEAR if physical_speed > 0 else Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if intercepted:
		var fraction := minf(0.5 / maxf(travel_duration, 0.6), 0.8)
		motion.tween_property(ship, "position", origin.lerp(destination, fraction), 0.5)
		motion.tween_callback(_impact)
		motion.tween_interval(1.0)
		motion.tween_callback(func(): traveling = false; interrupted.emit())
	else:
		motion.tween_property(ship, "position", destination, maxf(0.001, seconds))
		motion.tween_callback(func():
			traveling = false
			feedback.set_travel(false,true)
			if index == -3:
				free_arrived.emit()
			else:
				feedback.acknowledge(objects[index].position,float(objects[index].get_meta("radius",0.65)),markers[index].accent)
				orbit_index = index
				orbit_angle = 0.0
				arrived.emit(index))


func apply_navigation_position(point: Vector3) -> void:
	if motion and motion.is_valid(): motion.kill()
	traveling = false
	orbit_index = -1
	ship.position = point
	if is_instance_valid(feedback): feedback.set_travel(false)


func _impact() -> void:
	feedback.set_travel(false)
	_select_destination(-1)
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
	_restore_tactical()
	focus_orbit_enabled = true
	orbit_velocity = Vector2.ZERO
	_end_pinch()
	focused = true
	interactive = false
	if not objects.has(index):
		return
	_select_destination(index)
	focus_target = objects[index].position
	focus_offset = settings.destination_offset*maxf(1.0,float(objects[index].get_meta("radius",0.0))*1.2)
	camera.focus(focus_target, settings, float(objects[index].get_meta("radius", 0.0)))


func overview() -> void:
	selected_touch_index = -1
	last_touch_msec = 0
	interception_pending = false
	_restore_tactical()
	focus_orbit_enabled = false
	orbit_pointer = -2
	orbit_velocity = Vector2.ZERO
	if motion and motion.is_valid():
		motion.kill()
	traveling = false
	if is_instance_valid(feedback): feedback.set_travel(false)
	_select_destination(-1)
	focused = false
	interactive = true
	camera.overview(settings)


func set_active(active: bool) -> void:
	if not active: sun_lens.disable()
	if is_instance_valid(background): background.set_active(active)
	if not active:
		_end_pinch()
	visible = active
	if is_instance_valid(feedback):
		feedback.set_process(active)
		if not active: feedback.cancel()
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
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed)
	if inspection_active and pressed and (not inspection_area.is_valid() or not inspection_area.call().has_point(event.position)):
		consume_gesture()
		inspection_dismissed.emit()
		get_viewport().set_input_as_handled()
		return
	if gesture == Gesture.CONSUMED:
		if (event is InputEventScreenTouch or event is InputEventMouseButton) and not event.pressed:
			gesture = Gesture.IDLE
			get_viewport().set_input_as_handled()
		return
	if focused and focus_orbit_enabled and is_visible_in_tree() and (not input_allowed.is_valid() or input_allowed.call()):
		_focus_input(event)
		return
	if not _zoom_enabled():
		_end_pinch()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if point_is_reserved(event.position) or not get_global_rect().has_point(event.position): return
			if touches.is_empty():
				drag_origin = event.position
				hold_index = nearest_marker(event.position)
				hold_started = Time.get_ticks_msec()
				hold_fired = false
				gesture = Gesture.PRESS
			touches[event.index] = event.position
			if touches.size() >= 2:
				pinching = true
				gesture = Gesture.PINCH
				hold_index = -1
				pinch_distance = _touch_distance()
				_block_markers()
			# Capture presses as well as releases so native Button activation cannot duplicate the map intent.
			get_viewport().set_input_as_handled()
		else:
			if not touches.has(event.index): return
			var tap: bool = not hold_fired and not pinching and not dragging and event.position.distance_to(drag_origin) < settings.pan_drag_threshold
			touches.erase(event.index)
			if tap and touches.is_empty(): _touch_tap(event.position)
			if pinching or dragging: gesture_block_until = Time.get_ticks_msec() + 180
			if touches.is_empty(): _end_pinch()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and touches.has(event.index):
		var previous: Vector2 = touches[event.index]
		touches[event.index] = event.position
		if pinching:
			var distance: float = _touch_distance()
			if distance > 1.0 and pinch_distance > 1.0: camera.zoom_by(distance / pinch_distance)
			pinch_distance = distance
			get_viewport().set_input_as_handled()
		elif touches.size() == 1: _drag_map(previous, event.position)
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if point_is_reserved(event.position) or not get_global_rect().has_point(event.position): return
			mouse_down = true
			drag_origin = event.position
			hold_index = nearest_marker(event.position)
			hold_started = Time.get_ticks_msec()
			hold_fired = false
			gesture = Gesture.PRESS
			get_viewport().set_input_as_handled()
		elif mouse_down:
			var tap: bool = not hold_fired and not dragging and event.position.distance_to(drag_origin) < settings.pan_drag_threshold
			if tap: _tap_at(event.position)
			if dragging: gesture_block_until = Time.get_ticks_msec() + 180
			_end_pinch()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device != -1:
		if mouse_down: _drag_map(event.position - event.relative, event.position)
		var nearest: int = nearest_marker(event.position)
		for index in markers: markers[index]._set_hovered(index == nearest)


# The same nearest-target arbitration is used for native touch, mouse and GUI hit tests.
func nearest_marker(point: Vector2) -> int:
	if point_is_reserved(point) or not get_global_rect().has_point(point): return -1
	var nearest: int = -1
	var distance: float = INF
	for index in markers:
		var button = markers[index]
		if button.disabled or button.unavailable or not button.is_visible_in_tree(): continue
		var candidate: float = button.hit_distance(point - button.global_position)
		if candidate == INF: continue
		if candidate < distance or (is_equal_approx(candidate,distance) and index > nearest):
			nearest = index
			distance = candidate
	return nearest


# Touch selection is separate from confirmation; only a second tap on the
# same current marker inside the interval initiates a journey.
func _touch_tap(point: Vector2) -> void:
	if not touch_confirmation_required:
		_tap_at(point)
		return
	var index: int = nearest_marker(point)
	if index < 0:
		selected_touch_index = -1
		last_touch_msec = 0
		_select_destination(-1)
		# Marker confirmation must not swallow single-tap free travel.
		# Reuse _tap_at to preserve HUD, object and inspection guards.
		_tap_at(point)
		return
	var now: int = Time.get_ticks_msec()
	if selected_touch_index == index and now - last_touch_msec <= double_tap_msec:
		selected_touch_index = -1
		last_touch_msec = 0
		travel(index)
	else:
		selected_touch_index = index
		last_touch_msec = now
		_select_destination(index)
		feedback.acknowledge(objects[index].position, float(objects[index].get_meta("radius", 0.65)), markers[index].accent)

func consume_gesture() -> void:
	_end_pinch()
	gesture = Gesture.CONSUMED
	selected_touch_index = -1
	last_touch_msec = 0

func _tap_at(point: Vector2) -> void:
	if inspection_active:
		inspection_dismissed.emit()
		return
	if interception_pending or point_is_reserved(point) or Time.get_ticks_msec() < gesture_block_until: return
	var index: int = nearest_marker(point)
	if index != -1:
		travel(index)
		return
	# Completed tags, ships and celestial objects never turn into empty-space movement.
	for button in markers.values():
		if button.visible and button.hit_distance(point-button.global_position) != INF: return
	if _point_on_object(point): return
	var target: Vector3 = screen_to_navigation(point)
	free_move_requested.emit(target)


func screen_to_navigation(point: Vector2) -> Vector3:
	var local: Vector2 = point - global_position
	var origin: Vector3 = camera.project_ray_origin(local)
	var direction: Vector3 = camera.project_ray_normal(local)
	if absf(direction.y) < 0.0001: return ship.position
	var target: Vector3 = origin + direction * (-origin.y/direction.y)
	var bounds: Rect2 = settings.system_bounds.abs()
	return Vector3(clampf(target.x,bounds.position.x,bounds.end.x-0.001),0,clampf(target.z,bounds.position.y,bounds.end.y-0.001))


func _point_on_object(point: Vector2) -> bool:
	var local: Vector2 = point-global_position
	var models: Array = objects.values()
	models.append(ship)
	for model in models:
		if not model.visible: continue
		var at: Vector3 = model.position
		if camera.is_position_behind(at): continue
		var center: Vector2 = camera.unproject_position(at)
		var edge: Vector2 = camera.unproject_position(at+camera.basis.x*float(model.get_meta("radius",0.65)))
		if local.distance_to(center) < maxf(12,center.distance_to(edge)): return true
	return false


func _drag_map(previous: Vector2, current: Vector2) -> void:
	if not dragging and current.distance_to(drag_origin) < settings.pan_drag_threshold:
		return
	if not dragging:
		hold_index = -1
		gesture = Gesture.DRAG
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
	if gesture != Gesture.CONSUMED: gesture = Gesture.IDLE
	hold_index = -1
	hold_started = 0
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
	interception_pending = false
	if is_instance_valid(feedback): feedback.cancel()
	if motion and motion.is_valid():
		motion.kill()
	if is_instance_valid(camera):
		camera.cancel()
	_clear_impact()
	traveling = false
	travel_direction = Vector3.ZERO
	_end_pinch()
	if introducing:
		introducing = false
		interactive = true
		camera.finish_introduction()


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
	return preload("res://scripts/presentation/star_system/poi_marker.gd").icon_for("battle" if entry.get("profile")!=null else entry.get("model_kind","unknown"))

func _initial_ship_position() -> Vector3:
	for at in [Vector3(0,0,3),Vector3(-3,0,0),Vector3(3,0,0),Vector3(0,0,-3),Vector3(-2,0,2),Vector3(2,0,-2)]:
		if visual_data.planets.all(func(p): return at.distance_to(p.position)>p.radius*1.5+1.25):
			return at
	return Vector3(0,1.5,3)

func point_is_reserved(point: Vector2) -> bool:
	return hud_regions.any(func(rect): return rect.has_point(point)) or (is_instance_valid(zoom_controls) and zoom_controls.visible and zoom_controls.get_global_rect().has_point(point))

func fit_overview() -> void:
	var points: Array[Vector3] = []
	for p in visual_data.planets:
		for i in range(64): points.append(VisualSystem.orbit_point(p,TAU*i/64.0))
	for key in objects:
		var at: Vector3 = objects[key].position
		var radius: float = float(objects[key].get_meta("radius",2.6 if key==-100 else 1.0))+2.0
		for x in [-1,1]:
			for y in [-1,1]:
				for z in [-1,1]: points.append(at+Vector3(x,y,z)*radius)
	camera.fit_system(points,settings)

func begin_introduction() -> void:
	cancel_presentation()
	introducing = true
	interactive = false
	camera.introduce(settings)

func finish_introduction() -> void:
	camera.finish_introduction()
	introducing = false
	interactive = true

# Only ephemeral transforms are held here. Neither ship identity nor travel state changes.
func tactical_focus(index: int, pursuit: bool = false, profile: Resource = null) -> void:
	_restore_tactical()
	focus_orbit_enabled = false
	focused = true
	interactive = false
	_end_pinch()
	if motion and motion.is_valid(): motion.kill()
	var enemy: Node3D = objects.get(index)
	if enemy == null:
		if profile == null: return
		enemy = Models.ship(profile)
		enemy.scale = Vector3.ONE*0.275
		world.add_child(enemy)
		tactical_temporary = true
		enemy.position = ship.position+Vector3(-3,0,0)
		if pursuit: enemy.rotation = ship.rotation
	tactical_enemy = enemy
	tactical_snapshot = {"enemy":enemy.transform,"ship":ship.transform,"orbit":orbit_index}
	orbit_index = -1
	var center: Vector3 = enemy.position
	if not is_instance_valid(tactical_light):
		tactical_light = OmniLight3D.new()
		tactical_light.light_color = Color("a9cced")
		tactical_light.light_energy = 1.2
		tactical_light.omni_range = 8
		tactical_light.shadow_enabled = false
		world.add_child(tactical_light)
	tactical_light.position = center+Vector3(0,2,3)
	tactical_light.show()
	var enemy_radius: float = _ship_extent(enemy)
	var player_radius: float = _ship_extent(ship)
	var separation: float = maxf(ship.position.distance_to(enemy.position), enemy_radius + player_radius + 0.3)
	var target: Vector3 = (ship.position + enemy.position) * 0.5
	var offset: Vector3 = Vector3(2.5,3.2,7.5)*maxf(1.0,(separation+enemy_radius+player_radius)/2.7)
	var right: Vector3 = -offset.cross(Vector3.UP).normalized()
	var shift: Vector3 = right*offset.length()*tan(deg_to_rad(camera.fov*0.5))*viewport.size.x/viewport.size.y*0.50
	camera.frame(target+offset+shift,target+shift,settings.camera_duration,&"tactical")
	if is_instance_valid(feedback):
		feedback.tactical = true
		feedback.moving = pursuit

func _restore_tactical() -> void:
	if tactical_snapshot.is_empty(): return
	if is_instance_valid(ship): ship.transform = tactical_snapshot.ship
	orbit_index = tactical_snapshot.orbit
	if is_instance_valid(tactical_enemy):
		if tactical_temporary:
			tactical_enemy.hide()
			tactical_enemy.queue_free()
		else: tactical_enemy.transform = tactical_snapshot.enemy
	tactical_enemy = null
	tactical_temporary = false
	tactical_snapshot.clear()
	if is_instance_valid(tactical_light): tactical_light.hide()
	if is_instance_valid(feedback): feedback.tactical = false
	if is_instance_valid(feedback): feedback.set_travel(false)

func _focus_input(event: InputEvent) -> void:
	# Persistent edge HUD and Back remain exclusively GUI-owned.
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		for rect in hud_regions:
			if rect.has_point(event.position):
				orbit_pointer = -2
				return
	var region := Rect2(global_position+Vector2(0,80),Vector2(size.x*0.56,size.y-80))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		orbit_pointer = -1 if event.pressed and region.has_point(event.position) else -2
	elif event is InputEventScreenTouch:
		if event.pressed and region.has_point(event.position): orbit_pointer = event.index
		elif not event.pressed and orbit_pointer == event.index: orbit_pointer = -2
	elif event is InputEventMouseMotion and orbit_pointer == -1:
		orbit_velocity = Vector2(-event.relative.x,event.relative.y)*0.06
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and orbit_pointer == event.index:
		orbit_velocity = Vector2(-event.relative.x,event.relative.y)*0.06
		get_viewport().set_input_as_handled()

func _ship_extent(model: Node3D) -> float:
	var extent: float = 0.1
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree() or mesh.mesh == null: continue
		var bounds: AABB = mesh.mesh.get_aabb()
		for i in range(8):
			extent = maxf(extent,(mesh.to_global(bounds.get_endpoint(i))-model.global_position).length())
	return extent

static func _defense_point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
func _defense_hostile(index: int) -> bool:
	for unit in defense_view.get("units", []):
		if int(unit.encounter) == index: return true
	return false
func sync_defense(snapshot: Dictionary) -> void:
	defense_view = snapshot
	for unit in snapshot.units:
		var index: int = int(unit.encounter)
		if not objects.has(index): continue
		objects[index].position = _defense_point(unit.position)
		var active: bool = unit.status == "active" and (not unit.mothership or snapshot.revealed) and not snapshot.complete
		objects[index].visible = active
		markers[index].disabled = not active
		markers[index].tooltip_text = "Mothership · Neutralize to unlock FTL" if unit.mothership else "Incoming attacker → HOMEWORLD"
		visual_data.anchors[index] = objects[index].position
	if is_instance_valid(defense_effects): defense_effects.refresh(snapshot)
