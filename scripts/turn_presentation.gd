extends Label

# RESPONSIBILITY: Show whose turn it is without delaying or advancing turns.
const FADE_SECONDS: float = 0.2
var enemy_active: bool = false
var transition: Tween
var resting_y: float

func _ready() -> void:
	resting_y = position.y
	position.y = resting_y - 100.0
	modulate.a = 0.0

func show_enemy_turn(active: bool, slots: Array[NodePath]) -> void:
	if active == enemy_active:
		return
	enemy_active = active
	if transition:
		transition.kill()
	transition = create_tween().set_parallel(true)
	transition.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	transition.tween_property(self, "position:y", resting_y if active else resting_y - 100.0, FADE_SECONDS)
	transition.tween_property(self, "modulate:a", 1.0 if active else 0.0, FADE_SECONDS)
	for path in slots:
		var card: Control = get_parent().get_node(path)
		transition.tween_property(card, "modulate", Color(0.48, 0.48, 0.48) if active else Color.WHITE, FADE_SECONDS)
