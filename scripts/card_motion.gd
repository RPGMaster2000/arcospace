extends Control

const Flavor = preload("res://scripts/ui/enemy_card_flavor.gd")
const Sound = preload("res://scripts/audio/sfx.gd")
const ENEMY_LANE := 0.51
const ENEMY_EXIT_WIDTH := 0.65
const ENEMY_HANDOFF_FADE := 0.12

# RESPONSIBILITY: Present a card, invoke resolution at its cue, then finish motion.
# DOES NOT: Pay costs, apply abilities, draw cards or switch turns.

signal step_finished
var cancelling: bool = false

@export var settings: Resource = preload("res://resources/card_motion.tres")
@export var card_scene: PackedScene = preload("res://scenes/card.tscn")
var active_tween: Tween
var source_view: Control
var original_modulate: Color = Color.WHITE
var lingering_cards: Array[Control] = []
var lingering_tweens: Dictionary = {}


# Invoke the supplied resolution callback once at the visual cue; Board owns the callback and turn lock.
func animate_action(
	card: Resource, source: Control, side: String, discard: bool, resolve: Callable, present: Callable = Callable()
) -> void:
	if not settings.enabled:
		Sound.play(&"card_discard" if discard else &"card_play", self)
		await resolve.call()
		return
	if side == "player" and not discard:
		_fade_lingering(&"enemy_linger")
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
	if side == "enemy":
		visual.display_title = Flavor.title(card, get_parent().get("enemy_ship_data"))
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
		if side == "enemy":
			start = Vector2(size.x * ENEMY_LANE, maxf(155.0, size.y * 0.29))
			clipper.position = start
			clipper.scale = Vector2.ONE * 0.72
			clipper.modulate.a = 0.0
		elif source != null:
			clipper.scale = source.scale
		var extent := card_size * clipper.scale
		var lift := extent.y * 0.20 if side == "player" else card_size.y * 0.04
		var destination := start - Vector2(0, lift)
		if side == "player":
			destination.x = (size.x - extent.x) * 0.5
			clipper.set_meta(&"player_linger", true)
		else:
			clipper.set_meta(&"enemy_linger", true)

		var glow := Panel.new()
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var glow_style := StyleBoxFlat.new()
		glow_style.bg_color = Color(0.08, 0.54, 0.95, 0.10)
		glow_style.border_color = Color(0.26, 0.83, 1.0, 0.90)
		glow_style.set_border_width_all(3)
		glow_style.set_corner_radius_all(8)
		glow_style.shadow_color = Color(0.12, 0.65, 1.0, 0.65)
		glow_style.shadow_size = 0 if OS.has_feature("mobile") else 12
		glow.add_theme_stylebox_override("panel", glow_style)
		clipper.add_child(glow)
		clipper.move_child(glow, 0)
		active_tween = _new_tween().set_parallel(true)
		if side == "player":
			active_tween.tween_method(_center_player_card.bind(clipper, start, destination), 0.0, 1.0, settings.travel_seconds)
		else:
			active_tween.tween_property(clipper, "position", destination, settings.travel_seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		active_tween.tween_property(clipper, "modulate:a", 1.0, settings.travel_seconds)
		await step_finished
		if cancelling: return
		Sound.play(&"card_play", self)
		# Purely visual hold: the gameplay resolution and turn flow never await it.
		await resolve.call()
		if cancelling: return
		lingering_cards.append(clipper)
		var linger_seconds: float = 1.8 if side == "enemy" else 0.48
		var exit_tween := create_tween()
		lingering_tweens[clipper] = exit_tween
		# A parallel tween starts all tracks together; hold must be a prior step.
		exit_tween.tween_interval(linger_seconds)
		exit_tween.tween_property(clipper, "modulate:a", 0.0, 0.28)
		exit_tween.parallel().tween_property(clipper, "position", clipper.position + (Vector2(-card_size.x * ENEMY_EXIT_WIDTH, 0) if side == "enemy" else Vector2(0, -extent.y * 0.65)), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		exit_tween.tween_callback(_finish_lingering_card.bind(weakref(clipper)))
		if present.is_valid(): present.call()
		# Preserve the existing refill tween completion boundary. Tests and
		# callers await this action signal; the visual hold remains independent.
		if is_instance_valid(source_view):
			active_tween = _new_tween()
			active_tween.tween_property(source_view, "modulate", original_modulate, settings.refill_seconds)
			await step_finished
			if cancelling: return
		source_view = null
		return
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


func _center_player_card(progress: float, card: Control, start: Vector2, destination: Vector2) -> void:
	# Both axes move through one tween. The earlier horizontal easing clears
	# the defense tiles before the later part of the lift crosses their height.
	var slide := smoothstep(0.0, 1.0, 1.0 - pow(1.0 - progress, 4.0))
	var lift := smoothstep(0.0, 1.0, progress * progress)
	card.position = Vector2(lerpf(start.x, destination.x, slide), lerpf(start.y, destination.y, lift))


func fade_played_player() -> void:
	_fade_lingering(&"player_linger")


func _fade_lingering(tag: StringName) -> void:
	for card in lingering_cards:
		if not card.has_meta(tag): continue
		card.remove_meta(tag)
		lingering_tweens[card].kill()
		var fade := create_tween()
		lingering_tweens[card] = fade
		fade.tween_property(card, "modulate:a", 0.0, minf(ENEMY_HANDOFF_FADE, settings.travel_seconds * 0.4))
		fade.tween_callback(_finish_lingering_card.bind(weakref(card)))


func _finish_lingering_card(card_ref: WeakRef) -> void:
	var card: Control = card_ref.get_ref()
	if card == null:
		return
	lingering_cards.erase(card)
	lingering_tweens.erase(card)
	card.queue_free()


func clear_lingering_cards() -> void:
	# Called immediately before a replacement is drawn; never awaited.
	for card in lingering_cards:
		if lingering_tweens.has(card):
			var tween: Tween = lingering_tweens[card]
			if tween.is_valid(): tween.kill()
		if is_instance_valid(card):
			card.hide()
			card.queue_free()
	lingering_cards.clear()
	lingering_tweens.clear()
	if is_instance_valid(source_view):
		source_view.modulate = original_modulate


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
	clear_lingering_cards()
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
