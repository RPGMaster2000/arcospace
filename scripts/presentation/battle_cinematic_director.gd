extends Node
## One camera owner; no combat, reward, RNG or expedition-state references.
## Existing scene nodes are borrowed, never cloned. All edits are restored on exit.
signal settled
signal started
signal stage_changed(stage: String)
## Presentation cue, separate from the three camera shot stages.
signal intro_hud_ready
const INTRO_HUD_LEAD_SECONDS := 0.4
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const ImportedVFX = preload("res://scripts/effects/imported_combat_vfx.gd")
const Sound = preload("res://scripts/audio/sfx.gd")
const EMP = preload("res://scripts/presentation/emp_cinematic_effect.gd")
const IntroFont = preload("res://assets/fonts/emoji_ui.tres")
@export var settings: Resource = preload("res://resources/presentation/battle_cinematics.tres")
var camera: Camera3D
var player: Node3D
var enemy: Node3D
var backdrop: MeshInstance3D
var view: SubViewportContainer
var board: Control
var active := false
var kind := ""
var stage := ""
var exiting := false
var revision := 0
var motion: Tween
var skipped := false
var external_destruction := false
var default_fov := 0.0
var default_backdrop_scale := Vector3.ONE
var _camera_rest: Transform3D
var _backdrop_rest: Transform3D
var _view_bottom := 0.0
var _ui: Dictionary = {}
var _bounds: Dictionary = {}
var _backfill: ColorRect
var _skip_layer: CanvasLayer
var skip_button: Button
var _intro_caption: PanelContainer
var _intro_name: Label
var _intro_class: Label
var _boost_body: Node3D
var _body_rest := Vector3.ZERO
var _boost_shield: Node3D
var _shield_rest := Vector3.ZERO
var _engine_rest := false
var _focus_rest: WeakRef
var _transition: CanvasLayer
var _charge_glow: MeshInstance3D
var _beam_victim_pose: Transform3D
var _impact_hold: Tween
var emp_effect: Node3D


static func enabled() -> bool:
	# Regression runners opt out of optional camera/handoff presentation explicitly.
	# Dedicated camera tests opt in; no preference or save file is rewritten.
	return OS.get_environment("ARCOSPACE_BATTLE_CINEMATICS") != "0"


func allowed() -> bool:
	return enabled() and not Preferences.skip_cinematics()


func configure(
	owner: Control, lens: Camera3D, surface: MeshInstance3D, viewport: SubViewportContainer
) -> void:
	board = owner
	camera = lens
	backdrop = surface
	view = viewport
	player = camera.get_parent().get_node("PlayerShip")
	enemy = camera.get_parent().get_node("EnemyShip")
	# Cover the space exposed as the full-screen intro settles back into the hand.
	_backfill = ColorRect.new()
	_backfill.color = Color.BLACK
	_backfill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backfill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	board.add_child(_backfill)
	board.move_child(_backfill, 0)
	_backfill.hide()
	_skip_layer = CanvasLayer.new()
	_skip_layer.layer = 400
	add_child(_skip_layer)
	var blocker := Control.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_skip_layer.add_child(blocker)
	skip_button = Button.new()
	skip_button.text = "Skip cinematic"
	skip_button.custom_minimum_size = Vector2(140, 48)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	skip_button.position = Vector2(-156, 16)
	preload("res://scripts/ui/encounter_presentation.gd").action(skip_button)
	blocker.add_child(skip_button)
	skip_button.pressed.connect(skip)
	_intro_caption = PanelContainer.new()
	_intro_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_intro_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_intro_caption.offset_left = 24
	_intro_caption.offset_right = 24
	_intro_caption.offset_top = -24
	_intro_caption.offset_bottom = -24
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color(.025, .05, .085, .86)
	plate.border_color = Color(.43, .68, .84, .66)
	plate.border_width_left = 2
	plate.content_margin_left = 15
	plate.content_margin_right = 18
	plate.content_margin_top = 8
	plate.content_margin_bottom = 8
	_intro_caption.add_theme_stylebox_override("panel", plate)
	blocker.add_child(_intro_caption)
	var caption_lines := VBoxContainer.new()
	caption_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_lines.add_theme_constant_override("separation", 0)
	_intro_caption.add_child(caption_lines)
	_intro_name = Label.new()
	_intro_name.add_theme_font_override("font", IntroFont)
	_intro_name.add_theme_font_size_override("font_size", 25)
	caption_lines.add_child(_intro_name)
	_intro_class = Label.new()
	_intro_class.add_theme_font_override("font", IntroFont)
	_intro_class.add_theme_font_size_override("font_size", 17)
	_intro_class.add_theme_color_override("font_color", Color(.70, .84, .93))
	caption_lines.add_child(_intro_class)
	_intro_caption.hide()
	_skip_layer.hide()


