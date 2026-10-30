extends Node

const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const ImportedVFX = preload("res://scripts/effects/imported_combat_vfx.gd")
const BEAM_SECONDS: float = 0.45
var imported_nodes: Array[Node] = []
var active_beam: Node3D
# Buffer presentation while the card covers the ships. Gameplay callbacks run normally.
var card_covers_ships: bool = false
var card_presentation_elapsed: float = 0.0
var card_presentation_delay: float = 0.0
var card_presentations: Array[Dictionary] = []

func defer_card_presentation() -> void:
	card_covers_ships = true
	card_presentation_elapsed = 0.0
	card_presentation_delay = 0.0

func _process(delta: float) -> void:
	if card_covers_ships: card_presentation_elapsed += delta

func reveal_card_presentation() -> void:
	if not card_covers_ships: return
	card_covers_ships = false
	card_presentation_delay = card_presentation_elapsed
	for event in card_presentations:
		_schedule_presentation(event.action, event.offset)
	card_presentations.clear()

func end_card_presentation() -> void:
	card_covers_ships = false
	card_presentation_delay = 0.0
	card_presentations.clear()

func _schedule_presentation(action: Callable, delay: float) -> void:
	if delay <= 0.0:
		action.call()
	else:
		var timeline := _job()
		timeline.tween_interval(delay)
		timeline.tween_callback(action)

func _defer_presentation(action: Callable) -> bool:
	if card_covers_ships:
		card_presentations.append({"action": action, "offset": card_presentation_elapsed})
		return true
	if card_presentation_delay > 0.0:
		# Overflow arriving after a very short card exit gets the same visual shift.
		_schedule_presentation(action, card_presentation_delay)
		return true
	return false

const Sound = preload("res://scripts/audio/sfx.gd")

# RESPONSIBILITY: Animate actual stat changes without modifying game state.
# DOES NOT: Apply card rules, draw cards or advance turns.
# EXTEND: Dispatch committed deltas in play_changes; register all independent tweens with _job.
signal finished
@export var visual_settings: Resource = preload("res://resources/visual/alpha_visual_settings.tres")
const REPAIR_SHADER = preload("res://shaders/hull_repair.gdshader")
const RIPPLE_SHADER = preload("res://shaders/shield_ripple.gdshader")
const RESOURCES = preload("res://scripts/combat/ship_combat_state.gd").RESOURCES
const PRODUCTION = preload("res://scripts/combat/ship_combat_state.gd").PRODUCTION
const COLORS = [Color(1, 0.35, 0.2), Color(0.25, 0.8, 1), Color(0.5, 1, 0.3)]
## TUNE: Set false to skip stat-change animations.
@export var enabled: bool = true
## Experimental imported hull-hit flash; disable for a direct performance comparison.
@export var imported_hits_enabled: bool = true
# Optional presentation targets; defaults preserve the original 2D board.
@export var player_ship_path: NodePath = NodePath("PlayerShip")
@export var enemy_ship_path: NodePath = NodePath("EnemyShip")
## TUNE: Seconds between each integer when resources count up; smaller = faster.
var count_step_seconds: float:
	get:
		return visual_settings.count_step_seconds
## TUNE: Seconds for ship hit/recoil feedback.
var hit_seconds: float:
	get:
		return visual_settings.hit_seconds
## TUNE: Seconds for the production icon pulse.
var production_seconds: float:
	get:
		return visual_settings.production_seconds
## TUNE: Seconds for the hull repair sweep.
var repair_seconds: float:
	get:
		return visual_settings.repair_seconds
## TUNE: Seconds for shield activation/upgrade; 3D hit ripples are capped at 0.28 seconds.
var shield_seconds: float:
	get:
		return visual_settings.shield_seconds
## TUNE: 2D ship shake distance in pixels; this does not change 3D recoil.
var shake_pixels: float:
	get:
		return visual_settings.shake_pixels
