extends RefCounted
## Fleet and objective state. Both map and committed activities use the same clock.

const Defense = preload("res://scripts/expedition/defense_state.gd")
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const REQUIRED_OBJECTIVES := 2
const STEP_MS := 1000
const MAX_EVENTS := 8
const OWNER := ["allied", "hostile", "neutral"]
const OBJECTIVES := ["Communications Relay", "Shipyard", "Defense Array"]
const ROLES := ["Defender", "Vanguard", "Assault", "Patrol", "Reinforcement"]
const START := Vector3(-16.1, 0, 10.7)
const OUTPOST := Vector3(-22, 0, 3.5)
const ALLIED_GROUPS := 2
const HOSTILE_GROUPS := 5
const INTERCEPT_RADIUS := 2.75

var tuning: Resource
var objectives: Array[Dictionary] = []
var fleets: Array[Dictionary] = []
var events: Array[String] = []
var event_revision := 0
var clock_ms := 0
var travel_ms_remainder := 0.0
var consolidation := 0
var player_victories := 0
var initial_allied_strength := 0
var complete := false
## Transient presentation cues from the most recent committed volley.
var volley_tick := 0
var volley: Array[Vector2i] = []
## Recent committed positions for display only. Saves use current coordinates.
var motion_samples: Array[Dictionary] = []


func is_lattice() -> bool:
	return false


func objective_name(index: int) -> String:
	return OBJECTIVES[index]


func start_position(expansion: float) -> Vector3:
	return START * maxf(1.0, expansion)


func outpost_position(expansion: float) -> Vector3:
	return OUTPOST * maxf(1.0, expansion)


func setup(configuration: Resource, strength: int, expansion: float = 1.0) -> void:
	tuning = configuration
	objectives.clear()
	fleets.clear()
	events.clear()
	event_revision = 0
	clock_ms = 0
	travel_ms_remainder = 0.0
	consolidation = 0
	player_victories = 0
	complete = false
	volley_tick = 0
	volley.clear()
	motion_samples.clear()
	initial_allied_strength = 2 * strength
	for point in [Vector3(-15, 0, 8), Vector3(12, 0, -13), Vector3(14, 0, 13)]:
		objectives.append({"position": point * expansion, "owner": "allied" if objectives.is_empty() else "hostile",
			"contested": false, "capturing": "neutral", "progress": 0, "held": 0})
	var relay_front := Vector3(-15.7, 0, 11.4) * expansion
	var shipyard_front: Vector3 = objectives[1].position - Vector3.RIGHT * (tuning.objective_radius * 0.85)
	var engagement_spacing := Vector3.RIGHT * minf(1.5, tuning.engagement_radius * 0.8)
	_add_fleet("allied", "Defender", relay_front, 0, strength)
	_add_fleet("allied", "Vanguard", shipyard_front, 1, strength)
	_add_fleet("hostile", "Assault", relay_front + engagement_spacing, 0, tuning.hostile_strength)
	_add_fleet("hostile", "Reinforcement", Vector3(3, 0, 9) * expansion, 0, tuning.hostile_strength)
	_add_fleet("hostile", "Patrol", shipyard_front + engagement_spacing, 1, tuning.hostile_strength)
	_add_fleet("hostile", "Defender", objectives[2].position, 2, tuning.hostile_strength)
	_add_fleet("hostile", "Assault", Vector3(3, 0, -9) * expansion, 1, tuning.hostile_strength)
	_notice("Reinforcements arrived near the Communications Relay.")
	_assign_engagements(true)
	_capture(1, START * expansion)
	_notice("Hostile reinforcements are approaching the Communications Relay.")


func _add_fleet(side: String, role: String, position: Vector3, destination: int, strength: int) -> void:
	fleets.append({"id": fleets.size(), "side": side, "role": role, "position": position,
		"destination": destination, "strength": strength, "engaged": -1})


func active(fleet: Dictionary) -> bool:
	return not fleet.is_empty() and fleet.strength > 0


func fleet_at(id: int) -> Dictionary:
	return fleets[id] if id >= 0 and id < fleets.size() else {}


func fleet_count(side: String) -> int:
	return fleets.filter(func(fleet): return fleet.side == side and active(fleet)).size()


func controlled() -> int:
	return objectives.filter(func(objective): return objective.owner == "allied" and not objective.contested).size()


func engagement_count() -> int:
	return fleets.filter(func(fleet): return fleet.side == "allied" and active(fleet) and fleet.engaged >= 0).size()


