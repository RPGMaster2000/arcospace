extends Control
# RESPONSIBILITY: Own one temporary raised hand card; never execute a combat action.
const Style = preload("res://scripts/ui/encounter_presentation.gd")
var cards: Array[Control] = []
var source: Control
var adapter: Node
var settings: Resource
var origin: Vector2
var saved_z: int
var signature: String
var context: Dictionary = {}
var inspect: Button
var tween: Tween
var lowering: Dictionary = {}
var modals: Array[Control] = []
var consume_release: bool = false
var pending_other: Control
var button_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	inspect = Button.new()
	inspect.text = "INSPECT"
	inspect.custom_minimum_size = Vector2(120, 48)
	Style.action(inspect)
	add_child(inspect)
	inspect.hide()
	inspect.pressed.connect(open_inspection)
	get_viewport().size_changed.connect(func(): dismiss(true))


func bind(hand: Array[Control], modal_controls: Array) -> void:
	cards = hand
	modals.assign(modal_controls)
	for card in cards:
		card.hold_input.preview = self


func update_context(data: Dictionary) -> void:
	if is_instance_valid(source):
		if data.current_actor != "player" or not data.winner.is_empty() or data.resolving_card or data.effects_busy or data.turn_number != context.get("turn_number", data.turn_number):
			dismiss()
	context = data


func valid() -> bool:
	return is_instance_valid(source) and source.is_visible_in_tree() and source.card_data != null and fingerprint(source.card_data) == signature


static func fingerprint(card: Resource) -> String:
	return card.identity_key() + str(card.upgrade_level) + str(card.effects)


func present(hold: Node) -> void:
	if not hold.settings.tactical_preview_enabled:
		hold.overlay().present(hold.source, hold.rendering, hold.settings)
		return
	if context.get("current_actor", "") != "player" or not context.get("winner", "").is_empty() or context.get("resolving_card", false) or context.get("effects_busy", false): return
	if source == hold.source: return
	dismiss()
	adapter = hold
	source = hold.source
	settings = hold.settings
	if lowering.has(source):
		var prior: Dictionary = lowering[source]
		prior.tween.kill()
		source.position = prior.origin
		source.z_index = prior.z
		lowering.erase(source)
	origin = source.position
	saved_z = source.z_index
	signature = fingerprint(source.card_data)
	source.z_index = 40
	var height: float = source.size.y * source.scale.y
	var target: Vector2 = origin - Vector2(0, height * settings.preview_raise_fraction)
	target.y = maxf(64 + settings.preview_inspect_spacing, target.y)
	inspect.position = Vector2(clampf(target.x, 12, get_viewport_rect().size.x - inspect.size.x - 12), target.y - 48 - settings.preview_inspect_spacing)
	if button_tween != null: button_tween.kill()
	inspect.modulate.a = 0
	inspect.show()
	tween = create_tween().set_trans(settings.preview_transition).set_ease(Tween.EASE_OUT)
	tween.tween_property(source, "position", target, settings.preview_raise_duration)
	tween.tween_property(inspect, "modulate:a", 1.0, settings.preview_fade_duration)
	queue_redraw()


func open_inspection() -> void:
	if valid(): adapter.overlay().present(source, source, settings)


func dismiss(immediate: bool = false) -> void:
	if tween != null: tween.kill()
	if button_tween != null: button_tween.kill()
	if immediate or settings == null:
		inspect.hide()
	else:
		button_tween = create_tween()
		button_tween.tween_property(inspect, "modulate:a", 0.0, settings.preview_fade_duration)
		button_tween.tween_callback(func():
			if source == null: inspect.hide())
	if is_instance_valid(source):
		var card: Control = source
		if immediate:
			card.position = origin
			card.z_index = saved_z
		else:
			var lower := create_tween().set_trans(settings.preview_transition).set_ease(Tween.EASE_OUT)
			lowering[card] = {"tween": lower, "origin": origin, "z": saved_z}
			lower.tween_property(card, "position", origin, settings.preview_lower_duration)
			lower.tween_callback(func():
				if is_instance_valid(card): card.z_index = lowering[card].z
				lowering.erase(card))
	source = null
	queue_redraw()


func _process(_delta: float) -> void:
	if source == null: return
	if not valid():
		dismiss()
		return
	for modal in modals:
		if is_instance_valid(modal) and modal.is_visible_in_tree():
			dismiss()
			return
	var full := get_tree().root.get_node_or_null("CardInspection")
	inspect.visible = not (full != null and full.is_open())


func _input(event: InputEvent) -> void:
	var full := get_tree().root.get_node_or_null("CardInspection")
	if full != null and full.is_open(): return
	var pointer_event: bool = event is InputEventMouseButton or event is InputEventScreenTouch
	if consume_release and pointer_event and not event.pressed:
		consume_release = false
		if is_instance_valid(pending_other) and pending_other != source: dismiss()
		pending_other = null
		get_viewport().set_input_as_handled()
		return
	if source == null: return
	if event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_I:
		open_inspection()
		get_viewport().set_input_as_handled()
		return
	if not pointer_event or not event.pressed: return
	if inspect.visible and inspect.get_global_rect().has_point(event.position): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		dismiss(true)
		return
	consume_release = true
	for card in cards:
		if card.get_global_rect().has_point(event.position):
			pending_other = card if card != source else null
			card.hold_input._begin(event.index if event is InputEventScreenTouch else -1, event.position)
			get_viewport().set_input_as_handled()
			return
	dismiss()
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	for card in lowering:
		lowering[card].tween.kill()
		if is_instance_valid(card):
			card.position = lowering[card].origin
			card.z_index = lowering[card].z
	lowering.clear()
