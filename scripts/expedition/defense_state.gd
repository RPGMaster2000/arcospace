extends RefCounted
# Scene-free strategic authority. Units reference the existing encounter ledger.
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
var tuning: Resource
var layout_expansion: float = 0.0
var decorative_bodies: Array = []
var home: Vector3
var start: Vector3
var anchors: Dictionary = {}
var units: Array[Dictionary] = []
var integrity: int = 100
var revealed: bool = false
var reveal_pending: bool = false
var complete: bool = false
var pressure: float = 0.0
var mothership_advancing: bool = false
var construction_sites: Dictionary = {}
var turrets: Dictionary = {}
const Installations = preload("res://scripts/expedition/defense_installations.gd")

var contact: int = -1
var reinforcement_remaining: float = 0.0
var reinforcements_spawned: int = 0
var deferred_seconds: float = 0.0
static func point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])
static func wire(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
func deploy(configuration: Resource, angle: float, indices: Array, poi_indices: Array,
		hostile_offset: float = 0.7, poi_phase: float = 0.35, expansion: float = 0.0,
		planetary: Array = [], orbit_seed: int = 0) -> void:
	tuning = configuration
	layout_expansion = expansion
	var factor := Layout.scale_factor(expansion)
	integrity = tuning.base_integrity
	home = Vector3(cos(angle), 0, sin(angle)) * (22.0 * factor)
	start = home * 0.78
	for i in range(3):
		# Keep all three routes on the same safe flank of the sun and opposite home.
		var flank_sign: float = 1.0 if hostile_offset >= 0.0 else -1.0
		var heading: float = angle + PI + hostile_offset + flank_sign * [-0.45, 0.0, 0.35][i]
		var origin: Vector3 = Vector3(cos(heading), 0, sin(heading)) * (tuning.hostile_spawn_distance * factor)
		units.append({"encounter": indices[i], "position": origin, "route_origin": origin,
			"status": "active", "mothership": i == 2, "reinforcement": false, "spawned": false})
	var rings := [7.0, 10.0, 13.0, 16.0, 19.0, 5.5, 8.5, 14.5]
	var orbit_rng := RandomNumberGenerator.new()
	orbit_rng.seed = orbit_seed
	for i in poi_indices.size():
		var heading: float = angle + TAU * float(i) / maxi(1, poi_indices.size()) + poi_phase
		var radial: float = [19.0, 10.0, 16.0, 7.0, 16.0, 10.0, 19.0, 13.0][i % 8]
		var direction := Vector3(cos(heading), 0, sin(heading))
		var anchor := direction * (radial * factor)
		if expansion > 0.0 and poi_indices[i] in planetary:
			direction = direction.rotated(Vector3.UP, orbit_rng.randf_range(-0.08, 0.08))
			var jitter := orbit_rng.randf_range(-0.16, 0.16)
			var best_score := INF
			var chosen := 0
			for ring in rings.size():
				var candidate := direction * ((float(rings[ring]) + jitter) * factor)
				var score: float = absf(rings[ring] - radial)
				for unit in units:
					score += maxf(0.0, 5.5 - candidate.distance_to(unit.position)) * 8.0
				if score >= best_score: continue
				chosen = ring
				best_score = score
				anchor = candidate
			rings.remove_at(chosen)
		else:
			for unit in units:
				if unit.position.distance_to(anchor) <= 5.5 * factor:
					anchor = direction * (10.0 * factor)
					break
		anchors[poi_indices[i]] = anchor
# Reserve units have stable encounter IDs and existing profiles, but no active
# simulation or rendered presence until the scheduler deploys them.
func add_reserves(indices: Array) -> void:
	var mother: Dictionary = unit_for(mothership_index())
	for index in indices:
		units.append({"encounter": index, "position": mother.position, "route_origin": mother.position,
			"status": "reserve", "mothership": false, "reinforcement": true, "spawned": false})

func active_attackers() -> int:
	var count: int = 0
	for unit in units:
		if not unit.mothership and unit.status == "active": count += 1
	return count

func spawn_position(player: Vector3) -> Variant:
	var center: Vector3 = unit_for(mothership_index()).position
	var limit := Layout.bounds(layout_expansion).end.x - 2.0
	for distance in [3.5, 5.0, 6.5]:
		for i in range(24):
			var angle: float = TAU * float((i + reinforcements_spawned * 7) % 24) / 24.0
			var candidate: Vector3 = center + Vector3(cos(angle), 0, sin(angle)) * distance
			if absf(candidate.x) > limit or absf(candidate.z) > limit or candidate.length() < 3.5: continue
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
func mothership_arrived() -> bool:
	return unit_for(mothership_index()).get("status") == "arrived"

func failed() -> bool:
	if integrity <= 0 or mothership_arrived(): return true
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
		mothership_advancing = false
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
# Both player movement and committed activity costs use this same clock.
# Activity time advances the fleet without initiating chained stationary battles.
func target_for(_unit: Dictionary) -> Vector3:
	return home

func _speed(unit: Dictionary) -> float:
	if unit.mothership:
		return tuning.mothership_speed if mothership_advancing else 0.0
	return tuning.enemy_speed

func moving_route(unit: Dictionary) -> Dictionary:
	if not available(unit): return {}
	var speed := _speed(unit)
	if speed <= 0.0: return {}
	var target := target_for(unit)
	var origin: Vector3 = unit.route_origin
	# Use the original route ray to suppress rounding drift from Vector3 motion
	# samples. A repositioned unit still uses its actual route to the target.
	if Geometry3D.get_closest_point_to_segment(unit.position, origin, target).distance_squared_to(unit.position) > 0.000001:
		origin = unit.position
	return {"position": unit.position, "origin": origin, "target": target, "speed": speed}

func _advance_pressure(seconds: float) -> bool:
	pressure = minf(tuning.pressure_maximum, pressure + seconds * tuning.pressure_per_second)
	if mothership_advancing or pressure < tuning.pressure_maximum - 0.00000001:
		return false
	pressure = tuning.pressure_maximum
	mothership_advancing = true
	if not revealed:
		# Reveal immediately during the current movement/activity instead of pausing it.
		revealed = true
		reinforcement_remaining = tuning.first_reinforcement_seconds
	return true

func advance_time(seconds: float, from: Vector3, to: Vector3, carry: bool = false,
		observe_span: Callable = Callable()) -> Dictionary:
	var result: Dictionary = {"position": to, "contact": -1, "arrivals": 0, "spawned": [], "escalated": false}
	if complete or contact >= 0 or failed() or seconds <= 0 or not is_finite(seconds): return result
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
		if not mothership_advancing and tuning.pressure_per_second > 0:
			var threshold: float = (tuning.pressure_maximum - pressure) / tuning.pressure_per_second
			if threshold <= event_time:
				event_time = maxf(0.0, threshold)
				event_kind = "pressure"
		for unit in units:
			if not available(unit): continue
			var target: Vector3 = target_for(unit)
			var speed: float = _speed(unit)
			var velocity: Vector3 = (target - unit.position).normalized() * speed
			var arrival: float = unit.position.distance_to(target) / speed if speed > 0 else INF
			var hit: float = INF if carry else hit_time(from + player_velocity * elapsed - unit.position, player_velocity - velocity, tuning.interception_radius, minf(span, arrival))
			if hit <= event_time:
				event_time = hit
				event_unit = unit
				event_kind = "contact"
			elif arrival <= event_time:
				event_time = arrival
				event_unit = unit
				event_kind = "arrival"
		# Observe the consumed span with the current fleet and velocities. Events
		# at its endpoint change the roster for the following span.
		if observe_span.is_valid(): observe_span.call(event_time)
		for unit in units:
			if available(unit):
				unit.position = unit.position.move_toward(target_for(unit), _speed(unit) * event_time)
		if revealed and not reveal_pending and not complete and reinforcements_spawned < tuning.maximum_reinforcements:
			reinforcement_remaining = maxf(0.0, reinforcement_remaining - event_time)
		elapsed += event_time
		if _advance_pressure(event_time): result.escalated = true
		if event_kind.is_empty(): break
		if event_kind == "pressure": continue
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
			reserve.route_origin = at
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
		if event_unit.mothership:
			mothership_advancing = false
			result.position = from + player_velocity * elapsed
			break
		integrity = maxi(0, integrity - tuning.base_attack_damage)
		result.arrivals += 1
		if failed():
			mothership_advancing = false
			result.position = from + player_velocity * elapsed
			break
	return result

# Predict a meeting in distance travelled by the player. Enemy speed is per
# strategic second, so conversion to player distance is independent of FPS.
func intercept_point(index: int, player: Vector3) -> Vector3:
	var unit: Dictionary = unit_for(index)
	if unit.is_empty() or not available(unit): return player
	if _speed(unit) <= 0: return unit.position
	var relative: Vector3 = unit.position - player
	var target: Vector3 = target_for(unit)
	var velocity: Vector3 = (target - unit.position).normalized() * _speed(unit) * tuning.seconds_per_distance
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
	var until_arrival: float = unit.position.distance_to(target) / maxf(velocity.length(), 0.000001)
	if not is_finite(root) or root > until_arrival: return target
	return unit.position + velocity * root

func snapshot() -> Dictionary:
	var data: Dictionary = {"home": wire(home), "start": wire(start), "integrity": integrity, "maximum_integrity": tuning.base_integrity,
		"revealed": revealed, "reveal_pending": reveal_pending, "complete": complete, "contact": contact,
		"pressure": pressure, "maximum_pressure": tuning.pressure_maximum, "mothership_advancing": mothership_advancing,
		"mothership_eta": unit_for(mothership_index()).position.distance_to(home) / tuning.mothership_speed if mothership_advancing else 0.0,
		"construction_sites": construction_sites.duplicate(true), "turrets": turrets.duplicate(true),
		"reinforcement_remaining": reinforcement_remaining, "reinforcements_spawned": reinforcements_spawned, "deferred_seconds": deferred_seconds, "units": [], "anchors": {}}
	for unit in units:
		var copy: Dictionary = unit.duplicate()
		copy.position = wire(unit.position)
		copy.route_origin = wire(unit.route_origin)
		data.units.append(copy)
	for index in anchors: data.anchors[str(index)] = wire(anchors[index])
	return data
func restore(data: Variant, configuration: Resource, encounters: Array, expansion: float = 0.0) -> bool:
	if not data is Dictionary: return false
	layout_expansion = expansion
	var limit := Layout.bounds(expansion).end.x
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
		if not Navigation.valid_point(unit.get("route_origin", unit.position), false): return false
		if absf(float(unit.position[0])) > limit or absf(float(unit.position[2])) > limit: return false
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
	var saved_pressure: Variant = data.get("pressure", 0.0)
	if not (saved_pressure is int or saved_pressure is float) or not is_finite(float(saved_pressure)) or saved_pressure < 0 or saved_pressure > 1000.0: return false
	if not data.get("mothership_advancing", false) is bool: return false
	pressure = minf(float(saved_pressure), tuning.pressure_maximum)
	mothership_advancing = data.get("mothership_advancing", false)
	if mothership_advancing and (not revealed or complete): return false
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
		copy.route_origin = point(copy.get("route_origin", unit.position))
		copy.reinforcement = bool(copy.get("reinforcement", false))
		copy.spawned = bool(copy.get("spawned", false))
		units.append(copy)
	if not revealed and (neutralized_attackers() >= 1 or complete or reveal_pending): return false
	if revealed and not (neutralized_attackers() >= 1 or mothership_advancing or complete): return false
	if contact >= 0 and (unit_for(contact).is_empty() or not available(unit_for(contact))): return false
	var expected: Dictionary = {}
	for index in encounters.size():
		if encounters[index].kind == "poi": expected[index] = true
	if data.anchors.size() not in [expected.size(), expected.size() + 1]: return false
	for key in data.anchors:
		if not str(key).is_valid_int() or not Navigation.valid_point(data.anchors[key], false): return false
		var index: int = int(key)
		if not expected.has(index) and index != -2: return false
		if absf(float(data.anchors[key][0])) > limit or absf(float(data.anchors[key][2])) > limit: return false
		anchors[index] = point(data.anchors[key])
	for index in expected:
		if not anchors.has(index): return false
	construction_sites = Installations.sites(home, anchors, encounters, expansion)
	var saved_turrets: Variant = data.get("turrets", {})
	if not Installations.valid_deployments(saved_turrets, construction_sites): return false
	turrets = saved_turrets.duplicate(true)
	for turret in turrets.values():
		turret.position = wire(point(turret.position))
		turret.radius = float(turret.radius)
		turret.damage = int(turret.damage)
		turret.interval = int(turret.interval)
	return true
static func number(value: Variant, low: int, high: int) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value == floor(value) and value >= low and value <= high