func fleet_status(fleet: Dictionary) -> String:
	if not active(fleet): return "Destroyed"
	if fleet.engaged >= 0: return "Engaged"
	if fleet.get("withdrawing", false): return "Retreating"
	var objective := objectives[fleet.destination]
	var needs_recovery: bool = is_lattice() and fleet.strength <= 2
	if (fleet.position as Vector3).distance_squared_to(objective.position) > 0.01:
		return "Retreating" if needs_recovery else "Moving"
	if objective.owner != fleet.side: return "Capturing"
	return "Resupplying" if needs_recovery and _fleet_supplied(fleet) else "Defending"


func _fleet_supplied(_fleet: Dictionary) -> bool:
	return false


func objective_brief(index: int) -> String:
	var objective: Dictionary = objectives[index]
	if objective.contested: return "Contested"
	if objective.progress > 0:
		return "%s capturing · %ds / %ds" % [objective.capturing.capitalize(), objective.progress, tuning.capture_seconds]
	var approaching := fleets.any(func(fleet): return fleet.side == "hostile" and active(fleet) and fleet.destination == index)
	if objective.owner == "allied" and approaching: return "Allied · Hostiles approaching"
	return objective.owner.capitalize()


func main_threat() -> String:
	for index in objectives.size():
		var objective: Dictionary = objectives[index]
		if objective.contested or objective.progress > 0:
			return "%s · %s" % [objective_name(index), objective_brief(index)]
	for index in objectives.size():
		if objective_brief(index).contains("approaching"):
			return objective_name(index) + " · Hostiles approaching"
	return ""


func _notice(message: String) -> void:
	event_revision += 1
	events.append(message)
	if events.size() > MAX_EVENTS:
		events.pop_front()


func events_since(revision: int) -> Array[String]:
	return events.slice(maxi(0, events.size() - (event_revision - revision)))


func motion_step_ms() -> int:
	return STEP_MS


func _advance_step(player: Vector3, allow_victory: bool) -> void:
	_tick(player, allow_victory)


# Evaluate movement and events at fixed clock boundaries.
# The full clock includes the sub-second remainder and survives a save.
func advance(milliseconds: float, from: Vector3, to: Vector3, allow_victory: bool = true) -> void:
	if complete or milliseconds <= 0:
		return
	var start_ms := clock_ms + travel_ms_remainder
	var end_ms := start_ms + milliseconds
	var committed := floori(end_ms + 0.0000001)
	var step := motion_step_ms()
	var tick_ms := clock_ms - posmod(clock_ms, step) + step
	if motion_samples.is_empty() and tick_ms <= committed:
		_record_motion(tick_ms - step)
	while tick_ms <= committed:
		clock_ms = tick_ms
		travel_ms_remainder = 0.0
		_advance_step(from.lerp(to, clampf((tick_ms - start_ms) / milliseconds, 0.0, 1.0)), allow_victory)
		_record_motion(tick_ms)
		if complete:
			return
		tick_ms += step
	clock_ms = committed
	var remainder := end_ms - committed
	# Normalize errors at the integer boundary so equal spans encode identically.
	travel_ms_remainder = remainder if remainder > 0.0000001 else 0.0


func _record_motion(tick_ms: int) -> void:
	motion_samples.append({"tick": tick_ms, "positions": fleets.map(func(fleet): return fleet.position)})
	if motion_samples.size() > 90:
		motion_samples.pop_front()


func _tick(player: Vector3, allow_victory: bool) -> void:
	_assign_engagements(true)
	_reassess_orders()
	for fleet in fleets:
		if not active(fleet) or fleet.engaged >= 0:
			continue
		var destination: Vector3 = objectives[fleet.destination].position
		fleet.position = (fleet.position as Vector3).move_toward(destination, tuning.fleet_speed)
	_assign_engagements(true)
	if roundi(float(clock_ms) / STEP_MS) % maxi(1, tuning.exchange_seconds) == 0:
		_exchange_damage()
		_assign_engagements()
	var previous_consolidation := consolidation
	for index in objectives.size():
		_capture(index, player)
		var objective := objectives[index]
		objective.held = mini(tuning.consolidation_seconds, objective.held + 1) if objective.owner == "allied" and not objective.contested else 0
	var held_times := objectives.map(func(objective): return objective.held)
	held_times.sort()
	consolidation = held_times[-REQUIRED_OBJECTIVES]
	if consolidation > 0 and previous_consolidation == 0:
		_notice("Consolidation started. Hold both objectives.")
	elif consolidation == 0 and previous_consolidation > 0:
		_notice("Consolidation interrupted. Secure two objectives again.")
	if allow_victory and consolidation >= tuning.consolidation_seconds:
		complete = true
		_notice(outcome().grade + " · FTL route secured.")


