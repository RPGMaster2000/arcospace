extends "res://scripts/expedition/moving_poi.gd"
## Secondary objective and its one possible punitive encounter.
const MARKER := -4
const LABEL := "Civilian Evacuation Convoy"
const CONTACT_RADIUS := 2.5
var maximum_integrity: int
var integrity: int
var attack_damage: int
var reward: int
var pressure_penalty: float
var pursuer_limit: int
var dispatch_delay: float
var pursuers: Array[int] = []
var attackers: Array[int] = []
var reward_claimed := false
var punitive_index := -1
var punitive_remaining := 0.0
var punitive_entry: Dictionary = {}
var entry_point := Vector3.ZERO


func setup(system: int, tuning: Resource, starting_integrity: int = 0) -> void:
	id = "evacuation-%d" % system
	kind = "evacuation"
	display_name = LABEL
	faction = "allied"
	maximum_integrity = tuning.convoy_integrity
	integrity = mini(starting_integrity, maximum_integrity) if starting_integrity > 0 else maximum_integrity
	speed = tuning.convoy_speed
	attack_damage = tuning.convoy_attack_damage
	reward = tuning.convoy_salvage
	pressure_penalty = tuning.convoy_pressure
	pursuer_limit = tuning.convoy_pursuer_limit
	dispatch_delay = tuning.convoy_punitive_delay


func extract() -> void:
	leg = route.size() - 1
	progress = 0.0
	activity = "extracted"
	pursuers.clear()


func attack(index: int) -> bool:
	if not traveling() or attackers.has(index) or not pursuers.has(index): return false
	attackers.append(index)
	pursuers.erase(index)
	integrity = maxi(0, integrity - attack_damage)
	if integrity == 0:
		activity = "destroyed"
		pursuers.clear()
	return true


func pursuit_time(at: Vector3, enemy_speed: float) -> float:
	return meeting_time(position() - at, velocity(), enemy_speed, CONTACT_RADIUS)


func guidance(at: Vector3, enemy_speed: float) -> Vector3:
	var seconds := pursuit_time(at, enemy_speed)
	return position() + velocity() * minf(seconds, leg_seconds()) if velocity() != Vector3.ZERO else position()


func rendezvous(player: Vector3, speed_per_second: float) -> Vector3:
	var at := position()
	var spent := 0.0
	for index in range(leg, route.size() - 1):
		var velocity_on_leg := (route[index + 1] - at).normalized() * speed
		var duration := at.distance_to(route[index + 1]) / speed
		# The player keeps moving during earlier legs. This solution uses the
		# original departure throughout the route, including at waypoints.
		var t := meeting_time(at - player - velocity_on_leg * spent, velocity_on_leg, speed_per_second)
		if t >= spent - EPSILON and t <= spent + duration + EPSILON:
			return at + velocity_on_leg * maxf(0.0, t - spent)
		spent += duration
		at = route[index + 1]
	return destination()


func snapshot() -> Dictionary:
	var data := route_snapshot()
	data.merge({"version":1, "id":id, "integrity":integrity, "maximum_integrity":maximum_integrity,
		"attack_damage":attack_damage, "reward":reward, "pressure_penalty":pressure_penalty,
		"pursuer_limit":pursuer_limit, "dispatch_delay":dispatch_delay, "pursuers":pursuers.duplicate(),
		"attackers":attackers.duplicate(), "reward_claimed":reward_claimed, "punitive_index":punitive_index,
		"punitive_remaining":punitive_remaining, "elite":punitive_entry.enemy_data.resource_path,
		"elite_deployment":punitive_entry.get("defense_deployment", {}).duplicate(true),
		"entry_point":[entry_point.x, entry_point.y, entry_point.z]})
	return data


func restore(data: Variant, expansion: float, system: int, elite: Resource) -> bool:
	if not data is Dictionary or data.get("version") != 1 or data.get("id") != "evacuation-%d" % system or system < 3:
		return false
	if elite == null or elite.enemy_rank != 1 or not restore_route(data, expansion): return false
	for key in ["maximum_integrity", "attack_damage", "reward", "pursuer_limit", "integrity", "punitive_index"]:
		var low: int = {"reward":0, "integrity":0, "punitive_index":-1}.get(key, 1)
		var high: int = {"pursuer_limit":2, "punitive_index":99}.get(key, 200)
		if not whole(data.get(key), low, high): return false
	if data.integrity > data.maximum_integrity or (data.integrity == 0) != (activity == "destroyed"): return false
	if not finite(data.get("pressure_penalty"), 0, 100) or not finite(data.get("dispatch_delay"), 0.1, 60): return false
	if not finite(data.get("punitive_remaining"), 0, maxf(float(data.dispatch_delay), 2.0)): return false
	if not data.get("reward_claimed") is bool or data.reward_claimed != (activity == "extracted"): return false
	if (data.punitive_index >= 0) != (activity == "destroyed") or (activity != "destroyed" and data.punitive_remaining > 0): return false
	if not data.get("pursuers") is Array or data.pursuers.size() > data.pursuer_limit \
		or (not traveling() and not data.pursuers.is_empty()) or not data.get("attackers") is Array or data.attackers.size() > 22:
		return false
	var seen := {}
	for index in data.pursuers + data.attackers:
		if not whole(index, 0, 99) or seen.has(index): return false
		seen[index] = true
	if not Navigation.valid_point(data.get("entry_point"), false) or not data.get("elite_deployment") is Dictionary: return false
	entry_point = Vector3(data.entry_point[0], data.entry_point[1], data.entry_point[2])
	if not Layout.navigable(entry_point, expansion): return false
	id = data.id
	kind = "evacuation"
	display_name = LABEL
	faction = "allied"
	maximum_integrity = int(data.maximum_integrity)
	integrity = int(data.integrity)
	attack_damage = int(data.attack_damage)
	reward = int(data.reward)
	pursuer_limit = int(data.pursuer_limit)
	pressure_penalty = float(data.pressure_penalty)
	dispatch_delay = float(data.dispatch_delay)
	pursuers.assign(data.pursuers.map(func(index): return int(index)))
	attackers.assign(data.attackers.map(func(index): return int(index)))
	reward_claimed = data.reward_claimed
	punitive_index = int(data.punitive_index)
	punitive_remaining = float(data.punitive_remaining)
	punitive_entry = enemy_entry(elite, system)
	if not data.elite_deployment.is_empty(): punitive_entry.defense_deployment = data.elite_deployment.duplicate(true)
	return true


static func enemy_entry(elite: Resource, system: int) -> Dictionary:
	return {"kind":"battle", "enemy":0, "enemy_data":elite, "system_number":system, "modifier":0,
		"title":elite.ship_name, "completed":false, "punitive":true}
