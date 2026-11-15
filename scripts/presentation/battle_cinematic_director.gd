extends Node
## One camera owner; no combat, reward, RNG or expedition-state references.
## Existing scene nodes are borrowed, never cloned. All edits are restored on exit.
signal settled
signal stage_changed(stage: String)
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
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
var _boost_body: Node3D
var _body_rest := Vector3.ZERO
var _engine_rest := false
var _focus_rest: WeakRef
var _transition: CanvasLayer


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
	_skip_layer.hide()


func _measure(ship: Node3D) -> Dictionary:
	var bounds := AABB()
	var first := true
	for mesh in ship.get_node("Body").find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i in range(8):
			var point: Vector3 = ship.to_local(
				mesh.global_transform * mesh.mesh.get_aabb().get_endpoint(i)
			)
			if first:
				bounds = AABB(point, Vector3.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	var scale: Vector3 = ship.global_basis.get_scale()
	return {
		"center": bounds.get_center(),
		"radius": maxf(.5, bounds.size.length() * .5 * maxf(scale.x, maxf(scale.y, scale.z)))
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
	skip_button.grab_focus()
	return revision


func mask_ui() -> void:
	if not active:
		return
	for node in _ui:
		if is_instance_valid(node):
			node.hide()


func _set_camera(pose: Transform3D, fov: float) -> void:
	camera.global_transform = pose
	camera.fov = fov
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
	from: Transform3D, to: Transform3D, seconds: float, from_fov: float, to_fov: float
) -> void:
	motion = create_tween()
	(
		motion
		. tween_method(
			func(p: float): _set_camera(from.interpolate_with(to, p), lerpf(from_fov, to_fov, p)),
			0.0,
			1.0,
			maxf(.001, seconds)
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	motion.tween_callback(settled.emit)
	await settled


func introduction() -> void:
	if not allowed():
		return
	var token := _begin("introduction", true)
	_stage("establishing")
	if token != revision or not active:
		return
	var a := _pose(enemy, settings.establishing_from)
	var b := _pose(enemy, settings.establishing_to)
	_set_camera(a, settings.cinematic_fov)
	await _move(
		a, b, settings.introduction_seconds.x, settings.cinematic_fov, settings.cinematic_fov
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
	var center := (_center(player) + _center(enemy)) * .5
	var radius := (
		player.global_position.distance_to(enemy.global_position) * .5
		+ maxf(_bounds[player].radius, _bounds[enemy].radius)
	)
	a = (
		Transform3D(
			Basis.IDENTITY,
			(
				center
				+ (
					Vector3(-.6, .5, 1).normalized()
					* radius
					/ sin(deg_to_rad(settings.cinematic_fov) * .5)
					* settings.framing_margin
				)
			)
		)
		. looking_at(center, Vector3.UP)
	)
	_set_camera(a, settings.cinematic_fov)
	motion = create_tween()
	(
		motion
		. tween_method(
			func(p: float):
				view.offset_bottom = lerpf(0, _view_bottom, p)
				var normal_height := maxf(1, board.size.y + _view_bottom)
				var adjusted := rad_to_deg(
					2 * atan(tan(deg_to_rad(default_fov) * .5) * view.size.y / normal_height)
				)
				_set_camera(
					a.interpolate_with(_camera_rest, p), lerpf(settings.cinematic_fov, adjusted, p)
				),
			0.0,
			1.0,
			maxf(.001, settings.introduction_seconds.z)
		)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_IN_OUT)
	)
	motion.tween_callback(settled.emit)
	await settled
	if token == revision:
		_finish()


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
					maxf(.001, settings.orbit_seconds)
				)
				. set_trans(Tween.TRANS_SINE)
				. set_ease(Tween.EASE_IN_OUT)
			)
			motion.tween_callback(settled.emit)
			await settled
	if token != revision or not active:
		return false
	var duration: float = settings.fade_seconds
	if allowed() and not skipped:
		_stage("engine_boost")
		if token != revision or not active:
			return false
		if not skipped:
			player.engine_boost = true
			var rest := camera.global_transform
			var forward := player.global_basis.x.normalized()
			motion = create_tween()
			motion.tween_method(
				func(p: float):
					_boost_body.position = (
						_body_rest + Vector3.RIGHT * settings.boost_distance * p * p
					)
					var pose := rest
					pose.origin += forward * settings.boost_distance * p * .08
					_set_camera(pose, settings.cinematic_fov + p * 3),
				0.0,
				1.0,
				maxf(.001, settings.boost_seconds)
			)
			duration = maxf(settings.fade_seconds, settings.boost_seconds)
	_stage("fade_to_black")
	if token != revision or not active:
		return false
	if skipped:
		duration = settings.fade_seconds
	await transition.fade(1.0, duration)
	var covered: bool = token == revision and transition.curtain.color.a >= .999
	_transition = null
	if token == revision:
		_finish()
	return covered


func skip() -> void:
	if not active:
		return
	skipped = true
	if motion and motion.is_valid():
		motion.kill()
	if kind == "departure" and is_instance_valid(_transition) and _transition.curtain.visible:
		_transition.curtain.color.a = 1.0
		_transition.cancel(false)
	settled.emit()
	if active and kind != "departure":
		_finish()


func _finish() -> void:
	if not active:
		return
	if motion and motion.is_valid():
		motion.kill()
	active = false
	view.offset_bottom = _view_bottom
	camera.global_transform = _camera_rest
	camera.fov = default_fov
	backdrop.transform = _backdrop_rest
	backdrop.scale = default_backdrop_scale
	if is_instance_valid(_boost_body):
		_boost_body.position = _body_rest
		player.engine_boost = _engine_rest
	_boost_body = null
	for node in _ui:
		if is_instance_valid(node):
			node.visible = _ui[node]
	_ui.clear()
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
