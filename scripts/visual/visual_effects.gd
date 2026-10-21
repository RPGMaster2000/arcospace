extends RefCounted


# RESPONSIBILITY: Small interruptible text reveals; never block input or gameplay.
static func reveal(
	control: Control, settings: Resource, duration: float = -1.0, start_scale: float = 1.0
) -> void:
	reset(control)
	control.pivot_offset = control.size * 0.5
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * start_scale
	var tween = control.create_tween().set_parallel(true)
	tween.set_trans(settings.interaction_transition).set_ease(settings.interaction_ease)
	tween.tween_property(
		control, "modulate:a", 1.0, settings.ui_transition_duration if duration < 0 else duration
	)
	tween.tween_property(
		control, "scale", Vector2.ONE, settings.ui_transition_duration if duration < 0 else duration
	)
	control.set_meta("visual_reveal", tween)


static func reset(control: Control) -> void:
	if control.has_meta("visual_reveal"):
		var previous: Tween = control.get_meta("visual_reveal")
		if previous != null and previous.is_valid():
			previous.kill()
		control.remove_meta("visual_reveal")
	control.modulate.a = 1.0
	control.scale = Vector2.ONE
