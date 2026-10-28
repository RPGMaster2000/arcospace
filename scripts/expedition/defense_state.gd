extends RefCounted
# Scene-free strategic authority. Units reference the existing encounter ledger.
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
var tuning: Resource
var home: Vector3
var start: Vector3
var anchors: Dictionary = {}
var units: Array[Dictionary] = []
var integrity: int = 100
var revealed: bool = false
var reveal_pending: bool = false
var complete: bool = false
var contact: int = -1
static func point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
static func wire(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func deploy(configuration: Resource, angle: float, indices: Array, poi_indices: Array) -> void:
	tuning = configuration
	integrity = tuning.base_integrity
	home = Vector3(cos(angle), 0, sin(angle)) * 20.0
	start = home * 0.78
	for i in range(3):
		var heading: float = angle + PI + 0.7 + (i - 1) * 0.26
		units.append({"encounter": indices[i], "position": Vector3(cos(heading), 0, sin(heading)) * tuning.hostile_spawn_distance,
			"status": "active", "mothership": i == 2})
	for i in poi_indices.size():
		var heading: float = angle + TAU * float(i) / maxi(1, poi_indices.size()) + 0.35
		anchors[poi_indices[i]] = Vector3(cos(heading), 0, sin(heading)) * (10.0 if i % 2 == 0 else 14.0)
func unit_for(index: int) -> Dictionary:
	for unit in units:
		if unit.encounter == index: return unit
	return {}
func mothership_index() -> int:
	for unit in units:
		if unit.mothership: return unit.encounter
	return -1
func available(unit: Dictionary) -> bool:
	return unit.status == "active" and (not unit.mothership or revealed) and not complete
func neutralized_attackers() -> int:
	var count: int = 0
	for unit in units:
		if not unit.mothership and unit.status == "neutralized": count += 1
	return count
# With no surviving attacker and no neutralization, the only reveal condition is
# permanently unreachable. Resolve that failed objective instead of soft-locking FTL.
func failed() -> bool:
	if integrity <= 0: return true
	if revealed or complete: return false
	for unit in units:
		if not unit.mothership and unit.status == "active": return false
	return true
func neutralize(index: int) -> bool:
	var unit: Dictionary = unit_for(index)
	if unit.is_empty() or not available(unit): return false
	unit.status = "neutralized"
	contact = -1
	if unit.mothership:
		complete = true
		for remaining in units:
			if remaining.status == "active": remaining.status = "secured"
	elif not revealed and neutralized_attackers() >= 1:
		revealed = true
		reveal_pending = true
	return true
# Earliest swept relative-sphere contact, independent of sample length/frame rate.
static func hit_time(relative: Vector3, velocity: Vector3, radius: float, limit: float) -> float:
	var c: float = relative.length_squared() - radius * radius
	if c <= 0: return 0.0
	var a: float = velocity.length_squared()
	if a < 0.000000001: return INF
	var b: float = 2.0 * relative.dot(velocity)
	var discriminant: float = b*b - 4*a*c
	if discriminant < 0: return INF
	var t: float = (-b - sqrt(discriminant)) / (2*a)
	return t if t >= 0 and t <= limit else INF
func advance(distance: float, from: Vector3, to: Vector3) -> Dictionary:
	var result: Dictionary = {"position": to, "contact": -1, "arrivals": 0}
	if complete or contact >= 0 or integrity <= 0 or distance <= 0 or not is_finite(distance): return result
	var duration: float = distance * tuning.seconds_per_distance
	var player_velocity: Vector3 = (to - from) / duration
	var elapsed: float = 0.0
	while elapsed < duration:
		var span: float = duration - elapsed
		var event_time: float = span
		var event_unit: Dictionary = {}
		var interception: bool = false
		for unit in units:
			if not available(unit): continue
			var velocity: Vector3 = Vector3.ZERO if unit.mothership else (home - unit.position).normalized() * tuning.enemy_speed
			var arrival: float = INF if unit.mothership or tuning.enemy_speed <= 0 else unit.position.distance_to(home) / tuning.enemy_speed
			var hit: float = hit_time(from + player_velocity * elapsed - unit.position, player_velocity - velocity, tuning.interception_radius, minf(span, arrival))
			if hit <= event_time:
				event_time = hit
				event_unit = unit
				interception = true
			elif arrival <= event_time:
				event_time = arrival
				event_unit = unit
				interception = false
		for unit in units:
			if available(unit) and not unit.mothership:
				unit.position = unit.position.move_toward(home, tuning.enemy_speed * event_time)
		elapsed += event_time
		if event_unit.is_empty(): break
		if interception:
			contact = event_unit.encounter
			result.contact = contact
			result.position = from + player_velocity * elapsed
			break
		event_unit.status = "arrived"
		integrity = maxi(0, integrity - tuning.base_attack_damage)
		result.arrivals += 1
		if failed():
			result.position = from + player_velocity * elapsed
			break
	return result
func snapshot() -> Dictionary:
	var data: Dictionary = {"home": wire(home), "start": wire(start), "integrity": integrity,
		"revealed": revealed, "reveal_pending": reveal_pending, "complete": complete, "contact": contact, "units": [], "anchors": {}}
	for unit in units:
		var copy: Dictionary = unit.duplicate()
		copy.position = wire(unit.position)
		data.units.append(copy)
	for index in anchors: data.anchors[str(index)] = wire(anchors[index])
	return data
func restore(data: Variant, configuration: Resource, encounters: Array) -> bool:
	if not data is Dictionary: return false
	if not Navigation.valid_point(data.get("home"), false) or not Navigation.valid_point(data.get("start"), false): return false
	for key in ["revealed", "reveal_pending", "complete"]:
		if not data.get(key) is bool: return false
	if not number(data.get("integrity"), 1, configuration.base_integrity): return false
	if not data.get("units") is Array or data.units.size() != 3 or not data.get("anchors") is Dictionary: return false
	var seen: Dictionary = {}
	var bosses: int = 0
	for unit in data.units:
		if not unit is Dictionary or not unit.get("mothership") is bool: return false
		if not number(unit.get("encounter"), 0, encounters.size()-1): return false
		var index: int = int(unit.encounter)
		if seen.has(index) or encounters[index].kind != "battle" or unit.get("status") not in ["active", "neutralized", "arrived", "secured"]: return false
		if not Navigation.valid_point(unit.get("position"), false): return false
		if absf(float(unit.position[0])) > 28 or absf(float(unit.position[2])) > 28: return false
		if unit.status == "secured" and not data.complete: return false
		if data.complete and unit.status == "active": return false
		if encounters[index].completed != (unit.status != "active"): return false
		if unit.mothership:
			bosses += 1
			if unit.status == "arrived" or data.complete != (unit.status == "neutralized"): return false
		seen[index] = true
	if bosses != 1 or not number(data.get("contact"), -1, encounters.size()-1): return false
	tuning = configuration
	home = point(data.home)
	start = point(data.start)
	integrity = int(data.integrity)
	revealed = data.revealed
	reveal_pending = data.reveal_pending
	complete = data.complete
	contact = int(data.contact)
	units.clear()
	for unit in data.units:
		var copy: Dictionary = unit.duplicate(true)
		copy.encounter = int(copy.encounter)
		copy.position = point(copy.position)
		units.append(copy)
	if revealed != (neutralized_attackers() >= 1) or complete and not revealed or reveal_pending and not revealed: return false
	if contact >= 0 and (unit_for(contact).is_empty() or not available(unit_for(contact))): return false
	var expected: Dictionary = {}
	for index in encounters.size():
		if encounters[index].kind == "poi": expected[index] = true
	if data.anchors.size() not in [expected.size(), expected.size() + 1]: return false
	for key in data.anchors:
		if not str(key).is_valid_int() or not Navigation.valid_point(data.anchors[key], false): return false
		var index: int = int(key)
		if not expected.has(index) and index != -2: return false
		if absf(float(data.anchors[key][0])) > 28 or absf(float(data.anchors[key][2])) > 28: return false
		anchors[index] = point(data.anchors[key])
	for index in expected:
		if not anchors.has(index): return false
	return true
static func number(value: Variant, low: int, high: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high
