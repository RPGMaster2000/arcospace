extends Control
## Presents committed telemetry and hand entries. Owns no cards, input rules or turn timing.
signal boot_finished
signal skip_requested

const Holo = preload("res://scripts/ui/holographic/skin.gd")
const Motion = preload("res://scripts/ui/holographic/motion.gd")
const Sound = preload("res://scripts/audio/sfx.gd")
const DeckVisual = preload("res://scripts/ui/battle_deck_visual.gd")
const SignalAccent = preload("res://scripts/ui/battle_signal.gd")
const CardScene = preload("res://scenes/card.tscn")
const BOOT_SECONDS := 1.65
const MINIMAL_SECONDS := 0.20
const DEAL_START := 0.59
const DEAL_STAGGER := 0.105
const DEAL_TRAVEL := 0.31
const DEAL_SETTLE := 0.065
const REPLACEMENT_TRAVEL := 0.27
const DECK_IN := 0.12
const DECK_OUT := 0.15

var boot_started := false
var booting := false
var input_skip_enabled := true
var boot_duration := 0.0
var flights: Dictionary = {}
var deck: DeckVisual
var _boot: Tween
var _boot_items: Array[Control] = []
var _hand: Array[Control] = []
var _defenses: Array[Control] = []
var _player_hull: Control
var _left_controls: Array[Control] = []
var _battle_center_x := 0.0
var _replacement_origin := Vector2.ZERO
var _replacement_scale := 0.28
var _opening_deck := true
var _eat_release := false
var _swept: Array[Control] = []
var _skip_touch := -1
var _touch_skip_frame := -1


func configure(hud: RefCounted) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 24
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hand.assign(hud.cards)
	_defenses.assign([hud.nodes.player_shields_label, hud.nodes.enemy_shields_label])
	_player_hull = hud.nodes.player_hull_label
	_left_controls.assign([hud.nodes.PlayerResource1, hud.nodes.PlayerResource2,
		hud.nodes.PlayerResource3, hud.nodes.FTLPanel, hud.nodes.allocation_button,
		hud.player_panel.handle])
	deck = DeckVisual.new()
	deck.name = "ProjectedDeck"
	deck.hide()
	add_child(deck)
	Motion.Preferences.events.ui_motion_changed.connect(_profile_changed)



static func allowed() -> bool:
	return OS.get_environment("ARCOSPACE_BATTLE_HUD_BOOT") != "0"