func _measure(ship: Node3D) -> Dictionary:
	var bounds: AABB = ship.measure_hull()
	var scale: Vector3 = ship.global_basis.get_scale().abs()
	return {
		"center": bounds.get_center(),
		"radius": maxf(.5, (bounds.size * scale).length() * .5)
	}


func _center(ship: Node3D) -> Vector3:
	return ship.to_global(_bounds[ship].center)


func _pose(ship: Node3D, offset: Vector3) -> Transform3D:
	var radius: float = _bounds[ship].radius
	var distance := maxf(
		radius * offset.length(),
		radius / sin(deg_to_rad(settings.cinematic_fov) * .5) * settings.framing_margin
	)
	var direction: Vector3 = ship.global_basis.orthonormalized() * offset.normalized()
	return Transform3D(Basis.IDENTITY, _center(ship) + direction * distance).looking_at(
		_center(ship), Vector3.UP
	)


func _begin(mode: String, fullscreen: bool) -> int:
	cancel()
	kind = mode
	active = true
	started.emit()
	skipped = false
	external_destruction = false
	_camera_rest = camera.global_transform
	_backdrop_rest = backdrop.transform
	default_fov = camera.fov
	default_backdrop_scale = backdrop.scale
	_view_bottom = view.offset_bottom
	_bounds = {player: _measure(player), enemy: _measure(enemy)}
	if fullscreen:
		_backfill.show()
		for node in board.get_children():
			if node is CanvasItem and node != view and node != _backfill:
				_ui[node] = node.visible
				node.hide()
		view.offset_bottom = 0
	var focused := board.get_viewport().gui_get_focus_owner()
	_focus_rest = weakref(focused) if focused != null else null
	_skip_layer.show()
	if mode == "emp":
		skip_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
		skip_button.offset_left = -70.0
		skip_button.offset_right = 70.0
	else:
		skip_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		skip_button.offset_left = -156.0
		skip_button.offset_right = -16.0
	skip_button.offset_top = 16.0
	skip_button.offset_bottom = 64.0
	skip_button.grab_focus()
	return revision


func release_intro_hud(controls: Array) -> void:
	if not active or kind != "introduction": return
	for control in controls:
		if not _ui.has(control): continue
		control.visible = _ui[control]
		_ui.erase(control)


func mask_ui() -> void:
	if not active:
		return
	for node in _ui:
		if is_instance_valid(node):
			node.hide()


func _set_camera(pose: Transform3D, fov: float) -> void:
	camera.global_transform = pose
	camera.fov = fov
	if backdrop.get_meta("infinite_panorama", false):
		return
	# Reorient the existing panorama quad; preserve its material/environment.
	var depth := 100.0
	var mesh_size: Vector3 = backdrop.mesh.get_aabb().size
	var aspect := float(view.size.x) / maxf(1, view.size.y)
	var height := depth * tan(deg_to_rad(fov) * .5) * 2.4
	var scale_factor := maxf(
		height / maxf(.1, mesh_size.y), height * aspect / maxf(.1, mesh_size.x)
	)
	backdrop.global_transform = Transform3D(
		pose.basis.scaled(Vector3.ONE * scale_factor), pose.origin - pose.basis.z * depth
	)


func _stage(label: String) -> void:
	stage = label
	stage_changed.emit(label)