func _assign_engagements(announce: bool = false) -> void:
	var radius_squared: float = tuning.engagement_radius * tuning.engagement_radius
	for fleet in fleets:
		var previous: int = fleet.engaged
		fleet.engaged = -1
		if not active(fleet) or fleet.get("withdrawing", false):
			continue
		var existing := fleet_at(previous)
		if is_lattice() and active(existing) and not existing.get("withdrawing", false) and fleet.position.distance_squared_to(existing.position) < radius_squared:
			fleet.engaged = previous
			continue
		var nearest := radius_squared
		for other in fleets:
			if fleet.side == other.side or not active(other) or other.get("withdrawing", false):
				continue
			var distance: float = (fleet.position as Vector3).distance_squared_to(other.position)
			if distance < nearest:
				nearest = distance
				fleet.engaged = other.id
		if announce and previous < 0 and fleet.engaged >= 0 and fleet.side == "allied":
			_notice("Allied %s engaged near %s." % [fleet.role, objective_name(fleet.destination)])


func _exchange_damage() -> void:
	volley_tick = clock_ms
	volley.clear()
	var damage := PackedInt32Array()
	damage.resize(fleets.size())
	for fleet in fleets:
		if active(fleet) and fleet.engaged >= 0:
			volley.append(Vector2i(fleet.id, fleet.engaged))
			damage[fleet.engaged] += 2 if fleet.strength >= tuning.heavy_damage_strength else 1
	for fleet in fleets:
		if damage[fleet.id] > 0:
			_damage(fleet, damage[fleet.id])


func _damage(fleet: Dictionary, damage: int) -> void:
	if not active(fleet):
		return
	fleet.strength = maxi(0, fleet.strength - damage)
	if not active(fleet):
		fleet.engaged = -1
		_notice("%s %s destroyed." % [fleet.side.capitalize(), fleet.role])


func _capture_allowed(_index: int, _side: String, _player: Vector3) -> bool:
	return true


# A separate hook leaves legacy Warzone captures at six seconds while the
# lattice can require longer for an unsupported player ship.
func capture_requirement(_index: int, _side: String, _player: Vector3) -> int:
	return tuning.capture_seconds


func _capture_save_limit(configuration: Resource) -> int:
	return configuration.capture_seconds - 1


func _capture(index: int, player: Vector3) -> void:
	var objective := objectives[index]
	var allied: bool = player.distance_to(objective.position) <= tuning.objective_radius
	var hostile := false
	for fleet in fleets:
		if not active(fleet) or fleet.get("withdrawing", false) or (fleet.position as Vector3).distance_to(objective.position) > tuning.objective_radius:
			continue
		allied = allied or fleet.side == "allied"
		hostile = hostile or fleet.side == "hostile"
	var contested := allied and hostile
	if contested and not objective.contested:
		_notice(objective_name(index) + " contested.")
	objective.contested = contested
	var side := "neutral"
	if allied != hostile:
		side = "allied" if allied else "hostile"
	if side == "neutral" or side == objective.owner or not _capture_allowed(index, side, player):
		objective.progress = 0
		objective.capturing = "neutral"
		return
	objective.progress = objective.progress + 1 if objective.capturing == side else 1
	objective.capturing = side
	if objective.progress >= capture_requirement(index, side, player):
		objective.owner = side
		objective.capturing = "neutral"
		objective.progress = 0
		_notice("%s captured %s." % [side.capitalize(), objective_name(index)])
		if side == "allied":
			_counterattack(index)


func _reassess_orders() -> void:
	for fleet in fleets:
		if not active(fleet) or fleet.engaged >= 0 or fleet.role not in ["Assault", "Vanguard", "Reinforcement"]:
			continue
		var index: int = fleet.destination
		if objectives[index].owner != fleet.side or (fleet.position as Vector3).distance_squared_to(objectives[index].position) > 0.01:
			continue
		if _needs_garrison(fleet, index):
			continue
		for step in range(1, objectives.size()):
			var next := (index + step) % objectives.size()
			if objectives[next].owner != fleet.side:
				fleet.destination = next
				break