func begin(hud: RefCounted, snapshot: Dictionary, card_motion_enabled: bool) -> void:
	if boot_started: return
	boot_started = true
	if not allowed(): return
	booting = true
	var minimal := Motion.Preferences.ui_motion() == 0 or not card_motion_enabled
	boot_duration = MINIMAL_SECONDS if minimal else BOOT_SECONDS
	_boot = create_tween().set_parallel()
	for identity in [hud.header.player, hud.header.enemy]:
		_reveal(identity, 0.02, 0.29, Holo.DEFAULT.friendly if identity == hud.header.player else Holo.DEFAULT.hostile, minimal)
	for side in ["player", "enemy"]:
		var prefix := str(side).capitalize()
		var ship: Dictionary = snapshot[side]
		var hull: Control = hud.nodes[prefix + "HullBar"]
		var hull_label: Label = hud.nodes[side + "_hull_label"]
		_reveal(hull_label, 0.10, 0.34, hull.condition_color(), minimal)
		_reveal(hull, 0.13, 0.29, Color.TRANSPARENT, minimal)
		var shield: Control = hud.shield_stack(side)
		_reveal(hud.nodes[side + "_shields_label"], 0.20, 0.34, Holo.DEFAULT.shield, minimal)
		if not minimal:
			hull.displayed_hull = 0.0
			_boot.tween_property(hull, "displayed_hull", float(ship.hull), 0.35).from(0.0).set_delay(0.20)
			if not snapshot.shields_disabled:
				shield.displayed_points = 0.0
				_boot.tween_property(shield, "displayed_points", float(ship.shields), 0.34).from(0.0).set_delay(0.28)
		for index in hud.RESERVES.size():
			var family: String = hud.RESERVES[index]
			var tile: Control = hud.nodes[prefix + "Resource%d" % (index + 1)]
			var start: float = 0.27 + index * 0.07
			_reveal(tile, start, 0.33, Holo.family(family), minimal)
			if not minimal:
				var label: Label = hud.nodes[side + "_" + family + "_label"]
				label.text = "0"
				_boot.tween_method(hud.nodes.battle_effects.paint_number.bind(label),
					0.0, float(ship[family]), 0.30).set_delay(start + 0.09)
				_sweep(tile.get_node("ProductionBadge"), Holo.family(family), start + 0.23, 0.27)
	_reveal(hud.nodes.FTLPanel, 0.43, 0.33, Holo.DEFAULT.emp_color, minimal)
	var emp: Control = hud.nodes.FTLPanel
	if not minimal and snapshot.emp.charge > 0 and snapshot.emp.disabled_turns == 0:
		emp.fill = 0.0
		_boot.tween_property(emp, "fill", emp.ratio, 0.30).set_delay(0.48)
	_reveal(hud.nodes.allocation_button, 0.50, 0.31, Holo.DEFAULT.edge, minimal)
	_reveal(hud.header.turn, 1.36, 0.29, Holo.DEFAULT.friendly, minimal)
	if minimal:
		for slot in _hand.size():
			_reveal(_hand[slot], 0.0, MINIMAL_SECONDS, Color.TRANSPARENT, true)
	else:
		_boot.tween_callback(_show_deck.bind(true)).set_delay(DEAL_START - DECK_IN)
		_boot.tween_callback(_sound.bind(Holo.DEFAULT.battle_boot_sound)).set_delay(0.17)
		for slot in _hand.size():
			var shown: Dictionary = snapshot.cards[slot]
			if shown.present:
				_deal(slot, shown, DEAL_START + slot * DEAL_STAGGER, DEAL_TRAVEL, DEAL_SETTLE, true)
	_boot.tween_interval(boot_duration)
	_boot.finished.connect(finish_boot, CONNECT_ONE_SHOT)


