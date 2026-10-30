extends Control

const Sound = preload("res://scripts/audio/sfx.gd")

# RESPONSIBILITY: Present a card, invoke resolution at its cue, then finish motion.
# DOES NOT: Pay costs, apply abilities, draw cards or switch turns.

signal step_finished
var cancelling: bool = false

@export var settings: Resource = preload("res://resources/card_motion.tres")
@export var card_scene: PackedScene = preload("res://scenes/card.tscn")
var active_tween: Tween
var source_view: Control
var original_modulate: Color = Color.WHITE


# Invoke the supplied resolution callback once at the visual cue; Board owns the callback and turn lock.
func animate_action(
	card: Resource, source: Control, side: String, discard: bool, resolve: Callable, present: Callable = Callable()
) -> void:
	if not settings.enabled:
		Sound.play(&"card_discard" if discard else &"card_play", self)
		await resolve.call()
		return
	source_view = source
	var card_size := Vector2(198, 294)
	var start: Vector2 = $EnemyOrigin.position - card_size * 0.5
	if source != null:
		original_modulate = source.modulate
		card_size = source.size
		start = get_global_transform().affine_inverse() * source.global_position
		# Retain the hand slot; only its moving visual leaves the board.
		source.modulate.a = 0.0
	var clipper := Control.new()
	clipper.name = "PlayedCard"
	clipper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clipper.position = start
	clipper.size = card_size
	add_child(clipper)
	var visual = card_scene.instantiate()
	visual.card_data = card
	clipper.add_child(visual)
	visual.size = card_size
	visual.get_node("DiscardButton").hide()
	visual.set_playable(true)
	_ignore_input(visual)
	if discard:
		Sound.play(&"card_discard", self)
		# A moving clip boundary gives a cheap scanner dissolve without textures.
		clipper.clip_contents = true
		if side == "enemy":
			visual.get_node("TitleLabel").text = "ENEMY\nDISCARD"
			for path in ["CostLabel", "DescriptionLabel", "ResourceIcon", "ArtPlaceholder"]:
				visual.get_node(path).hide()
		$Scanner.size = Vector2(card_size.x + 10, 3)
		$Scanner.position = start - Vector2(5, 0)
		$Scanner.show()
		active_tween = _new_tween()
		active_tween.tween_method(
			func(progress: float):
				clipper.position.y = start.y + card_size.y * progress
				clipper.size.y = card_size.y * (1.0 - progress)
				visual.position.y = -card_size.y * progress
				$Scanner.position.y = start.y + card_size.y * progress,
			0.0,
			1.0,
			settings.discard_seconds
		)
		await step_finished
		if cancelling:
			return
		$Scanner.hide()
		resolve.call()
	else:
		# Cards activate in place rather than covering the battlefield.
		# Player: lift in the hand. Enemy: place the compact activation between
		# the ship (left), title (above), and resource stack (right).
		if side == "enemy":
			start = Vector2(size.x * 0.51, maxf(155.0, size.y * 0.29))
			clipper.position = start
		var destination: Vector2 = start + Vector2(0, -card_size.y * (0.20 if side == "player" else 0.04))
		if side == "enemy":
			clipper.scale = Vector2.ONE * 0.72
			clipper.modulate.a = 0.0
		var glow := Panel.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var glow_style := StyleBoxFlat.new()
		glow_style.bg_color = Color(0.08, 0.54, 0.95, 0.10)
		glow_style.border_color = Color(0.26, 0.83, 1.0, 0.90)
		glow_style.set_border_width_all(3)
		glow_style.set_corner_radius_all(8)
		glow_style.shadow_color = Color(0.12, 0.65, 1.0, 0.65)
		glow_style.shadow_size = 12
		glow.add_theme_stylebox_override("panel", glow_style)
		clipper.add_child(glow)
		clipper.move_child(glow, 0)
		active_tween = _new_tween().set_parallel(true)
		active_tween.tween_property(clipper, "position", destination, settings.travel_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(clipper, "modulate:a", 1.0, settings.travel_seconds)
		await step_finished
		if cancelling: return
		Sound.play(&"card_play", self)
		active_tween = _new_tween()
		active_tween.tween_interval(settings.damage_hold_seconds)
		await step_finished
		if cancelling: return
		# Dissolve/fade before invoking the gameplay callback: impact is the cue.
		active_tween = _new_tween().set_parallel(true)
		active_tween.tween_property(clipper, "modulate:a", 0.0, settings.damage_exit_seconds)
		active_tween.tween_property(clipper, "scale", clipper.scale * 0.93, settings.damage_exit_seconds)
		await step_finished
		if cancelling: return
		clipper.hide()
		await resolve.call()
		if cancelling: return
	clipper.hide()
	clipper.queue_free()
	if present.is_valid(): present.call()
	if is_instance_valid(source_view):
		# The replacement is already dealt, but is revealed only after the old card leaves.
		active_tween = _new_tween()
		active_tween.tween_property(
			source_view, "modulate", original_modulate, settings.refill_seconds
		)
		await step_finished
		if cancelling:
			return
	source_view = null


func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_ignore_input(child)


func _new_tween() -> Tween:
	var tween: Tween = create_tween()
	tween.finished.connect(func(): step_finished.emit(), CONNECT_ONE_SHOT)
	return tween


func _exit_tree() -> void:
	cancelling = true
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	if is_instance_valid(source_view):
		source_view.modulate = original_modulate
	# Release any waiting action when the scene closes or restarts.
	step_finished.emit()


func _ready() -> void:
	resized.connect(_fit_anchors)
	_fit_anchors()


func _fit_anchors() -> void:
	$StageAnchor.position = Vector2(size.x * 0.5, 282.0 + (size.y - 720.0) * 0.5)
	$EnemyOrigin.position = Vector2(size.x - 155.0, 190.0)