func _needs_garrison(fleet: Dictionary, index: int) -> bool:
	var incoming := fleets.any(func(other):
		return active(other) and other.side != fleet.side and other.destination == index)
	if not incoming: return false
	var site: Vector3 = objectives[index].position
	return not fleets.any(func(other):
		return active(other) and other.id != fleet.id and other.side == fleet.side and other.destination == index \
			and (other.position as Vector3).distance_to(site) <= tuning.objective_radius)


func _counterattack(index: int) -> void:
	var target: Vector3 = objectives[index].position
	var available := fleets.filter(func(fleet): return fleet.side == "hostile" and active(fleet) and fleet.engaged < 0)
	# Keep the final defensive group at its own station if it has no relief.
	if available.size() == 1 and fleet_count("hostile") == 1:
		var guard: Dictionary = available[0]
		if guard.role == "Defender" and fleet_status(guard) == "Defending":
			return
	available.sort_custom(func(a, b):
		var distance_a: float = target.distance_squared_to(a.position)
		var distance_b: float = target.distance_squared_to(b.position)
		return a.id < b.id if is_equal_approx(distance_a, distance_b) else distance_a < distance_b)
	var redirected := false
	for fleet in available.slice(0, 2):
		if fleet.destination != index:
			fleet.destination = index
			redirected = true
	if redirected:
		_notice("Hostile counterattack launched toward %s." % objective_name(index))


func allied_support(hostile_id: int) -> Dictionary:
	var hostile := fleet_at(hostile_id)
	if not active(hostile) or hostile.side != "hostile":
		return {}
	var ally := fleet_at(hostile.engaged)
	return ally if active(ally) and ally.side == "allied" else {}


func player_victory(hostile_id: int, _qualifies_for_income: bool = true) -> bool:
	var hostile := fleet_at(hostile_id)
	if complete or not active(hostile) or hostile.side != "hostile":
		return false
	_damage(hostile, hostile.strength)
	player_victories += 1
	_assign_engagements()
	return true


func player_defeat(hostile_id: int, hull_fraction: float, draw: bool) -> void:
	var hostile := fleet_at(hostile_id)
	if not active(hostile): return
	var remaining: int = ceili(hostile.strength * clampf(hull_fraction, 0.0, 1.0))
	if not draw: remaining = maxi(1, remaining)
	if remaining < hostile.strength:
		_damage(hostile, hostile.strength - remaining)
		if remaining > 0:
			_notice("Hostile %s weakened by the intervention." % hostile.role)
	_assign_engagements()


func intervention_summary(hostile_id: int, ally_id: int, prior_strength: int, event_start: int, won: bool, escaped: bool) -> String:
	var hostile := fleet_at(hostile_id)
	var status := "Hostile fleet disabled" if escaped else "Hostile fleet defeated"
	if not won:
		status = "Hostile fleet remains · Strength %d" % hostile.strength if active(hostile) else "Hostile fleet destroyed"
	var lines := PackedStringArray([status])
	if ally_id >= 0:
		var ally := fleet_at(ally_id)
		lines.append("Allied %s · %d → %d strength" % [ally.role, prior_strength, ally.strength])
	lines.append("%s · %s" % [objective_name(hostile.destination), objective_brief(hostile.destination)])
	for event in events_since(event_start).slice(-2 if event_revision - event_start >= 2 else 0):
		if event != "Hostile %s destroyed." % hostile.role:
			lines.append(event)
	return "\n".join(lines)


func outcome() -> Dictionary:
	var allied_strength := 0
	var hostile_strength := 0
	for fleet in fleets:
		if fleet.side == "allied":
			allied_strength += fleet.strength
		else:
			hostile_strength += fleet.strength
	var survival := float(allied_strength) / maxi(1, initial_allied_strength)
	var grade := "Pyrrhic Victory"
	var salvage: int = tuning.pyrrhic_salvage
	if survival >= tuning.decisive_survival:
		grade = "Decisive Victory"
		salvage = tuning.decisive_salvage
	elif survival >= tuning.hard_fought_survival:
		grade = "Hard-Fought Victory"
		salvage = tuning.hard_fought_salvage
	return {"secured": complete, "grade": grade if complete else "", "objective_count": controlled(),
		"allied_fleets": fleet_count("allied"), "allied_strength": allied_strength,
		"hostile_strength": hostile_strength, "player_victories": player_victories,
		"clock_ms": clock_ms, "salvage": salvage if complete else 0, "survival": survival}


