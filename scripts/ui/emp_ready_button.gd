extends Button

const Preferences = preload("res://scripts/ui/menu_preferences.gd")
# Pulse only while the charged EMP can actually be activated.
var pulse_time: float = 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree() or disabled:
		pulse_time = 0.0
		self_modulate = Color.WHITE
		return
	if Preferences.ui_motion() == 0:
		pulse_time = 0.0
		self_modulate = Color("addbff")
		return
	pulse_time += delta
	self_modulate = Color.WHITE.lerp(Color(0.3, 0.65, 1.0), (sin(pulse_time * TAU) + 1.0) * 0.35)