## TUNE: Icon pulse size; 1.07 = 7% larger.
var icon_peak_scale: float:
	get:
		return visual_settings.icon_peak_scale
var shatter_updates: Array[Callable] = []
var busy: bool = false
var cancelling: bool = false
var jobs: int = 0
var counters: Dictionary = {}
var tweens: Array[Tween] = []
var restorations: Array[Callable] = []
var temporary_nodes: Array[Node] = []

func _ready() -> void:
	Preferences.events.battle_vfx_changed.connect(_battle_vfx_changed)


func _battle_vfx_changed(value: bool) -> void:
	if value: return
	for node in imported_nodes.duplicate():
		if is_instance_valid(node):
			node.hide()
			_remove(node)
	# Keep registered jobs alive: toggling presentation must not change turn timing.


func play_direct_damage(side: String) -> void:
	if _defer_presentation(_play_direct_damage.bind(side)): return
	_play_direct_damage(side)

func fire_before_impact(side: String) -> void:
	# Await the single weapon cue; the caller commits combat state at contact.
	var shot: Tween = _play_direct_damage(side)
	if shot != null:
		await shot.finished


func _play_direct_damage(side: String) -> Tween:
	if not enabled or cancelling: return null
	var actor = get_parent().get_node(player_ship_path if side == "player" else enemy_ship_path)
	var target = get_parent().get_node(enemy_ship_path if side == "player" else player_ship_path)
	if not actor is Node3D or not target is Node3D: return null
	# Same timeline with VFX on/off; normally shorter than existing hit feedback.
	var timeline := _job()
	if not Preferences.battle_vfx():
		timeline.tween_interval(BEAM_SECONDS)
		return timeline
	if is_instance_valid(active_beam):
		active_beam.hide()
		_remove(active_beam)
	var beam: Node3D = ImportedVFX.beam(actor, target)
	active_beam = beam
	temporary_nodes.append(beam)
	imported_nodes.append(beam)
	var reference: WeakRef = weakref(beam)
	timeline.tween_method(func(progress: float):
		var current = reference.get_ref()
		if current != null and not current.is_queued_for_deletion():
			ImportedVFX.update_beam(current, actor, target, progress), 0.0, 1.0, BEAM_SECONDS)
	timeline.tween_callback(func():
		var current = reference.get_ref()
		if current != null: _remove(current))
	return timeline


#region Delta dispatch


func set_number(label: Label, value: int) -> void:
	if not counters.has(label):
		label.text = str(value)


# Compare committed snapshots to schedule visuals; these deltas must never be applied to gameplay again.
func play_changes(
	before: Dictionary,
	after: Dictionary,
	paid_side: String = "",
	paid_family: String = "",
	paid_cost: int = 0,
	impact: bool = false,
	external_timeline: bool = false
) -> void:
	# Capture committed snapshots now, never read a later state when the card leaves.
	if _defer_presentation(_play_changes.bind(before.duplicate(true), after.duplicate(true), paid_side, paid_family, paid_cost, impact, false)):
		# The existing damage timeline continues committing overflow on its original cue.
		# Buffered shatter visuals use their own existing BattleEffects tween afterwards.
		shatter_updates = []
		return
	_play_changes(before, after, paid_side, paid_family, paid_cost, impact, external_timeline)

