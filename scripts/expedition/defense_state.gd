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
var reinforcement_remaining: float = 0.0
var reinforcements_spawned: int = 0
var deferred_seconds: float = 0.0
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
			"status": "active", "mothership": i == 2, "reinforcement": false, "spawned": false})
	for i in poi_indices.size():
		var heading: float = angle + TAU * float(i) / maxi(1, poi_indices.size()) + 0.35
		anchors[poi_indices[i]] = Vector3(cos(heading), 0, sin(heading)) * (10.0 if i % 2 == 0 else 14.0)
# Reserve units have stable encounter IDs and existing profiles, but no active
# simulation or rendered presence until the scheduler deploys them.
func add_reserves(indices: Array) -> void:
	var mother: Dictionary = unit_for(mothership_index())
	for index in indices:
		units.append({"encounter": index, "position": mother.position, "status": "reserve", "mothership": false, "reinforcement": true, "spawned": false})

func active_attackers() -> int:
	var count: int = 0
	for unit in units:
		if not unit.mothership and unit.status == "active": count += 1
	return count

func spawn_position(player: Vector3) -> Variant:
	var center: Vector3 = unit_for(mothership_index()).position
	for distance in [3.5, 5.0, 6.5]:
		for i in range(24):
			var angle: float = TAU * float((i + reinforcements_spawned * 7) % 24) / 24.0
			var candidate: Vector3 = center + Vector3(cos(angle), 0, sin(angle)) * distance
			if absf(candidate.x) > 26 or absf(candidate.z) > 26 or candidate.length() < 3.5: continue
			if candidate.distance_to(player) < tuning.interception_radius + 1.0 or candidate.distance_to(home) < 5: continue
			var clear: bool = true
			for other in units:
				if other.status == "active" and candidate.distance_to(other.position) < 3.0: clear = false
			for anchor in anchors.values():
				if candidate.distance_to(anchor) < 3.0: clear = false
			if clear: return candidate
	return null

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
		deferred_seconds = 0.0
		for remaining in units:
			if remaining.status in ["active", "reserve"]: remaining.status = "secured"
	elif not revealed and neutralized_attackers() >= 1:
		reinforcement_remaining = tuning.first_reinforcement_seconds
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
# Both player movement and committed activity costs use this same clock. A
# contact interrupts the clock; unused activity seconds remain persisted until
# that encounter has resolved, so rewards never get interrupted.
func advance_time(seconds: float, from: Vector3, to: Vector3, carry: bool = false) -> Dictionary:
	var result: Dictionary = {"position": to, "contact": -1, "arrivals": 0, "spawned": []}
	if complete or contact >= 0 or integrity <= 0 or seconds <= 0 or not is_finite(seconds): return result
	var player_velocity: Vector3 = (to - from) / seconds
	var elapsed: float = 0.0
	var spawn_blocked: bool = false
	while elapsed < seconds:
		var span: float = seconds - elapsed
		var event_time: float = span
		var event_unit: Dictionary = {}
		var event_kind: String = ""
		var can_spawn: bool = revealed and not reveal_pending and not complete and reinforcements_spawned < tuning.maximum_reinforcements and active_attackers() < tuning.maximum_active_attackers
		if can_spawn and not spawn_blocked and reinforcement_remaining <= event_time:
			event_time = maxf(0.0, reinforcement_remaining)
			event_kind = "spawn"
		for unit in units:
			if not available(unit): continue
			var velocity: Vector3 = Vector3.ZERO if unit.mothership else (home - unit.position).normalized() * tuning.enemy_speed
			var arrival: float = INF if unit.mothership or tuning.enemy_speed <= 0 else unit.position.distance_to(home) / tuning.enemy_speed
			# Activity penalties advance hostile movement but cannot initiate a new
			# battle against a stationary player. Only actual travel can intercept.
			var hit: float = INF if carry else hit_time(from + player_velocity * elapsed - unit.position, player_velocity - velocity, tuning.interception_radius, minf(span, arrival))
			if hit <= event_time:
				event_time = hit
				event_unit = unit
				event_kind = "contact"
			elif arrival <= event_time:
				event_time = arrival
				event_unit = unit
				event_kind = "arrival"
		for unit in units:
			if available(unit) and not unit.mothership:
				unit.position = unit.position.move_toward(home, tuning.enemy_speed * event_time)
		if revealed and not reveal_pending and not complete and reinforcements_spawned < tuning.maximum_reinforcements:
			reinforcement_remaining = maxf(0.0, reinforcement_remaining - event_time)
		elapsed += event_time
		if event_kind.is_empty(): break
		if event_kind == "spawn":
			var at: Variant = spawn_position(from + player_velocity * elapsed)
			var reserve: Dictionary = {}
			for unit in units:
				if unit.status == "reserve":
					reserve = unit
					break
			if at == null or reserve.is_empty():
				spawn_blocked = true
				continue
			reserve.position = at
			reserve.status = "active"
			reserve.spawned = true
			reinforcements_spawned += 1
			reinforcement_remaining = tuning.reinforcement_interval_seconds
			result.spawned.append(reserve.encounter)
			continue
		if event_kind == "contact":
			contact = event_unit.encounter
			result.contact = contact
			result.position = from + player_velocity * elapsed
			if carry: deferred_seconds += maxf(0.0, seconds - elapsed)
			break
		event_unit.status = "arrived"
		integrity = maxi(0, integrity - tuning.base_attack_damage)
		result.arrivals += 1
		if failed():
			result.position = from + player_velocity * elapsed
			break
	return result