func _reveal(target: Control, delay: float, seconds: float, ink: Color, minimal: bool) -> void:
	_boot_items.append(target)
	target.modulate.a = 0.0
	_boot.tween_property(target, "modulate:a", 1.0, MINIMAL_SECONDS if minimal else seconds
		).set_delay(0.0 if minimal else delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	if not minimal and ink.a > 0.0:
		_sweep(target, ink, delay + seconds * 0.28, seconds * 0.87)


func _sweep(target: Control, ink: Color, delay: float, seconds: float) -> void:
	_swept.append(target)
	_boot.tween_callback(SignalAccent.sweep.bind(
		target, ink, seconds)).set_delay(delay)


func finish_boot() -> void:
	if not booting: return
	booting = false
	if _boot and _boot.is_valid(): _boot.kill()
	for target in _boot_items:
		target.modulate.a = 1.0
	_boot_items.clear()
	for target in _swept: SignalAccent.clear(target)
	_swept.clear()
	for slot in flights.keys(): complete_slot(slot)
	_hide_deck_immediately()
	boot_finished.emit()


func replacement(slot: int, shown: Dictionary) -> bool:
	if Motion.Preferences.ui_motion() == 0 or not shown.present: return false
	_show_deck(false)
	_deal(slot, shown, DECK_IN * 0.68, REPLACEMENT_TRAVEL, 0.045)
	return true


func _deal(slot: int, shown: Dictionary, delay: float, seconds: float, settle: float, opening: bool = false) -> void:
	_remove_flight(slot)
	var packet := Control.new()
	packet.name = "DealtCard%d" % slot
	packet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	packet.hide()
	add_child(packet)
	var back := DeckVisual.new()
	back.stack = false
	back.assembly = 1.0
	back.tint = Holo.family(shown.preview.family)
	back.premium = shown.preview.tier > 1
	packet.add_child(back)
	var face = CardScene.instantiate()
	face.inspection_enabled = false
	face.card_data = shown.preview
	packet.add_child(face)
	face.set_playable(false, int(shown.affordable))
	face.set_discardable(false)
	face.set_ion_glow(shown.ion_glow, shown.storm_color)
	_ignore_input(face)
	var tween := create_tween()
	flights[slot] = {"packet": packet, "tween": tween}
	_hand[slot].hide()
	tween.tween_interval(delay)
	tween.tween_callback(func():
		_pose(0.0, slot, packet, face, back, opening)
		packet.show()
		if not booting or slot % 2 == 0:
			var sample: StringName = Holo.DEFAULT.rare_draw_sound if shown.preview.tier > 1 else Holo.DEFAULT.card_draw_sound
			_sound(sample))
	tween.tween_method(_pose.bind(slot, packet, face, back, opening), 0.0, 1.0, seconds)
	tween.tween_interval(settle)
	tween.tween_callback(complete_slot.bind(slot, true))


func _pose(progress: float, slot: int, packet: Control, face: Control, back: Control, opening: bool) -> void:
	var destination := _hand[slot]
	var deck_center := deck_origin(opening)
	var extent := destination.size * destination.scale
	var goal := destination.position + extent * 0.5
	var slide := smoothstep(0.55, 1.0, progress)
	var fall := 1.0 - pow(1.0 - progress, 2.0)
	var launch_scale := 0.28
	var rotation := sin(progress * PI) * 0.10
	var expansion := smoothstep(0.14, 0.94, progress)
	if not opening:
		# Drop past the defense tiles in the side lane before crossing the hand.
		fall = 1.0 - pow(1.0 - minf(progress / 0.56, 1.0), 2.0)
		slide = smoothstep(0.51, 1.0, progress)
		launch_scale = _replacement_scale
		expansion = slide
		rotation *= slide
	var approach := Vector2(deck_center.x, goal.y + 11.0)
	var center := deck_center.lerp(approach, fall).lerp(goal, slide)
	# Keep cards narrow until they have cleared the defensive telemetry,
	# then spread out inside the hand. The last frame matches the slot.
	var flip := absf(cos(progress * PI * 1.04))
	var factor := lerpf(launch_scale, destination.scale.x, expansion)
	packet.scale = Vector2(factor * lerpf(maxf(0.08, flip), 1.0, slide), factor)
	packet.rotation = rotation * signf(goal.x - deck_center.x)
	packet.pivot_offset = destination.size * 0.5
	packet.position = center - packet.pivot_offset
	face.size = destination.size
	back.position = packet.pivot_offset - back.size * 1.75
	back.scale = Vector2.ONE * 3.5
	face.visible = progress >= 0.48
	back.visible = not face.visible
	var ink := Holo.family(face.card_data.family)
	var shine := sin(smoothstep(0.48, 0.97, progress) * PI)
	if face.card_data.tier > 1:
		ink = Holo.DEFAULT.rarity_three if face.card_data.tier == 3 else Holo.DEFAULT.rarity_two
	face.modulate = Color.WHITE.lerp(ink.lightened(0.58), shine * (0.43 if face.card_data.tier == 3 else 0.26))


func deck_origin(opening: bool) -> Vector2:
	if not opening: return _replacement_origin
	var left := _defenses[0].get_rect()
	var right := _defenses[1].get_rect()
	return Vector2(_battle_center_x,
		minf(left.position.y, right.position.y) - 64.0)


func fit_deck(bounds: Rect2) -> void:
	_battle_center_x = bounds.get_center().x
	var hull := _player_hull.get_rect()
	var shield := _defenses[0].get_rect()
	var opening := deck_origin(true)
	var hand := _hand[0]
	var gap: float = Holo.DEFAULT.spacing
	var compact := DeckVisual.EXTENT
	var preferred := Vector2(_left_controls.back().get_global_rect().end.x + compact.x * 0.5 + gap,
		hull.position.y - compact.y * 0.5 - gap)
	# Use HUD edges as candidate boundaries. The outer lane is usually beside
	# the ship. Narrow layouts can use the inside edge of the player side.
	var lanes := [Vector2(bounds.position.x, hull.position.x),
		Vector2(shield.end.x, opening.x)]
	for scale_factor: float in [0.28, 0.24, 0.20]:
		var half_extent := (hand.size * scale_factor).max(compact) * 0.5 + Vector2(12, 10) + Vector2.ONE * gap
		var y := hull.position.y - half_extent.y
		var best := Vector2.INF
		for lane: Vector2 in lanes:
			var left := lane.x + half_extent.x
			var right := lane.y - half_extent.x
			if left > right or y - half_extent.y < bounds.position.y: continue
			var candidates := [clampf(preferred.x, left, right), left, right]
			for control in _left_controls:
				var rect := control.get_global_rect()
				candidates.append(rect.end.x + half_extent.x)
				candidates.append(rect.position.x - half_extent.x)
			for x: float in candidates:
				if x < left or x > right: continue
				var corridor := Rect2(x - half_extent.x, y - half_extent.y,
					half_extent.x * 2.0, hand.position.y - y + half_extent.y)
				if _left_controls.any(func(control: Control): return corridor.intersects(control.get_global_rect())): continue
				var candidate := Vector2(x, y)
				if candidate.distance_squared_to(preferred) < best.distance_squared_to(preferred):
					best = candidate
		if best.is_finite():
			_replacement_origin = best
			_replacement_scale = scale_factor
			_fit_projector()
			return
	# Extreme safe insets can eliminate the outer lane. Retain the inside
	# player-side edge and keep the projection compact.
	_replacement_scale = hand.scale.x * 0.18
	_replacement_origin = Vector2(shield.end.x + (opening.x - shield.end.x) * 0.32, opening.y)
	_fit_projector()


func _fit_projector() -> void:
	deck.position = deck_origin(_opening_deck) - deck.size * 0.5


func _show_deck(opening: bool) -> void:
	_opening_deck = opening
	if not deck.visible:
		deck.assembly = 0.0
		deck.premium = Motion.Preferences.ui_motion() == 2
		deck.show()
		_sound(Holo.DEFAULT.deck_sound)
	_fit_projector()
	Motion.start(deck, &"assembly").tween_property(deck, "assembly", 1.0, DECK_IN)


func complete_slot(slot: int, arrived: bool = false) -> void:
	if not flights.has(slot): return
	_remove_flight(slot)
	_hand[slot].show()
	if arrived:
		var card = _hand[slot]
		if card.card_data != null:
			card.pulse_draw()
	if flights.is_empty() and deck.visible:
		var tween := Motion.start(deck, &"assembly")
		tween.tween_property(deck, "assembly", 0.0, DECK_OUT)
		tween.tween_callback(deck.hide)


func _remove_flight(slot: int) -> void:
	if not flights.has(slot): return
	var flight: Dictionary = flights[slot]
	flights.erase(slot)
	flight.tween.kill()
	flight.packet.hide()
	flight.packet.queue_free()


func _hide_deck_immediately() -> void:
	Motion.stop(deck, &"assembly")
	deck.assembly = 0.0
	deck.hide()


func _profile_changed(profile: int) -> void:
	if profile != 0: return
	finish_boot()
	for slot in flights.keys(): complete_slot(slot)
	_hide_deck_immediately()


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and booting and input_skip_enabled:
			_skip_touch = event.index
			_touch_skip_frame = Engine.get_process_frames()
			get_viewport().set_input_as_handled()
			skip_requested.emit()
		elif event.pressed and event.index == _skip_touch:
			# A touch can leave the app before its release arrives.
			_skip_touch = -1
		elif not event.pressed and event.index == _skip_touch:
			_skip_touch = -1
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and (booting and input_skip_enabled
			or (event.device == InputEvent.DEVICE_ID_EMULATION and _touch_skip_frame == Engine.get_process_frames())):
			_eat_release = true
			get_viewport().set_input_as_handled()
			if booting: skip_requested.emit()
		elif event.pressed:
			# The next click takes over after an interrupted skip gesture.
			_eat_release = false
		elif _eat_release:
			_eat_release = false
			get_viewport().set_input_as_handled()
	elif booting and input_skip_enabled and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		skip_requested.emit()


func _ignore_input(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_NONE
	for child in node.get_children(): _ignore_input(child)


func _sound(event: StringName) -> void:
	if event != &"": Sound.play(event, self)
