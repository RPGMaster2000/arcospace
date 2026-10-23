extends Camera3D
# Owns map camera framing; never reads or modifies expedition state.
var motion: Tween
var viewing: StringName = &"overview"

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
	frame(settings.overview_position, settings.overview_target, 0.0 if immediate else settings.camera_duration, &"overview")

func focus(point: Vector3, settings: Resource) -> void:
	# Aim to the right of the object: it appears in the left half of the viewport.
	var offset: Vector3 = settings.destination_offset
	var right := offset.cross(Vector3.UP).normalized() * -1.0
	var aspect: float = get_viewport().get_visible_rect().size.aspect()
	var shift: Vector3 = right * offset.length() * tan(deg_to_rad(fov * 0.5)) * aspect * 0.52
	frame(point + offset + shift, point + shift, settings.camera_duration, &"destination")

func close_ship(point: Vector3, duration: float, state: StringName) -> void:
	frame(point + Vector3(1.5, 1.5, 2.2), point, duration, state)
