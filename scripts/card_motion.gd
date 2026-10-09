extends Control

signal step_finished
var cancelling: bool = false

# RESPONSIBILITY: Present a card, invoke resolution at its cue, then finish motion.
# DOES NOT: Pay costs, apply abilities, draw cards or switch turns.
@export var settings: Resource = preload("res://resources/card_motion.tres")
@export var card_scene: PackedScene = preload("res://scenes/card.tscn")
var active_tween: Tween
var source_view: Control
var original_modulate: Color = Color.WHITE

func animate_action(card: Resource, source: Control, side: String, discard: bool, resolve: Callable) -> void:
	if not settings.enabled:
		resolve.call()
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
		active_tween.tween_method(func(progress: float):
			clipper.position.y = start.y + card_size.y * progress
			clipper.size.y = card_size.y * (1.0 - progress)
			visual.position.y = -card_size.y * progress
			$Scanner.position.y = start.y + card_size.y * progress,
			0.0, 1.0, settings.discard_seconds)
		await step_finished
		if cancelling:
			return
		$Scanner.hide()
		resolve.call()
	else:
		var centre: Vector2 = $StageAnchor.position - card_size * settings.stage_scale * 0.5
		if side == "enemy":
			clipper.modulate.a = 0.0
		active_tween = _new_tween().set_parallel(true)
		active_tween.tween_property(clipper, "position", centre, settings.travel_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(clipper, "scale", Vector2.ONE * settings.stage_scale, settings.travel_seconds)
		active_tween.tween_property(clipper, "modulate:a", 1.0, settings.travel_seconds)
		await step_finished
		if cancelling:
			return
		# Resolve once the card has arrived, while the player can read its text.
		resolve.call()
		active_tween = _new_tween()
		active_tween.tween_interval(settings.hold_seconds)
		await step_finished
		if cancelling:
			return
		active_tween = _new_tween().set_parallel(true)
		active_tween.tween_property(clipper, "position", $ExitAnchor.position - card_size * 0.5, settings.exit_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		active_tween.tween_property(clipper, "modulate:a", 0.0, settings.exit_seconds)
		active_tween.tween_property(clipper, "scale", Vector2.ONE * 0.85, settings.exit_seconds)
		await step_finished
		if cancelling:
			return
	clipper.queue_free()
	if is_instance_valid(source_view):
		# The replacement is already dealt, but is revealed only after the old card leaves.
		active_tween = _new_tween()
		active_tween.tween_property(source_view, "modulate", original_modulate, settings.refill_seconds)
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
