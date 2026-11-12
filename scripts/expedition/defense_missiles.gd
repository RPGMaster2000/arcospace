extends RefCounted

const FIRST_ID = 1000
const EPSILON = 0.000001
const PRIORITY = {"": 0, "launch": 1, "impact": 2, "intercept": 3, "shot": 4}
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const Layout = preload("res://scripts/expedition/system_layout.gd")
var active: Dictionary = {}
var pending := -1
var next_id := FIRST_ID
var countdown := 0.0
var cooldowns: Dictionary = {}

static func point(wire: Array) -> Vector3:
	return Vector3(wire[0], wire[1], wire[2])

func position(missile: Dictionary, home: Vector3) -> Vector3:
	var origin: Vector3 = missile.origin
	return home + (origin - home).normalized() * float(missile.remaining)

func speed(tuning: Resource) -> float:
	return float(tuning.enemy_speed) * float(tuning.missile_speed_multiplier)

func event(fleet: RefCounted, player: Vector3, velocity: Vector3, span: float, carry: bool,
		sweep: Callable) -> Dictionary:
	var best := {"time": span, "kind": ""}
	if fleet.revealed and speed(fleet.tuning) > 0.0 and countdown <= span + EPSILON:
		best = {"time": minf(span, countdown), "kind": "launch"}
	var missile_speed := speed(fleet.tuning)
	var sites: Array = fleet.turrets.keys()
	sites.sort()
	for id in active:
		var missile: Dictionary = active[id]
		var at := position(missile, fleet.home)
		var motion: Vector3 = (fleet.home - at).normalized() * missile_speed
		var arrival := float(missile.remaining) / missile_speed if missile_speed > 0.0 else INF
		if _before(arrival, "impact", best):
			best = {"time": minf(arrival, span), "kind": "impact", "id": id}
		if not carry:
			var hit: float = sweep.call(player - at, velocity - motion,
				fleet.tuning.interception_radius, minf(span, arrival))
			if _before(hit, "intercept", best):
				best = {"time": hit, "kind": "intercept", "id": id}
		for site in sites:
			var turret: Dictionary = fleet.turrets[site]
			var ready := float(cooldowns.get(site, 0.0))
			var window := minf(span, arrival) - ready
			if window < -EPSILON: continue
			var radius: float = turret.radius
			var relative := at - point(turret.position) + motion * ready
			var enter: float = 0.0 if relative.length_squared() <= (radius + EPSILON) ** 2 \
				else sweep.call(relative, motion, radius, maxf(0.0, window))
			var fire := enter + ready
			if _before(fire, "shot", best):
				best = {"time": minf(fire, span), "kind": "shot", "id": id, "site": site}
	return best

static func _before(time: float, kind: String, best: Dictionary) -> bool:
	return time < float(best.time) - EPSILON or (absf(time - float(best.time)) <= EPSILON
		and int(PRIORITY[kind]) > int(PRIORITY[best.kind]))

func advance(seconds: float, fleet: RefCounted) -> void:
	if fleet.revealed: countdown = maxf(0.0, countdown - seconds)
	for missile in active.values():
		missile.remaining = maxf(0.0, float(missile.remaining) - speed(fleet.tuning) * seconds)
	for site in cooldowns:
		cooldowns[site] = maxf(0.0, float(cooldowns[site]) - seconds)

func resolve(action: Dictionary, fleet: RefCounted) -> void:
	var id: int = action.get("id", -1)
	match action.kind:
		"launch":
			countdown = maxf(0.1, fleet.tuning.missile_interval)
			if active.size() >= fleet.tuning.maximum_missiles: return
			var origin: Vector3 = fleet.unit_for(fleet.mothership_index()).position
			if origin.distance_to(fleet.home) <= EPSILON: return
			active[next_id] = {"origin": origin, "remaining": origin.distance_to(fleet.home), "hull": fleet.tuning.missile_hull}
			next_id += 1
		"impact":
			active.erase(id)
			fleet.integrity = maxi(0, fleet.integrity - fleet.tuning.missile_home_damage)
		"shot":
			cooldowns[action.site] = fleet.tuning.turret_missile_interval
			active[id].hull -= fleet.tuning.turret_missile_damage
			if active[id].hull <= 0: active.erase(id)
		"intercept":
			pending = id

func snapshot(home: Vector3) -> Dictionary:
	var records: Array = []
	for id in active:
		var missile: Dictionary = active[id]
		var origin: Vector3 = missile.origin
		var at := position(missile, home)
		records.append({"id": id, "origin": [origin.x, origin.y, origin.z], "position": [at.x, at.y, at.z],
			"remaining": missile.remaining, "hull": missile.hull})
	return {"active": records, "pending": pending, "next_id": next_id, "countdown": countdown,
		"cooldowns": cooldowns.duplicate()}

func restore(data: Variant, fleet: RefCounted) -> bool:
	if not data is Dictionary or not data.get("active") is Array or data.active.size() > 8: return false
	if not _integer(data.get("next_id"), FIRST_ID, 2147483647) or not _number(data.get("countdown"), 120.0): return false
	next_id = int(data.next_id)
	countdown = float(data.countdown)
	if not _integer(data.get("pending"), -1, next_id - 1) or not data.get("cooldowns") is Dictionary: return false
	pending = int(data.pending)
	for record in data.active:
		if not record is Dictionary or not _integer(record.get("id"), FIRST_ID, next_id - 1): return false
		var id := int(record.id)
		if active.has(id) or not Navigation.valid_point(record.get("origin"), false): return false
		var origin := point(record.origin)
		if not Layout.bounds(fleet.layout_expansion).has_point(Vector2(origin.x, origin.z)): return false
		if not _number(record.get("remaining"), origin.distance_to(fleet.home) + EPSILON): return false
		if not _integer(record.get("hull"), 1, 100): return false
		var missile := {"origin": origin, "remaining": float(record.remaining), "hull": int(record.hull)}
		if not Navigation.valid_point(record.get("position"), false): return false
		if point(record.position).distance_to(position(missile, fleet.home)) > 0.001: return false
		active[id] = missile
	for site in data.cooldowns:
		if not fleet.turrets.has(site) or not _number(data.cooldowns[site], 30.0): return false
		cooldowns[site] = float(data.cooldowns[site])
	if not fleet.revealed or fleet.complete:
		return pending == -1 and active.is_empty() and countdown == 0.0 and cooldowns.is_empty()
	return pending == -1 or active.has(pending)

static func _number(value: Variant, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0.0 and value <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and value >= low and value <= high and value == floor(value)
