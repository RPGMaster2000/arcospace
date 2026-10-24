extends Camera3D
# Owns map camera framing; never reads or modifies expedition state.
var motion: Tween
var viewing: StringName = &"overview"
var zoom_scale: float = 1.0
var zoom_target: float = 1.0
var calibration: Resource
var pan_offset := Vector2.ZERO


func _process(delta: float) -> void:
	if calibration == null or viewing != &"overview" or (motion and motion.is_running()):
		return
	zoom_scale = lerpf(zoom_scale, zoom_target, 1.0 - exp(-18.0 * delta))
	position = _overview_position(calibration)


func _overview_position(settings: Resource) -> Vector3:
	return _overview_target(settings) + (settings.overview_position - settings.overview_target) / zoom_scale


func zoom_by(factor: float) -> void:
	if calibration == null or viewing != &"overview":
		return
	var low: float = minf(calibration.minimum_zoom, calibration.maximum_zoom)
	var high: float = maxf(calibration.minimum_zoom, calibration.maximum_zoom)
	zoom_target = clampf(zoom_target * factor, maxf(0.1, low), maxf(0.1, high))


func frame(position_to: Vector3, target: Vector3, duration: float, state: StringName) -> void:
	viewing = state
	if motion and motion.is_valid():
		motion.kill()
	var destination := Transform3D(Basis.IDENTITY, position_to).looking_at(target, Vector3.UP)
	if duration <= 0.0:
		transform = destination
		return
	motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(self, "transform", destination, duration)


func overview(settings: Resource, immediate: bool = false) -> void:
	if calibration == null:
		calibration = settings
		zoom_target = settings.default_zoom
		zoom_by(1.0)
		zoom_scale = zoom_target
	frame(
		_overview_position(settings), _overview_target(settings),
		0.0 if immediate else settings.camera_duration, &"overview"
	)


func focus(point: Vector3, settings: Resource) -> void:
	# Aim to the right of the object: it appears in the left half of the viewport.
	var offset: Vector3 = settings.destination_offset
	var right := offset.cross(Vector3.UP).normalized() * -1.0
	var aspect: float = get_viewport().get_visible_rect().size.aspect()
	var shift: Vector3 = right * offset.length() * tan(deg_to_rad(fov * 0.5)) * aspect * 0.52
	frame(point + offset + shift, point + shift, settings.camera_duration, &"destination")


func close_ship(point: Vector3, duration: float, state: StringName) -> void:
	frame(ship_view(point).origin, point, duration, state)


func _overview_target(settings: Resource) -> Vector3:
	return settings.overview_target + Vector3(pan_offset.x, 0, pan_offset.y)


func pan_screen(from: Vector2, to: Vector2) -> void:
	if calibration == null or viewing != &"overview":
		return
	var plane := Plane(Vector3.UP, calibration.overview_target.y)
	var origin: Variant = plane.intersects_ray(project_ray_origin(from), project_ray_normal(from))
	var destination: Variant = plane.intersects_ray(project_ray_origin(to), project_ray_normal(to))
	if origin == null or destination == null:
		return
	var shift: Vector3 = origin - destination
	var bounds: Rect2 = calibration.pan_bounds.abs()
	pan_offset = (pan_offset + Vector2(shift.x, shift.z)).clamp(bounds.position, bounds.end)
	position = _overview_position(calibration)


func cancel() -> void:
	if motion and motion.is_valid():
		motion.kill()


func _exit_tree() -> void:
	cancel()


func ship_view(point: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, point + Vector3(1.5, 1.5, 2.2)).looking_at(point, Vector3.UP)
