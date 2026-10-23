extends Control
# RESPONSIBILITY: Own one temporary raised hand card; never execute a combat action.
const Style = preload("res://scripts/ui/encounter_presentation.gd")
const Targets = preload("res://scripts/cards/card_targets.gd")
var indicators: Dictionary = {}
var targets: Dictionary = {}
var target_marks: Array = []
var target_context: String = ""
var pulse_time: float = 0.0
var cards: Array[Control] = []
var source: Control
var adapter: Node
var settings: Resource
var origin: Vector2
var saved_z: int
var signature: String
var context: Dictionary = {}
var hint: Label
var hint_tween: Tween
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
	hint = Label.new()
	hint.text = "HIGHLIGHTED SYSTEMS SHOW WHAT THIS CARD MAY AFFECT."
	hint.add_theme_font_size_override("font_size", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	hint.hide()
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
	if valid(): refresh_targets()


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
	refresh_targets()
	source.z_index = 40
	var preferences = preload("res://scripts/ui/menu_preferences.gd")
	if not preferences.preview_hint_seen():
		hint.position = Vector2(160, 76)
		hint.size = Vector2(maxf(200, get_viewport_rect().size.x - 320), 48)
		hint.show()
		hint_tween = create_tween()
		hint_tween.tween_interval(5.0)
		hint_tween.tween_property(hint, "modulate:a", 0.0, 0.4)
		preferences.mark_preview_hint_seen()
	var height: float = source.size.y * source.scale.y
	var target: Vector2 = origin - Vector2(0, height * settings.preview_raise_fraction)
	var inset: Vector4 = preload("res://scripts/ui/battle_layout.gd").safe_insets(get_parent())
	target.y = maxf(inset.y + 64 + settings.preview_inspect_spacing, target.y)
	inspect.position = Vector2(clampf(target.x + (source.size.x * source.scale.x - inspect.size.x) * 0.5, inset.x + 12, get_viewport_rect().size.x - inspect.size.x - inset.z - 12), target.y - 48 - settings.preview_inspect_spacing)
	# Prefer the space above this card, shifting around actual HUD labels when needed.
	for indicator in indicators.values():
		var bounds: Rect2 = indicator.get_global_rect().grow(6)
		if inspect.get_global_rect().intersects(bounds):
			inspect.position.x = clampf(bounds.end.x + 6 if bounds.get_center().x < get_viewport_rect().size.x * 0.5 else bounds.position.x - inspect.size.x - 6, inset.x + 12, get_viewport_rect().size.x - inspect.size.x - inset.z - 12)
	if button_tween != null: button_tween.kill()
	inspect.modulate.a = 0
	inspect.disabled = true
	inspect.show()
	tween = create_tween().set_trans(settings.preview_transition).set_ease(Tween.EASE_OUT)
	tween.tween_property(source, "position", target, 0.0 if settings.reduced_preview_animation else settings.preview_raise_duration)
	tween.tween_callback(func(): inspect.disabled = false)
	tween.tween_property(inspect, "modulate:a", 1.0, settings.preview_fade_duration)
	queue_redraw()


func open_inspection() -> void:
	if valid(): adapter.overlay().present(source, source, settings)


func dismiss(immediate: bool = false) -> void:
	if immediate: finish_lowering()
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
			lower.tween_property(card, "position", origin, 0.0 if settings.reduced_preview_animation else settings.preview_lower_duration)
			lower.tween_callback(func():
				if is_instance_valid(card): card.z_index = lowering[card].z
				lowering.erase(card))
	source = null
	targets.clear()
	target_marks.clear()
	target_context = ""
	queue_redraw()


func _process(delta: float) -> void:
	if source != null:
		pulse_time += delta
		queue_redraw()
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
		if is_instance_valid(pending_other):
			pending_other.hold_input.cancel()
			if pending_other != source: dismiss()
		pending_other = null
		get_viewport().set_input_as_handled()
		return
	if source == null: return
	if event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_I) or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_Y):
		open_inspection()
		get_viewport().set_input_as_handled()
		return
	if not pointer_event or not event.pressed: return
	if inspect.visible and inspect.get_global_rect().has_point(event.position): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var discarded: Control
		for card in cards:
			if card.get_global_rect().has_point(event.position): discarded = card
		dismiss(true)
		if is_instance_valid(discarded) and not discarded.get_node("DiscardButton").disabled:
			discarded.discard_requested.emit()
		consume_release = true
		get_viewport().set_input_as_handled()
		return
	consume_release = true
	for card in cards:
		if card.get_global_rect().has_point(event.position):
			pending_other = card
			card.hold_input._begin(event.index if event is InputEventScreenTouch else -1, event.position)
			get_viewport().set_input_as_handled()
			return
	dismiss()
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if is_instance_valid(inspect): dismiss(true)
	targets.clear()
	target_marks.clear()
	finish_lowering()


func finish_lowering() -> void:
	for card in lowering:
		lowering[card].tween.kill()
		if is_instance_valid(card):
			card.position = lowering[card].origin
			card.z_index = lowering[card].z
	lowering.clear()


func refresh_targets() -> void:
	var stamp: String = signature + str(context.player) + str(context.enemy) + str(context.get("nebula_miss_rate", 0)) + str(context.shields_disabled)
	if stamp == target_context: return
	target_context = stamp
	targets = Targets.analyze(source.card_data, context)
	target_marks.clear()
	var colors: Dictionary = {"positive": settings.target_positive, "negative": settings.target_negative, "uncertain": settings.target_uncertain, "cost": settings.target_cost}
	var symbols: Dictionary = {"positive": "+", "negative": "−", "uncertain": "?", "cost": "$!" if context.player[source.card_data.family] < source.card_data.cost else "$"}
	for key in targets:
		if not indicators.has(key): continue
		for index in range(targets[key].size()):
			var meaning: String = targets[key][index]
			target_marks.append([indicators[key], colors[meaning], symbols[meaning], index])
	inspect.tooltip_text = "Cost: %d %s%s. + gain; − loss; ? uncertain; $ payment." % [source.card_data.cost, source.card_data.family, " (unaffordable)" if context.player[source.card_data.family] < source.card_data.cost else ""]


func _draw() -> void:
	if source == null or settings == null: return
	var pulse: float = 1.0 if settings.reduced_preview_animation else (sin(pulse_time * TAU / settings.target_pulse_duration) + 1.0) * 0.5
	for mark in target_marks:
		var control: Control = mark[0]
		var rect: Rect2 = control.get_global_rect().grow(4)
		var color: Color = mark[1]
		var index: int = mark[3]
		color.a = 0.5 + pulse * settings.target_pulse_intensity * 0.5
		draw_rect(rect.grow(index * 3), color, false, 2)
		draw_string(ThemeDB.fallback_font, rect.position + Vector2(index * 13, -3), mark[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