func _move(
	from: Transform3D, to: Transform3D, seconds: float, from_fov: float, to_fov: float,
	reveal_caption: bool = false
) -> void:
	motion = create_tween()
	(
		motion
		. tween_method(
			func(p: float):
				_set_camera(from.interpolate_with(to, p), lerpf(from_fov, to_fov, p))
				if reveal_caption: _intro_caption.modulate.a = smoothstep(0.0, .50, p),
			0.0,
			1.0,
			settings.duration(seconds)
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	motion.tween_callback(settled.emit)
	await settled


func introduction(enemy_name: String = "", enemy_class: String = "") -> void:
	if not allowed():
		return
	var token := _begin("introduction", true)
	_intro_name.text = enemy_name
	_intro_class.text = enemy_class
	_intro_caption.modulate.a = 0.0
	_intro_caption.visible = not enemy_name.is_empty()
	_stage("establishing")
	if token != revision or not active:
		return
	var a := _pose(enemy, settings.establishing_from)
	var b := _pose(enemy, settings.establishing_to)
	_set_camera(a, settings.cinematic_fov)
	await _move(
		a, b, settings.introduction_seconds.x, settings.cinematic_fov, settings.cinematic_fov, true
	)
	if token != revision or not active:
		return
	if skipped:
		_finish()
		return
	_stage("flyby")
	if token != revision or not active:
		return
	a = _pose(enemy, settings.flyby_from)
	b = _pose(enemy, settings.flyby_to)
	_set_camera(a, settings.cinematic_fov)
	await _move(
		a, b, settings.introduction_seconds.y, settings.cinematic_fov, settings.cinematic_fov
	)
	if token != revision or not active:
		return
	if skipped:
		_finish()
		return
	_stage("confrontation")
	if token != revision or not active:
		return
	a = _pose(enemy, settings.confrontation_offset)
	_set_camera(a, settings.cinematic_fov)
	var hold: float = minf(settings.confrontation_hold, settings.introduction_seconds.z * .4)
	var exit_direction := (_camera_rest.origin - a.origin).slide(a.basis.z).normalized()
	var travel := a.origin.distance_to(_camera_rest.origin)
	# Bend above the intervening player ship, then descend into its normal frame.
	var pullback := a.origin + (a.basis.z * .38 + exit_direction * .26 + Vector3.UP * .42) * travel
	var pullback_seconds: float = settings.duration(settings.introduction_seconds.z - hold)
	motion = create_tween()
	motion.tween_interval(settings.duration(hold))
	(
		motion
		. tween_method(
			func(p: float):
				_intro_caption.modulate.a = 1.0 - smoothstep(.12, .72, p)
				view.offset_bottom = lerpf(0, _view_bottom, p)
				var normal_height := maxf(1, board.size.y + _view_bottom)
				var adjusted := rad_to_deg(
					2 * atan(tan(deg_to_rad(default_fov) * .5) * view.size.y / normal_height)
				)
				var pose := a.interpolate_with(_camera_rest, p)
				pose.origin = a.origin.lerp(pullback, p).lerp(pullback.lerp(_camera_rest.origin, p), p)
				_set_camera(pose, lerpf(settings.cinematic_fov, adjusted, p)),
			0.0,
			1.0,
			pullback_seconds
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	# Run alongside the final pullback, using actual playback duration.
	# A short pullback starts the HUD immediately after the confrontation hold.
	motion.parallel().tween_callback(intro_hud_ready.emit).set_delay(
		maxf(0.0, pullback_seconds - INTRO_HUD_LEAD_SECONDS)
	)
	motion.tween_callback(settled.emit)
	await settled
	if token == revision:
		_finish()


func beam_charge(actor: Node3D, victim: Node3D) -> void:
	var token := _begin("heavy_beam", false)
	var attacker_center := _center(actor)
	var victim_center := _center(victim)
	var midpoint := attacker_center.lerp(victim_center, .5)
	var axis := (victim_center - attacker_center).normalized()
	var normal := Vector3.UP.cross(axis).normalized()
	if normal.is_zero_approx(): normal = Vector3.BACK
	if normal.dot(_camera_rest.origin - midpoint) < 0.0: normal = -normal
	var aspect := maxf(.1, view.size.x / maxf(1, view.size.y))
	# Pull back partway on tighter lenses, keeping the hit readable on large hulls.
	var half_angle := deg_to_rad(lerpf(settings.beam_fov, settings.cinematic_fov, .5) * .5)
	var horizontal := half_angle if camera.keep_aspect == Camera3D.KEEP_WIDTH else atan(tan(half_angle) * aspect)
	var vertical := atan(tan(half_angle) / aspect) if camera.keep_aspect == Camera3D.KEEP_WIDTH else half_angle
	var radius: float = maxf(_bounds[actor].radius, _bounds[victim].radius)
	var half_gap := attacker_center.distance_to(victim_center) * .5
	# Fit the focused hull. The opposing hull can fall off the edge during the turn.
	var focus_distance: float = radius * settings.framing_margin / sin(minf(horizontal, vertical))
	var distance := maxf(half_gap * .95, sqrt(maxf(0.0, focus_distance * focus_distance - half_gap * half_gap)))
	var lift := Vector3.UP.slide(axis)
	var position := midpoint + (normal + lift * .18).normalized() * distance
	var pose := Transform3D(Basis.IDENTITY, position)
	_beam_victim_pose = pose.looking_at(midpoint.lerp(victim_center, .94), Vector3.UP)
	_set_camera(pose.looking_at(midpoint.lerp(attacker_center, .94), Vector3.UP), settings.beam_fov)
	_charge_glow = MeshInstance3D.new()
	_charge_glow.mesh = QuadMesh.new()
	_charge_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.no_depth_test = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .24, .55, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(.35, .82, 1, .9), Color(.12, .45, 1, .40), Color.TRANSPARENT])
	var glow := GradientTexture2D.new()
	glow.width = 48
	glow.height = 48
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(.5, .5)
	glow.fill_to = Vector2(1, .5)
	material.albedo_texture = glow
	_charge_glow.material_override = material
	actor.add_child(_charge_glow)
	_charge_glow.global_position = ImportedVFX.beam_origin(actor)
	var size: float = clampf(_bounds[actor].radius * .72, .36, 1.2)
	_charge_glow.scale = Vector3.ONE * size * .15
	motion = create_tween()
	motion.tween_method(func(progress: float):
		_charge_glow.scale = Vector3.ONE * size * lerpf(.15, 1.0, progress)
		material.albedo_color = Color(.06, .40, .95, .30).lerp(Color(.65, .90, 1, .85), progress),
		0.0, 1.0, settings.duration(settings.beam_charge_seconds))
	motion.tween_callback(settled.emit)
	Sound.play(&"emp_charge", self)
	_stage("beam_charge")
	if active and token == revision:
		await settled


func beam_launched() -> void:
	if not active or skipped or stage != "beam_charge": return
	_clear_charge()
	var from := camera.global_transform
	motion = create_tween()
	motion.tween_method(
		func(progress: float): _set_camera(from.interpolate_with(_beam_victim_pose, progress), settings.beam_fov),
		0.0, 1.0, settings.duration(settings.beam_turn_seconds)
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_stage("beam_turn")


func beam_impact() -> void:
	if not active: return
	if stage == "beam_charge":
		# Battle VFX may have been turned off during the charge.
		_finish()
		return
	if stage != "beam_turn": return
	if motion and motion.is_valid(): motion.kill()
	_set_camera(_beam_victim_pose, settings.beam_fov)
	_impact_hold = create_tween()
	_impact_hold.tween_interval(settings.duration(settings.beam_impact_hold))
	_impact_hold.tween_callback(settled.emit)
	_stage("impact_hold")


func finish_beam(destruction: bool) -> void:
	if not active or kind != "heavy_beam": return
	if destruction:
		kind = "destruction"
		_stage("destruction_hold")
		return
	var token := revision
	if _impact_hold and _impact_hold.is_running():
		await settled
	if token == revision: _finish()


func _clear_charge() -> void:
	if is_instance_valid(_charge_glow):
		_charge_glow.hide()
		_charge_glow.queue_free()
		_charge_glow = null


func attack(actor: Node3D, victim: Node3D, destruction: bool, hold_for_vfx: bool) -> void:
	if not allowed() or (active and kind == "destruction"):
		return
	var token := _begin("destruction" if destruction else "heavy_beam", false)
	external_destruction = destruction and hold_for_vfx
	_stage("attacker")
	if token != revision or not active:
		return
	var a := _pose(actor if actor != null else victim, settings.attacker_offset)
	var b := _pose(victim, settings.victim_offset)
	_set_camera(a, settings.cinematic_fov)
	_stage("impact_pan")
	if token != revision or not active:
		return
	await _move(a, b, settings.attack_seconds * .65, settings.cinematic_fov, settings.cinematic_fov)
	if token != revision or not active:
		return
	if skipped:
		_finish()
		return
	_stage("impact_hold")
	if external_destruction:
		return
	await _move(b, b, settings.attack_seconds * .35, settings.cinematic_fov, settings.cinematic_fov)
	if token == revision:
		_finish()


func release_destruction() -> void:
	if active and kind == "destruction":
		_finish()


func departure(transition: CanvasLayer) -> bool:
	var token := _begin("departure", true)
	_transition = transition
	_boost_body = player.get_node("Body")
	_body_rest = _boost_body.position
	_boost_shield = player.get_node("Shield")
	_shield_rest = _boost_shield.position
	_engine_rest = player.engine_boost
	if allowed():
		_stage("victory_orbit")
		if token != revision or not active:
			return false
		if not skipped:
			var offset: Vector3 = settings.orbit_offset
			motion = create_tween()
			(
				motion
				. tween_method(
					func(p: float):
						_set_camera(
							_pose(
								player,
								offset.rotated(Vector3.UP, deg_to_rad(settings.orbit_degrees) * p)
							),
							settings.cinematic_fov
						),
					0.0,
					1.0,
					settings.duration(settings.orbit_seconds)
				)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
			motion.tween_callback(settled.emit)
			await settled
	if token != revision or not active:
		return false
	if allowed() and not skipped:
		player.engine_boost = true
		motion = create_tween()
		motion.tween_interval(settings.duration(settings.engine_charge_seconds))
		motion.tween_callback(settled.emit)
		_stage("engine_charge")
		if token != revision or not active:
			return false
		if not skipped:
			await settled
	if token != revision or not active:
		return false
	if allowed() and not skipped:
		motion = create_tween()
		motion.tween_method(
			func(progress: float):
				var displacement: Vector3 = Vector3.RIGHT * settings.boost_distance * progress * (.28 + .72 * progress * progress)
				_boost_body.position = _body_rest + displacement
				_boost_shield.position = _shield_rest + displacement,
			0.0, 1.0, settings.duration(settings.boost_seconds)
		)
		motion.tween_callback(settled.emit)
		_stage("engine_boost")
		if token != revision or not active:
			return false
		if not skipped:
			await settled
	if token != revision or not active:
		return false
	_stage("fade_to_black")
	if token != revision or not active:
		return false
	await transition.fade(1.0, settings.duration(settings.fade_seconds))
	var covered: bool = token == revision and transition.curtain.color.a >= .999
	_transition = null
	if token == revision:
		_finish()
	return covered


func emp_victory(seed_value: int) -> void:
	if not allowed(): return
	var token := _begin("emp", false)
	emp_effect = EMP.new()
	player.get_parent().add_child(emp_effect)
	emp_effect.setup(_center(player), _bounds[player].radius, enemy, _center(enemy), _bounds[enemy].radius, seed_value)
	var seconds: Vector3 = settings.emp_seconds
	motion = create_tween().set_ignore_time_scale(true)
	motion.tween_method(func(progress: float): emp_effect.charge(progress, camera), 0.0, 1.0, maxf(0.01, seconds.x))
	motion.tween_callback(func():
		emp_effect.discharge()
		_stage("emp_discharge"))
	motion.tween_method(func(progress: float): emp_effect.expand(progress), 0.0, 1.0, maxf(0.01, seconds.y))
	motion.tween_callback(func():
		emp_effect.drift(0.0)
		_stage("emp_drift"))
	motion.tween_method(func(progress: float): emp_effect.drift(progress), 0.0, 1.0, maxf(0.01, seconds.z))
	motion.tween_callback(func():
		enemy.hide()
		_finish())
	_stage("emp_charge")
	if active and token == revision: await settled


func skip() -> void:
	if not active:
		return
	skipped = true
	if motion and motion.is_valid():
		motion.kill()
	if kind == "departure" and is_instance_valid(_transition) and _transition.curtain.visible:
		_transition.curtain.color.a = 1.0
		_transition.cancel(false)
	if kind == "emp":
		_finish()
		return
	settled.emit()
	if active and kind != "departure":
		_finish()


func _finish() -> void:
	if not active:
		return
	if motion and motion.is_valid():
		motion.kill()
	if _impact_hold and _impact_hold.is_valid():
		_impact_hold.kill()
	_clear_charge()
	if is_instance_valid(emp_effect):
		emp_effect.restore_power()
		emp_effect.hide()
		emp_effect.queue_free()
		emp_effect = null
	active = false
	view.offset_bottom = _view_bottom
	camera.global_transform = _camera_rest
	camera.fov = default_fov
	backdrop.transform = _backdrop_rest
	backdrop.scale = default_backdrop_scale
	if is_instance_valid(_boost_body):
		_boost_body.position = _body_rest
		player.engine_boost = _engine_rest
	if is_instance_valid(_boost_shield):
		_boost_shield.position = _shield_rest
	_boost_shield = null
	_boost_body = null
	for node in _ui:
		if is_instance_valid(node):
			node.visible = _ui[node]
	_ui.clear()
	_intro_caption.hide()
	_skip_layer.hide()
	_backfill.hide()
	if _focus_rest != null:
		var focused = _focus_rest.get_ref()
		if is_instance_valid(focused) and focused.is_inside_tree() and focused.is_visible_in_tree():
			focused.grab_focus()
	_focus_rest = null
	settled.emit()


func cancel() -> void:
	revision += 1
	_finish()
	settled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if active and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept")):
		skip()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	exiting = true
	cancel()
