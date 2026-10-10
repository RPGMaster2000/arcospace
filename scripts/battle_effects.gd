extends Node

# RESPONSIBILITY: Animate actual stat changes without modifying game state.
# DOES NOT: Apply card rules, draw cards or advance turns.
signal finished
const REPAIR_SHADER = preload("res://shaders/hull_repair.gdshader")
const RIPPLE_SHADER = preload("res://shaders/shield_ripple.gdshader")
const RESOURCES = ["materials", "energy", "crew"]
const PRODUCTION = ["synthesizer", "reactor", "quarters"]
const COLORS = [Color(1, 0.35, 0.2), Color(0.25, 0.8, 1), Color(0.5, 1, 0.3)]
@export var enabled: bool = true
# Optional presentation targets; defaults preserve the original 2D board.
@export var player_ship_path: NodePath = NodePath("PlayerShip")
@export var enemy_ship_path: NodePath = NodePath("EnemyShip")
@export_range(0.02, 0.15, 0.005) var count_step_seconds: float = 0.035
@export_range(0.1, 2.0, 0.05) var hit_seconds: float = 0.3
@export_range(0.1, 2.0, 0.05) var production_seconds: float = 0.28
@export_range(0.2, 3.0, 0.05) var repair_seconds: float = 1.0
@export_range(0.2, 3.0, 0.05) var shield_seconds: float = 0.55
@export_range(0.0, 12.0, 0.5) var shake_pixels: float = 4.0
@export_range(1.0, 1.2, 0.01) var icon_peak_scale: float = 1.07
var busy: bool = false
var cancelling: bool = false
var jobs: int = 0
var counters: Dictionary = {}
var tweens: Array[Tween] = []
var restorations: Array[Callable] = []
var temporary_nodes: Array[Node] = []

func set_number(label: Label, value: int) -> void:
	if not counters.has(label):
		label.text = str(value)


func play_changes(before: Dictionary, after: Dictionary, paid_side: String = "", paid_family: String = "", paid_cost: int = 0, impact: bool = false) -> void:
	if not enabled:
		return
	for side in ["player", "enemy"]:
		var old: Dictionary = before[side]
		var current: Dictionary = after[side]
		var prefix: String = "Player" if side == "player" else "Enemy"
		var ship: Node = get_parent().get_node(player_ship_path if side == "player" else enemy_ship_path)
		var hull_delta: int = current.hull - old.hull
		var shield_delta: int = current.shields - old.shields
		if hull_delta < 0 and current.shields == 0 and ship.has_method("animate_explosions"):
			ship.animate_explosions(_job(), maxf(hit_seconds, 0.5))
		if hull_delta < 0 or (shield_delta < 0 and impact):
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
			var effect_delta: int = delta + (paid_cost if side == paid_side and key == paid_family else 0)
			if delta > 0 or (delta < 0 and effect_delta < 0):
				_count(icon.get_node(key), old[key], current[key])
			if delta > 0:
				_resource_burst(icon, COLORS[index], false)
			if effect_delta < 0:
				_pulse_icon(icon, COLORS[index], false)
			var production_delta: int = current[PRODUCTION[index]] - old[PRODUCTION[index]]
			if production_delta > 0:
				_resource_burst(icon, COLORS[index], true)
			if production_delta != 0:
				_pulse_icon(icon, COLORS[index], production_delta > 0)


# Draw behind the icon/badge; the effect owns no input or game state.
func _resource_burst(icon: Control, tint: Color, production: bool) -> void:
	var burst := ColorRect.new()
	burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	burst.show_behind_parent = true
	var badge: Control = icon.get_node("ProductionBadge")
	burst.size = Vector2(155, 24) if production else Vector2(110, 80)
	burst.position = badge.position + badge.size * 0.5 - burst.size * 0.5 if production else Vector2(-22, 32)
	icon.add_child(burst)
	icon.move_child(burst, 0)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/resource_burst.gdshader")
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("beam", production)
	burst.material = material
	_run_material(burst, material, 0.32 if production else 0.4)

func _job() -> Tween:
	busy = true
	jobs += 1
	var tween: Tween = create_tween()
	tweens.append(tween)
	tween.finished.connect(func():
		jobs -= 1
		tweens.erase(tween)
		if jobs == 0:
			busy = false
			restorations.clear()
			finished.emit(), CONNECT_ONE_SHOT)
	return tween


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
	tween.parallel().tween_property(icon, "modulate", tint.lightened(0.35) if increase else tint.darkened(0.3), production_seconds * 0.45)
	tween.tween_property(icon, "scale", original_scale, production_seconds * 0.55)
	tween.parallel().tween_property(icon, "modulate", original_color, production_seconds * 0.55)
	tween.tween_callback(restore)


func _hit(ship: Node, hull_hit: bool, shield_hit: bool, side: String) -> void:
	if ship.has_method("animate_hit"):
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
	tween.tween_method(func(p: float):
		ship.position = origin + Vector2(sin(p * TAU * 3), sin(p * TAU * 4) * 0.4) * shake_pixels * (1.0 - p)
		if hull_hit:
			hull.color = hull_color.lerp(Color(1, 0.12, 0.08), sin(p * PI)), 0.0, 1.0, hit_seconds)
	tween.tween_callback(restore)
	if shield_hit:
		_pulse_shield(ship, false)
		var shield: Line2D = ship.get_node("ShieldPlaceholder")
		var bounds: Rect2 = _bounds(shield.points)
		var arc := Line2D.new()
		arc.width = 7
		arc.default_color = Color(0.65, 0.93, 1)
		arc.antialiased = true
		var angle: float = 0.0 if side == "player" else PI
		for i in range(17):
			var a: float = angle - 0.5 + i / 16.0
			arc.add_point(bounds.get_center() + Vector2(cos(a), sin(a)) * bounds.size * 0.5)
		ship.add_child(arc)
		temporary_nodes.append(arc)
		var flash := _job()
		flash.tween_property(arc, "modulate:a", 0.0, hit_seconds)
		flash.parallel().tween_property(arc, "width", 1.0, hit_seconds)
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
	tween.tween_method(func(p: float):
		var pulse: float = sin(p * PI * 6) * (1.0 - p)
		shield.scale = size_before * (1.0 + pulse * 0.035)
		shield.modulate = tint_before.lerp(Color(1.6, 1.8, 2.0), absf(pulse)), 0.0, 1.0, shield_seconds)
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


func _material_effect(node: CanvasItem, shader: Shader, duration: float) -> void:
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	_run_material(node, material, duration)


func _run_material(node: CanvasItem, material: ShaderMaterial, duration: float) -> void:
	temporary_nodes.append(node)
	var tween := _job()
	tween.tween_method(func(p: float): material.set_shader_parameter("progress", p), 0.0, 1.0, duration)
	tween.tween_callback(func(): _remove(node))


func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _remove(node: Node) -> void:
	temporary_nodes.erase(node)
	node.queue_free()


func _exit_tree() -> void:
	cancelling = true
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