func snapshot() -> Dictionary:
	var data := {"clock_ms": clock_ms, "travel_ms_remainder": travel_ms_remainder,
		"consolidation": consolidation, "player_victories": player_victories,
		"complete": complete, "initial_allied_strength": initial_allied_strength,
		"objectives": [], "fleets": [], "events": events.duplicate()}
	for records in [[objectives, data.objectives], [fleets, data.fleets]]:
		for record in records[0]:
			var copy: Dictionary = record.duplicate()
			copy.position = Defense.wire(copy.position)
			records[1].append(copy)
	return data


func _valid_objective_count(count: int) -> bool:
	return count == OBJECTIVES.size()


func _valid_consolidation(objective_records: Array[Dictionary], saved: int) -> bool:
	var held := objective_records.map(func(objective): return objective.held)
	held.sort()
	return held[-REQUIRED_OBJECTIVES] == saved


func _valid_fleet_count(count: int) -> bool:
	return count == ALLIED_GROUPS + HOSTILE_GROUPS


func _fleet_side(id: int) -> String:
	return "allied" if id < ALLIED_GROUPS else "hostile"


func encounter_for_fleet(fleet: Dictionary) -> int:
	return int(fleet.id) - ALLIED_GROUPS if fleet.side == "hostile" else -1


func restore(data: Variant, configuration: Resource) -> bool:
	if not data is Dictionary or not data.get("complete") is bool:
		return false
	for key in ["clock_ms", "consolidation", "player_victories", "initial_allied_strength"]:
		if not Defense.number(data.get(key), 0, 1000000000):
			return false
	if not data.get("objectives") is Array or not _valid_objective_count(data.objectives.size()):
		return false
	if not data.get("fleets") is Array or not _valid_fleet_count(data.fleets.size()):
		return false
	if not data.get("events") is Array or data.events.size() > MAX_EVENTS:
		return false
	for event in data.events:
		if not event is String or event.length() > 200:
			return false
	if data.consolidation > configuration.consolidation_seconds or data.complete != (data.consolidation == configuration.consolidation_seconds):
		return false
	var remainder: Variant = data.get("travel_ms_remainder", 0.0)
	if not (remainder is float or remainder is int) or not is_finite(remainder) or remainder < 0 or remainder >= 1:
		return false
	var restored_objectives: Array[Dictionary] = []
	for objective in data.objectives:
		if not objective is Dictionary or not Navigation.valid_point(objective.get("position"), false):
			return false
		if objective.get("owner") not in OWNER or objective.get("capturing") not in OWNER or not objective.get("contested") is bool:
			return false
		if not Defense.number(objective.get("progress"), 0, _capture_save_limit(configuration)):
			return false
		if not Defense.number(objective.get("held"), 0, configuration.consolidation_seconds):
			return false
		if objective.held > 0 and (objective.owner != "allied" or objective.contested):
			return false
		var copy: Dictionary = objective.duplicate()
		copy.position = Defense.point(copy.position)
		copy.progress = int(copy.progress)
		copy.held = int(copy.held)
		restored_objectives.append(copy)
	if not _valid_consolidation(restored_objectives, int(data.consolidation)):
		return false
	var restored_fleets: Array[Dictionary] = []
	for fleet in data.fleets:
		if not fleet is Dictionary or not Navigation.valid_point(fleet.get("position"), false):
			return false
		var expected_side := _fleet_side(restored_fleets.size())
		if fleet.get("id") != restored_fleets.size() or fleet.get("side") != expected_side or fleet.get("role") not in ROLES:
			return false
		if not Defense.number(fleet.get("destination"), 0, restored_objectives.size() - 1) or not Defense.number(fleet.get("engaged"), -1, data.fleets.size() - 1):
			return false
		if not Defense.number(fleet.get("strength"), 0, 1000000):
			return false
		var copy: Dictionary = fleet.duplicate()
		copy.position = Defense.point(copy.position)
		for key in ["id", "destination", "engaged", "strength"]:
			copy[key] = int(copy[key])
		restored_fleets.append(copy)
	for fleet in restored_fleets:
		if fleet.engaged >= 0:
			var target := restored_fleets[fleet.engaged]
			if target.side == fleet.side or target.strength == 0 or fleet.strength == 0:
				return false
	tuning = configuration
	objectives = restored_objectives
	fleets = restored_fleets
	events.assign(data.events)
	event_revision = events.size()
	clock_ms = int(data.clock_ms)
	travel_ms_remainder = float(remainder)
	consolidation = int(data.consolidation)
	player_victories = int(data.player_victories)
	initial_allied_strength = int(data.initial_allied_strength)
	complete = data.complete
	volley.clear()
	motion_samples.clear()
	volley_tick = 0
	return true