# Predict a meeting in distance travelled by the player. Enemy speed is per
# strategic second, so conversion to player distance is independent of FPS.
func intercept_point(index: int, player: Vector3) -> Vector3:
	var unit: Dictionary = unit_for(index)
	if unit.is_empty() or not available(unit): return player
	if unit.mothership: return unit.position
	var relative: Vector3 = unit.position - player
	var velocity: Vector3 = (home - unit.position).normalized() * tuning.enemy_speed * tuning.seconds_per_distance
	var a: float = velocity.length_squared() - 1.0
	var b: float = 2.0 * relative.dot(velocity)
	var c: float = relative.length_squared()
	var root: float = INF
	if absf(a) < 0.000001:
		if b < 0: root = -c / b
	else:
		var discriminant: float = b*b - 4*a*c
		if discriminant >= 0:
			var first: float = (-b - sqrt(discriminant)) / (2*a)
			var second: float = (-b + sqrt(discriminant)) / (2*a)
			if first >= 0: root = first
			if second >= 0: root = minf(root, second)
	var until_arrival: float = unit.position.distance_to(home) / maxf(velocity.length(), 0.000001)
	if not is_finite(root) or root > until_arrival: return home
	return unit.position + velocity * root

func snapshot() -> Dictionary:
	var data: Dictionary = {"home": wire(home), "start": wire(start), "integrity": integrity,
		"revealed": revealed, "reveal_pending": reveal_pending, "complete": complete, "contact": contact,
		"reinforcement_remaining": reinforcement_remaining, "reinforcements_spawned": reinforcements_spawned, "deferred_seconds": deferred_seconds, "units": [], "anchors": {}}
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
	if not data.get("units") is Array or data.units.size() < 3 or data.units.size() > 23 or not data.get("anchors") is Dictionary: return false
	var seen: Dictionary = {}
	var bosses: int = 0
	var spawned_count: int = 0
	for unit in data.units:
		if not unit is Dictionary or not unit.get("mothership") is bool: return false
		if unit.get("status") not in ["active", "reserve", "neutralized", "arrived", "secured"]: return false
		if not unit.get("reinforcement", false) is bool or not unit.get("spawned", false) is bool: return false
		if unit.get("reinforcement", false):
			if unit.mothership or unit.status == "reserve" and unit.get("spawned", false): return false
			if unit.status in ["active", "neutralized", "arrived"] and not unit.get("spawned", false): return false
			if unit.get("spawned", false): spawned_count += 1
		elif unit.get("spawned", false) or unit.status == "reserve": return false
		if not number(unit.get("encounter"), 0, encounters.size()-1): return false
		var index: int = int(unit.encounter)
		if seen.has(index) or encounters[index].kind != "battle" or unit.get("status") not in ["active", "reserve", "neutralized", "arrived", "secured"]: return false
		if not Navigation.valid_point(unit.get("position"), false): return false
		if absf(float(unit.position[0])) > 28 or absf(float(unit.position[2])) > 28: return false
		if unit.status == "secured" and not data.complete: return false
		if data.complete and unit.status in ["active", "reserve"]: return false
		if encounters[index].completed != (unit.status not in ["active", "reserve"]): return false
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
	var remaining: Variant = data.get("reinforcement_remaining", configuration.first_reinforcement_seconds if revealed else 0.0)
	var deferred: Variant = data.get("deferred_seconds", 0.0)
	if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or remaining < 0 or remaining > 60: return false
	if not (deferred is int or deferred is float) or not is_finite(float(deferred)) or deferred < 0 or deferred > 1000: return false
	if not number(data.get("reinforcements_spawned", 0), 0, configuration.maximum_reinforcements): return false
	reinforcement_remaining = float(remaining)
	deferred_seconds = float(deferred)
	reinforcements_spawned = int(data.get("reinforcements_spawned", 0))
	if spawned_count != reinforcements_spawned: return false
	if spawned_count > 0 and not revealed: return false
	if deferred_seconds > 0 and contact < 0: return false
	units.clear()
	for unit in data.units:
		var copy: Dictionary = unit.duplicate(true)
		copy.encounter = int(copy.encounter)
		copy.position = point(copy.position)
		copy.reinforcement = bool(copy.get("reinforcement", false))
		copy.spawned = bool(copy.get("spawned", false))
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