func _play_changes(
	before: Dictionary, after: Dictionary, paid_side: String, paid_family: String,
	paid_cost: int, impact: bool, external_timeline: bool
) -> void:
	shatter_updates = []
	if not enabled:
		return
	for side in ["player", "enemy"]:
		var old: Dictionary = before[side]
		var current: Dictionary = after[side]
		var prefix: String = "Player" if side == "player" else "Enemy"
		var ship: Node = get_parent().get_node(
			player_ship_path if side == "player" else enemy_ship_path
		)
		var hull_delta: int = current.hull - old.hull
		var shield_delta: int = current.shields - old.shields
		if hull_delta < 0:
			Sound.play(&"ship_destroyed" if current.hull <= 0 and old.hull > 0 else &"hull_hit", self)
		elif hull_delta > 0:
			Sound.play(&"hull_repair", self)
		if shield_delta < 0:
			Sound.play(&"shield_break" if old.shields > 0 and current.shields == 0 else &"shield_hit", self)
		if (
			hull_delta < 0
			and (current.shields == 0 or get_parent().modifier.shields_disabled())
			and ship.has_method("animate_explosions")
		):
			ship.animate_explosions(_job(), maxf(hit_seconds, 0.5))
		var collapse: bool = (
			old.shields > 0
			and current.shields == 0
			and visual_settings.shield_shatter.shatter_enabled
			and not get_parent().modifier.shields_disabled()
		)
		if collapse:
			if ship.has_method("begin_shield_shatter"):
				shatter_updates.append(ship.begin_shield_shatter(visual_settings.shield_shatter))
			var feedback = get_parent().get_node_or_null("ModifierDisplay")
			if feedback != null:
				feedback.shake_screen(
					visual_settings.shield_shatter.shatter_shake_strength * 25.0,
					visual_settings.shield_shatter.shatter_shake_duration
				)
			if hull_delta < 0:
				_hit(ship, true, false, side)
		elif hull_delta < 0 or (shield_delta < 0 and impact):
			_hit(ship, hull_delta < 0, shield_delta < 0, side)
		elif shield_delta < 0:
			_pulse_shield(ship, false)
		if hull_delta > 0:
			_repair(ship)
		if shield_delta > 0:
			if ship.has_method("animate_shield"):
				ship.shield_was_offline = old.shields <= 0
			_pulse_shield(ship, true)
		for index in range(3):
			var key: String = RESOURCES[index]
			var icon: Control = get_parent().get_node(prefix + "Resource%d" % (index + 1))
			var delta: int = current[key] - old[key]
			# Ordinary payment is not a hostile resource-drain effect.
			var effect_delta: int = (
				delta + (paid_cost if side == paid_side and key == paid_family else 0)
			)
			if delta > 0 or (delta < 0 and effect_delta < 0):
				_count(icon.get_node(key), old[key], current[key])
			if delta > 0:
				Sound.play([&"materials_gain", &"energy_gain", &"crew_gain"][index], self)
				_resource_burst(icon, COLORS[index], false)
			if effect_delta < 0:
				Sound.play(&"resource_drain", self)
				_pulse_icon(icon, COLORS[index], false)
			var production_delta: int = current[PRODUCTION[index]] - old[PRODUCTION[index]]
			if production_delta > 0:
				_resource_burst(icon, COLORS[index], true)
			if production_delta != 0:
				Sound.play(&"production_gain" if production_delta > 0 else &"production_loss", self)
				_pulse_icon(icon, COLORS[index], production_delta > 0)

	if not shatter_updates.is_empty():
		var updates: Array[Callable] = shatter_updates.duplicate()
		var duration: float = maxf(
			visual_settings.shield_shatter.shatter_burst_start + 0.01,
			visual_settings.shield_shatter.shatter_total_duration
		)
		var timeline = _job()
		if external_timeline:
			timeline.tween_interval(duration)
		else:
			timeline.tween_method(
				func(time: float):
					for update in updates:
						if update.is_valid():
							update.call(time),
				0.0,
				duration,
				duration
			)


#endregion

#region Resource feedback


