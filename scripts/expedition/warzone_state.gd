extends RefCounted
## Fleet and objective state. Advances only on committed strategic time.

const Defense = preload("res://scripts/expedition/defense_state.gd")
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
const REQUIRED_OBJECTIVES := 2
const STEP_MS := 1000
const MAX_EVENTS := 8
const OWNER := ["allied", "hostile", "neutral"]
const OBJECTIVES := ["Communications Relay", "Shipyard", "Defense Array"]
const ROLES := ["Defender", "Vanguard", "Assault", "Patrol", "Reinforcement"]
const START := Vector3(-20, 0, 11)

var tuning: Resource
var objectives: Array[Dictionary] = []
var fleets: Array[Dictionary] = []
var events: Array[String] = []
var clock_ms := 0
var consolidation := 0
var player_victories := 0
var initial_allied_strength := 0
var complete := false


func setup(configuration: Resource, strength: int, expansion: float = 1.0) -> void:
	tuning = configuration
	objectives.clear()
	fleets.clear()
	events.clear()
	clock_ms = 0
	consolidation = 0
	player_victories = 0
	complete = false
	initial_allied_strength = 2 * strength
	for point in [Vector3(-15, 0, 8), Vector3(12, 0, -13), Vector3(14, 0, 13)]:
		objectives.append({"position": point * expansion, "owner": "allied" if objectives.is_empty() else "hostile",
			"contested": false, "capturing": "neutral", "progress": 0})
	_add_fleet("allied", "Defender", objectives[0].position, 0, strength)
	_add_fleet("allied", "Vanguard", Vector3(-11, 0, -3) * expansion, 1, strength)
	_add_fleet("hostile", "Assault", Vector3(-6, 0, 8) * expansion, 0, tuning.hostile_strength)
	_add_fleet("hostile", "Reinforcement", Vector3(3, 0, 9) * expansion, 0, tuning.hostile_strength)
	_add_fleet("hostile", "Patrol", objectives[1].position, 1, tuning.hostile_strength)
	_add_fleet("hostile", "Defender", objectives[2].position, 2, tuning.hostile_strength)
	_add_fleet("hostile", "Assault", Vector3(3, 0, -9) * expansion, 1, tuning.hostile_strength)
	_notice("Reinforcements arrived near the Communications Relay.")


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


func _notice(message: String) -> void:
	events.append(message)
	if events.size() > MAX_EVENTS:
		events.pop_front()


# Evaluate positions at fixed one-second boundaries along committed movement.
# The full clock includes the sub-second remainder and survives a save.
func advance(milliseconds: int, from: Vector3, to: Vector3) -> void:
	if complete or milliseconds <= 0:
		return
	var start_ms := clock_ms
	var end_ms := start_ms + milliseconds
	var tick_ms := start_ms - posmod(start_ms, STEP_MS) + STEP_MS
	while tick_ms <= end_ms:
		clock_ms = tick_ms
		_tick(from.lerp(to, float(tick_ms - start_ms) / milliseconds))
		if complete:
			return
		tick_ms += STEP_MS
	clock_ms = end_ms


func _tick(player: Vector3) -> void:
	_assign_engagements()
	for fleet in fleets:
		if not active(fleet) or fleet.engaged >= 0:
			continue
		var destination: Vector3 = objectives[fleet.destination].position
		fleet.position = (fleet.position as Vector3).move_toward(destination, tuning.fleet_speed)
	_assign_engagements(true)
	if roundi(float(clock_ms) / STEP_MS) % maxi(1, tuning.exchange_seconds) == 0:
		_exchange_damage()
		_assign_engagements()
	for index in objectives.size():
		_capture(index, player)
	consolidation = consolidation + 1 if controlled() >= REQUIRED_OBJECTIVES else 0
	if consolidation >= tuning.consolidation_seconds:
		complete = true
		_notice(outcome().grade + " · FTL route secured.")


func _assign_engagements(announce: bool = false) -> void:
	var radius_squared: float = tuning.engagement_radius * tuning.engagement_radius
	for fleet in fleets:
		var previous: int = fleet.engaged
		fleet.engaged = -1
		if not active(fleet):
			continue
		var nearest := radius_squared
		for other in fleets:
			if fleet.side == other.side or not active(other):
				continue
			var distance: float = (fleet.position as Vector3).distance_squared_to(other.position)
			if distance < nearest:
				nearest = distance
				fleet.engaged = other.id
		if announce and previous < 0 and fleet.engaged >= 0 and fleet.side == "allied":
			_notice("Allied %s engaged near %s." % [fleet.role, OBJECTIVES[fleet.destination]])


func _exchange_damage() -> void:
	var damage := PackedInt32Array()
	damage.resize(fleets.size())
	for fleet in fleets:
		if active(fleet) and fleet.engaged >= 0:
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