# Draw behind the icon/badge; the effect owns no input or game state.
func _resource_burst(icon: Control, tint: Color, production: bool) -> void:
	var burst := ColorRect.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.show_behind_parent = true
	var badge: Control = icon.get_node("ProductionBadge")
	burst.size = Vector2(155, 24) if production else Vector2(110, 80)
	burst.position = (
		badge.position + badge.size * 0.5 - burst.size * 0.5 if production else Vector2(-22, 32)
	)
	icon.add_child(burst)
	icon.move_child(burst, 0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/resource_burst.gdshader")
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("beam", production)
	burst.material = material
	_run_material(burst, material, 0.32 if production else 0.4)


func _count(label: Label, start: int, target: int) -> void:
	counters[label] = true
	label.text = str(start)
	var tween := _job()
	var step: int = 1 if target > start else -1
	# One callback per integer: no interpolation that skips intermediate values.
	for value in range(start + step, target + step, step):
		tween.tween_interval(count_step_seconds)
		tween.tween_callback(func(): label.text = str(value))
	tween.tween_callback(func(): counters.erase(label))


func _pulse_icon(icon: Control, tint: Color, increase: bool) -> void:
	var original_scale: Vector2 = icon.scale
	var original_color: Color = icon.modulate
	var pivot: Vector2 = icon.pivot_offset
	icon.pivot_offset = icon.size * 0.5
	var restore := func():
		if is_instance_valid(icon):
			icon.scale = original_scale
			icon.modulate = original_color
			icon.pivot_offset = pivot
	restorations.append(restore)
	var tween := _job()
	var peak: float = icon_peak_scale if increase else 2.0 - icon_peak_scale
	tween.tween_property(icon, "scale", original_scale * peak, production_seconds * 0.45)
	tween.parallel().tween_property(
		icon,
		"modulate",
		tint.lightened(0.35) if increase else tint.darkened(0.3),
		production_seconds * 0.45
	)
	tween.tween_property(icon, "scale", original_scale, production_seconds * 0.55)
	tween.parallel().tween_property(icon, "modulate", original_color, production_seconds * 0.55)
	tween.tween_callback(restore)


#endregion

#region Ship feedback


func _hit(ship: Node, hull_hit: bool, shield_hit: bool, side: String) -> void:
	if shield_hit:
		var feedback = get_parent().get_node_or_null("ModifierDisplay")
		if feedback != null:
			feedback.shake_screen(
				visual_settings.shield_screen_shake_pixels,
				visual_settings.shield_screen_shake_duration
			)
	if ship.has_method("animate_hit"):
		if hull_hit and imported_hits_enabled and Preferences.battle_vfx() and ship is Node3D:
			var effect: Node3D = preload("res://scripts/effects/imported_combat_vfx.gd").hull_hit(ship, hit_seconds)
			temporary_nodes.append(effect)
			imported_nodes.append(effect)
			var reference: WeakRef = weakref(effect)
			_job().tween_interval(hit_seconds).finished.connect(func():
				var current = reference.get_ref()
				if current != null: _remove(current))
		ship.animate_hit(_job(), hull_hit, hit_seconds)
		if shield_hit:
			_pulse_shield(ship, false)
		return
	var origin: Vector2 = ship.position
	var hull: Polygon2D = ship.get_node("HullPlaceholder")
	var hull_color: Color = hull.color
	var restore := func():
		if is_instance_valid(ship):
			ship.position = origin
			hull.color = hull_color
	restorations.append(restore)
	var tween := _job()
	tween.tween_method(
		func(p: float):
			ship.position = (
				origin
				+ (
					Vector2(sin(p * TAU * 3), sin(p * TAU * 4) * 0.4)
					* (shake_pixels if hull_hit else 0.0)
					* (1.0 - p)
				)
			)
			if hull_hit:
				hull.color = hull_color.lerp(
					visual_settings.hull_flash_color,
					(
						sin(minf(1.0, p * hit_seconds / visual_settings.hull_flash_duration) * PI)
						* visual_settings.hull_flash_opacity
					)
				),
		0.0,
		1.0,
		hit_seconds
	)
	tween.tween_callback(restore)
	if shield_hit:
		_pulse_shield(ship, false)
		var shield: Line2D = ship.get_node("ShieldPlaceholder")
		var bounds: Rect2 = _bounds(shield.points)
		var arc := Line2D.new()
		arc.width = 7
		arc.default_color = Color(
			visual_settings.shield_impact_color, visual_settings.shield_flash_opacity
		)
		arc.antialiased = true
		var angle: float = 0.0 if side == "player" else PI
		for i in range(17):
			var a: float = angle - 0.5 + i / 16.0
			arc.add_point(bounds.get_center() + Vector2(cos(a), sin(a)) * bounds.size * 0.5)
		ship.add_child(arc)
		temporary_nodes.append(arc)
		var flash := _job()
		flash.tween_property(
			arc, "modulate:a", 0.0, minf(hit_seconds, visual_settings.shield_flash_duration)
		)
		flash.parallel().tween_property(
			arc, "width", 1.0, minf(hit_seconds, visual_settings.shield_flash_duration)
		)
		flash.tween_callback(func(): _remove(arc))


func _pulse_shield(ship: Node, increase: bool) -> void:
	if ship.has_method("animate_shield"):
		ship.animate_shield(_job(), shield_seconds, increase)
		return
	var shield: Line2D = ship.get_node("ShieldPlaceholder")
	var size_before: Vector2 = shield.scale
	var tint_before: Color = shield.modulate
	var restore := func():
		if is_instance_valid(shield):
			shield.scale = size_before
			shield.modulate = tint_before
	restorations.append(restore)
	var tween := _job()
	tween.tween_method(
		func(p: float):
			var pulse: float = sin(p * PI * 6) * (1.0 - p)
			shield.scale = size_before * (1.0 + pulse * 0.035)
			shield.modulate = tint_before.lerp(Color(1.6, 1.8, 2.0), absf(pulse)),
		0.0,
		1.0,
		shield_seconds
	)
	tween.tween_callback(restore)
	if increase:
		var bounds: Rect2 = _bounds(shield.points)
		var ripple := ColorRect.new()
		ripple.position = bounds.position
		ripple.size = bounds.size
		ripple.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ship.add_child(ripple)
		_material_effect(ripple, RIPPLE_SHADER, shield_seconds)


func _repair(ship: Node) -> void:
	if ship.has_method("animate_repair"):
		ship.animate_repair(_job(), repair_seconds)
		return
	var hull: Polygon2D = ship.get_node("HullPlaceholder")
	var wash := Polygon2D.new()
	wash.polygon = hull.polygon
	wash.transform = hull.transform
	ship.add_child(wash)
	var material := ShaderMaterial.new()
	material.shader = REPAIR_SHADER
	var bounds: Rect2 = _bounds(hull.polygon)
	material.set_shader_parameter("lower_y", bounds.end.y)
	material.set_shader_parameter("upper_y", bounds.position.y)
	wash.material = material
	_run_material(wash, material, repair_seconds)


#endregion

#region Tween lifecycle


# Register a presentation tween so Board can await finished only after every visual job completes.
func _job() -> Tween:
	busy = true
	jobs += 1
	var tween: Tween = create_tween()
	tweens.append(tween)
	tween.finished.connect(
		func():
			jobs -= 1
			tweens.erase(tween)
			if jobs == 0:
				busy = false
				restorations.clear()
				finished.emit(),
		CONNECT_ONE_SHOT
	)
	return tween


func _material_effect(node: CanvasItem, shader: Shader, duration: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	_run_material(node, material, duration)


func _run_material(node: CanvasItem, material: ShaderMaterial, duration: float) -> void:
	temporary_nodes.append(node)
	var tween := _job()
	tween.tween_method(
		func(p: float): material.set_shader_parameter("progress", p), 0.0, 1.0, duration
	)
	tween.tween_callback(func(): _remove(node))


func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _remove(node: Node) -> void:
	temporary_nodes.erase(node)
	imported_nodes.erase(node)
	node.queue_free()


func _exit_tree() -> void:
	cancelling = true
	end_card_presentation()
	for tween in tweens:
		tween.kill()
	for restore in restorations:
		restore.call()
	for node in temporary_nodes:
		if is_instance_valid(node):
			node.queue_free()
	counters.clear()
	busy = false
	finished.emit()

#endregion