func _capture(index: int, player: Vector3) -> void:
	var objective := objectives[index]
	var allied: bool = player.distance_to(objective.position) <= tuning.objective_radius
	var hostile := false
	for fleet in fleets:
		if not active(fleet) or (fleet.position as Vector3).distance_to(objective.position) > tuning.objective_radius:
			continue
		allied = allied or fleet.side == "allied"
		hostile = hostile or fleet.side == "hostile"
	var contested := allied and hostile
	if contested and not objective.contested:
		_notice(OBJECTIVES[index] + " contested.")
	objective.contested = contested
	var side := "neutral"
	if allied != hostile:
		side = "allied" if allied else "hostile"
	if side == "neutral" or side == objective.owner:
		objective.progress = 0
		objective.capturing = "neutral"
		return
	objective.progress = objective.progress + 1 if objective.capturing == side else 1
	objective.capturing = side
	if objective.progress >= tuning.capture_seconds:
		objective.owner = side
		objective.capturing = "neutral"
		objective.progress = 0
		_notice("%s captured %s." % [side.capitalize(), OBJECTIVES[index]])
		_retask(index, side)


func _retask(index: int, side: String) -> void:
	# Defenders hold their area. Assault and vanguard groups advance along the
	# predetermined objective cycle once the current order is satisfied.
	for fleet in fleets:
		if fleet.side != side or fleet.destination != index or fleet.role not in ["Assault", "Vanguard"]:
			continue
		for step in range(1, objectives.size()):
			var next := (index + step) % objectives.size()
			if objectives[next].owner != side:
				fleet.destination = next
				break


func allied_support(hostile_id: int) -> Dictionary:
	var hostile := fleet_at(hostile_id)
	if not active(hostile) or hostile.side != "hostile":
		return {}
	var ally := fleet_at(hostile.engaged)
	return ally if active(ally) and ally.side == "allied" else {}


func player_victory(hostile_id: int) -> bool:
	var hostile := fleet_at(hostile_id)
	if complete or not active(hostile) or hostile.side != "hostile":
		return false
	_damage(hostile, hostile.strength)
	player_victories += 1
	_assign_engagements()
	return true


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
	var data := {"clock_ms": clock_ms, "consolidation": consolidation, "player_victories": player_victories,
		"complete": complete, "initial_allied_strength": initial_allied_strength,
		"objectives": [], "fleets": [], "events": events.duplicate()}
	for records in [[objectives, data.objectives], [fleets, data.fleets]]:
		for record in records[0]:
			var copy: Dictionary = record.duplicate()
			copy.position = Defense.wire(copy.position)
			records[1].append(copy)
	return data


func restore(data: Variant, configuration: Resource) -> bool:
	if not data is Dictionary or not data.get("complete") is bool:
		return false
	for key in ["clock_ms", "consolidation", "player_victories", "initial_allied_strength"]:
		if not Defense.number(data.get(key), 0, 1000000000):
			return false
	if not data.get("objectives") is Array or data.objectives.size() != OBJECTIVES.size():
		return false
	if not data.get("fleets") is Array or data.fleets.size() != 7:
		return false
	if not data.get("events") is Array or data.events.size() > MAX_EVENTS:
		return false
	for event in data.events:
		if not event is String or event.length() > 200:
			return false
	if data.consolidation > configuration.consolidation_seconds or data.complete != (data.consolidation == configuration.consolidation_seconds):
		return false
	var restored_objectives: Array[Dictionary] = []
	for objective in data.objectives:
		if not objective is Dictionary or not Navigation.valid_point(objective.get("position"), false):
			return false
		if objective.get("owner") not in OWNER or objective.get("capturing") not in OWNER or not objective.get("contested") is bool:
			return false
		if not Defense.number(objective.get("progress"), 0, configuration.capture_seconds - 1):
			return false
		var copy: Dictionary = objective.duplicate()
		copy.position = Defense.point(copy.position)
		copy.progress = int(copy.progress)
		restored_objectives.append(copy)
	var restored_fleets: Array[Dictionary] = []
	for fleet in data.fleets:
		if not fleet is Dictionary or not Navigation.valid_point(fleet.get("position"), false):
			return false
		if fleet.get("id") != restored_fleets.size() or fleet.get("side") not in ["allied", "hostile"] or fleet.get("role") not in ROLES:
			return false
		if not Defense.number(fleet.get("destination"), 0, OBJECTIVES.size() - 1) or not Defense.number(fleet.get("engaged"), -1, data.fleets.size() - 1):
			return false
		if not Defense.number(fleet.get("strength"), 0, 1000000):
			return false
		var copy: Dictionary = fleet.duplicate()
		copy.position = Defense.point(copy.position)
		for key in ["id", "destination", "engaged", "strength"]:
			copy[key] = int(copy[key])
		restored_fleets.append(copy)
	if restored_fleets.filter(func(fleet): return fleet.side == "allied").size() != 2:
		return false
	for fleet in restored_fleets:
		if fleet.engaged >= 0:
			var target := restored_fleets[fleet.engaged]
			if target.side == fleet.side or target.strength == 0 or fleet.strength == 0:
				return false
	tuning = configuration
	objectives = restored_objectives
	fleets = restored_fleets
	events.assign(data.events)
	clock_ms = int(data.clock_ms)
	consolidation = int(data.consolidation)
	player_victories = int(data.player_victories)
	initial_allied_strength = int(data.initial_allied_strength)
	complete = data.complete
	return true
