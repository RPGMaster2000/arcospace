extends "res://scripts/expedition/warzone_state.gd"
## Lattice rules for new sectors. The base state handles the existing clock, combat
## handoff, campaign outcome and historical three-objective saves.

const Lattice = preload("res://scripts/expedition/warzone_lattice.gd")
const ALLIED_ROOT := 1
const HOSTILE_ROOT := 7
const COMMANDS := [4, 6]
const Operations = preload("res://scripts/expedition/warzone_operations.gd")
const FLEET_LIMIT := 40
const MOVEMENT_STEP_MS := 100

var pattern := 0
var links: Array[Vector2i] = []
var disrupted := {}
var supplied: Dictionary = {"allied": [], "hostile": []}
var accomplishments := {}
var planned := {}
var effort := 0
var convoy := {}
var recovered := false
var wreckage := {}


func is_lattice() -> bool:
	return true


func objective_name(index: int) -> String:
	return Lattice.TYPES[index]


func objective_glyph(index: int) -> String:
	return Lattice.GLYPHS[index]


func start_position(_expansion: float) -> Vector3:
	return objectives[1].position.lerp(objectives[4].position, 0.47)


func outpost_position(_expansion: float) -> Vector3:
	return objectives[1].position + (objectives[1].position - objectives[4].position).normalized() * 4.0


func setup_sector(configuration: Resource, strength: int, expansion: float, seed_value: int, system: int) -> void:
	tuning = configuration
	var generated := Lattice.generate(seed_value, system, expansion)
	objectives.assign(generated.nodes)
	links.assign(generated.links)
	pattern = generated.pattern
	initial_allied_strength = strength * ALLIED_GROUPS
	_add_front("allied", "Vanguard", 1, 4, strength, 0.47)
	_add_front("allied", "Vanguard", 0, 3, strength, 0.47)
	var hostile: int = maxi(tuning.hostile_strength, strength)
	_add_front("hostile", "Assault", 4, 1, hostile, 0.48)
	_add_front("hostile", "Patrol", 3, 0, hostile, 0.48)
	_add_front("hostile", "Defender", 7, 7, hostile, 0.0)
	_add_front("hostile", "Reinforcement", 8, 8, hostile - 2, 0.0)
	_add_front("hostile", "Defender", 5, 5, hostile - 2, 0.0)
	_refresh_supply()
	_assign_engagements(true)
	_launch_convoy()
	_notice("%s · Allied forces are fighting on two fronts." % Lattice.PATTERNS[pattern])


func _add_front(side: String, role: String, at: int, next: int, strength: int, fraction: float) -> void:
	var position: Vector3 = objectives[at].position.lerp(objectives[next].position, fraction)
	_add_fleet(side, role, position, next, strength)
	fleets.back().at = at
	fleets.back().strength_limit = strength
	fleets.back().counter_target = -1
	fleets.back().withdrawing = false


func _refresh_supply() -> void:
	supplied.allied = Lattice.reachable(objectives, links, ALLIED_ROOT, "allied", disrupted)
	supplied.hostile = Lattice.reachable(objectives, links, HOSTILE_ROOT, "hostile", disrupted)


func is_supplied(index: int) -> bool:
	var owner: String = objectives[index].owner
	return index in supplied.get(owner, [])


func _fleet_supplied(fleet: Dictionary) -> bool:
	return fleet.at in supplied[fleet.side]


func link_active(link: Vector2i) -> bool:
	return not disrupted.has(link.x) and not disrupted.has(link.y)


func objective_brief(index: int) -> String:
	var status := super.objective_brief(index)
	if disrupted.has(index): return status + " · disrupted %ds" % disrupted[index]
	if wreckage.has(index): status += " · wreckage"
	return status + (" · supplied" if is_supplied(index) else " · isolated")


func _award(key: String, amount: int, reason: String) -> void:
	if accomplishments.has(key): return
	accomplishments[key] = amount
	effort += amount
	_notice("+%d War Effort · %s" % [amount, reason])


func motion_step_ms() -> int:
	return MOVEMENT_STEP_MS


func _advance_step(player: Vector3, allow_victory: bool) -> void:
	var second := clock_ms % STEP_MS == 0
	if second:
		for site in disrupted.keys():
			disrupted[site] -= 1
			if disrupted[site] <= 0: disrupted.erase(site)
		_refresh_supply()
	_assign_engagements(true)
	for fleet in fleets:
		if active(fleet) and fleet.engaged < 0:
			_move_fleet(fleet, float(MOVEMENT_STEP_MS) / STEP_MS)
	_assign_engagements(true)
	if second:
		_tick(player, allow_victory)


func _tick(player: Vector3, allow_victory: bool) -> void:
	if (clock_ms / STEP_MS) % maxi(1, tuning.exchange_seconds) == 0:
		_exchange_damage()
		_assign_engagements()
	for index in objectives.size():
		var before: String = objectives[index].owner
		var prior: Array = supplied.allied.duplicate()
		# The emergency rendezvous remains an allied foothold even after a rout.
		if index != ALLIED_ROOT: _capture(index, player)
		if before != objectives[index].owner:
			_refresh_supply()
			if objectives[index].owner == "allied":
				var value: int = tuning.capture_effort + (4 if index in COMMANDS else 0)
				_award("capture:%d" % index, value, "Captured " + objective_name(index))
				if supplied.allied.size() > prior.size() + 1:
					_award("reconnect:%d" % index, 6, "Reconnected allied installations")
	_update_convoy()
	for site in wreckage.keys():
		wreckage[site] -= 1
		if wreckage[site] <= 0: wreckage.erase(site)
	var can_hold: bool = effort >= tuning.effort_goal and _command_ready()
	consolidation = mini(tuning.consolidation_seconds, consolidation + 1) if can_hold else 0
	if allow_victory and consolidation >= tuning.consolidation_seconds:
		complete = true
		_notice(outcome().grade + " · Sector secured.")


func _command_ready() -> bool:
	return COMMANDS.any(func(id): return id in supplied.allied and not objectives[id].contested)


func _move_fleet(fleet: Dictionary, seconds: float = 1.0) -> void:
	while seconds > 0.00001:
		var at: int = fleet.at
		var next: int = fleet.destination
		var position: Vector3 = fleet.position
		if at != next and not fleet.withdrawing and next not in Lattice.neighbors(at, links, disrupted):
			# A severed corridor sends ships back along the same segment.
			next = at
			fleet.destination = at
		var target: Vector3 = objectives[next].position
		var distance := position.distance_to(target)
		if distance <= 0.00001:
			fleet.at = next
			fleet.withdrawing = false
			if objectives[next].owner != fleet.side and not disrupted.has(next) and fleet.strength > 2:
				return
			fleet.destination = _next_hop(fleet)
			if fleet.destination == next:
				return
			continue
		var speed: float = tuning.fleet_speed * (1.0 if at in supplied[fleet.side] else 0.72)
		fleet.position = position.move_toward(target, speed * seconds)
		seconds -= distance / speed


func _next_hop(fleet: Dictionary) -> int:
	var at: int = fleet.at
	var side: String = fleet.side
	var retreat: bool = fleet.strength <= 2
	if retreat and at in supplied[side]: return at
	var goal: int = fleet.counter_target
	if not retreat and goal >= 0 and goal != at:
		var path := _supply_route(side, at, goal, true)
		if path.size() >= 2: return path[1]
	if goal >= 0: fleet.counter_target = -1
	var frontier: Array[int] = [at]
	var first := {at: at}
	var cursor := 0
	while cursor < frontier.size():
		var site := frontier[cursor]
		cursor += 1
		for next in Lattice.neighbors(site, links, disrupted):
			if first.has(next): continue
			first[next] = next if site == at else first[site]
			if retreat:
				var safe: bool = is_supplied(next) and objectives[next].owner == side
				if safe: return first[next]
			elif objectives[next].owner != side:
				if fleet.role == "Defender" and side == "hostile" and objectives[next].owner != "allied": continue
				return first[next]
			if objectives[next].owner == side: frontier.append(next)
	return at


func _counterattack(index: int) -> void:
	var candidates := fleets.filter(func(fleet):
		return (fleet.side == "hostile" and active(fleet) and fleet.engaged < 0
			and fleet.strength > 2 and _supply_route("hostile", fleet.at, index, true).size() >= 2))
	var point: Vector3 = objectives[index].position
	candidates.sort_custom(func(a, b):
		var first: float = a.position.distance_squared_to(point)
		var second: float = b.position.distance_squared_to(point)
		return a.id < b.id if is_equal_approx(first, second) else first < second)
	for fleet in candidates.slice(0, 2):
		fleet.counter_target = index
	if not candidates.is_empty():
		_notice("Hostile counterattack toward " + objective_name(index) + ".")


func _exchange_damage() -> void:
	volley_tick = clock_ms
	volley.clear()
	var damage := PackedInt32Array()
	damage.resize(fleets.size())
	for fleet in fleets:
		if not active(fleet): continue
		var supplied_fleet := _fleet_supplied(fleet)
		if fleet.engaged < 0:
			if supplied_fleet and fleet.strength < fleet.strength_limit and fleet.destination == fleet.at:
				fleet.strength += 1
			continue
		volley.append(Vector2i(fleet.id, fleet.engaged))
		var shot := 2 if supplied_fleet and (fleet.side == "hostile" or fleet.strength >= tuning.heavy_damage_strength) else 1
		damage[fleet.engaged] += shot
	for fleet in fleets:
		if damage[fleet.id] <= 0: continue
		_damage(fleet, damage[fleet.id])
		if not active(fleet) and fleet.side == "hostile":
			_award("fleet:%d" % fleet.id, tuning.victory_effort, "Allied strategic victory")


func _damage(fleet: Dictionary, damage: int) -> void:
	var was_active := active(fleet)
	super._damage(fleet, damage)
	if was_active and not active(fleet):
		wreckage[int(fleet.destination)] = 30


func player_victory(hostile_id: int) -> bool:
	if not super.player_victory(hostile_id): return false
	_award("fleet:%d" % hostile_id, tuning.victory_effort, "Hostile formation defeated")
	return true


func allied_support(hostile_id: int) -> Dictionary:
	var ally := super.allied_support(hostile_id)
	if not ally.is_empty() and ally.at not in supplied.allied:
		ally = ally.duplicate()
		ally.strength = maxi(1, ally.strength - 2)
	return ally


func _launch_convoy(side: String = "hostile") -> void:
	var origin := HOSTILE_ROOT if side == "hostile" else ALLIED_ROOT
	var options: Array = supplied[side]
	for site in [5, 8, 6, 4, 3] if side == "hostile" else [0, 2, 4, 3]:
		if site not in options: continue
		var route := _supply_route(side, origin, site)
		if route.is_empty(): continue
		convoy = {"side": side, "origin": origin, "target": site, "route": route, "remaining": int(tuning.convoy_seconds)}
		return


func _supply_route(side: String, origin: int, target: int, allow_hostile_target: bool = false) -> Array[int]:
	var queued: Array[int] = [origin]
	var previous := {origin: -1}
	var cursor := 0
	while cursor < queued.size():
		var node := queued[cursor]
		cursor += 1
		if node == target:
			var route: Array[int] = []
			while node >= 0:
				route.push_front(node)
				node = previous[node]
			return route
		for next in Lattice.neighbors(node, links, disrupted):
			if not previous.has(next) and (objectives[next].owner == side or allow_hostile_target and next == target):
				previous[next] = node
				queued.append(next)
	return []


func _convoy_route_valid(side: String, route: Array) -> bool:
	for i in route.size():
		var site: int = route[i]
		if site not in supplied[side]: return false
		if i > 0 and site not in Lattice.neighbors(route[i - 1], links, disrupted): return false
	return true


func convoy_position() -> Vector3:
	if convoy.is_empty(): return Vector3.ZERO
	var last: int = convoy.route.size() - 1
	var distance: float = (1.0 - float(convoy.remaining) / tuning.convoy_seconds) * last
	var index := mini(last - 1, floori(distance))
	return objectives[convoy.route[index]].position.lerp(objectives[convoy.route[index + 1]].position, distance - index)


func _update_convoy() -> void:
	if convoy.is_empty():
		if clock_ms % (24 * STEP_MS) == 0:
			_launch_convoy("allied" if (clock_ms / (24 * STEP_MS)) % 2 == 1 else "hostile")
		return
	if not _convoy_route_valid(convoy.side, convoy.route):
		if convoy.side == "hostile": _award("convoy_cut:%d" % convoy.target, 5, "Convoy route severed")
		_notice("Supply convoy aborted after losing its route.")
		convoy.clear()
		return
	convoy.remaining -= 1
	if convoy.remaining > 0: return
	if convoy.target in supplied[convoy.side] and convoy.origin in supplied[convoy.side]:
		for fleet in fleets:
			if active(fleet) and fleet.side == convoy.side and fleet.at in supplied[fleet.side]:
				fleet.strength = mini(fleet.strength_limit, fleet.strength + 1)
		_notice("Supply convoy delivered stores.")
	convoy.clear()


func operations(index: int, salvage: int) -> Array[Dictionary]:
	return Operations.options(self, index, salvage)


func operate(index: int, action: Dictionary) -> int:
	return Operations.apply(self, index, action)


func _scatter_garrison(index: int) -> void:
	for fleet in fleets:
		var distance: float = fleet.position.distance_to(objectives[index].position)
		if not active(fleet) or fleet.side != "hostile" or distance > tuning.objective_radius + 1.0:
			continue
		var exits := Lattice.neighbors(index, links)
		if exits.is_empty(): continue
		var destination: int = exits[-1]
		fleet.at = index
		fleet.destination = destination
		fleet.withdrawing = true
		fleet.strength = maxi(1, fleet.strength - 2)
	_assign_engagements()


func outcome() -> Dictionary:
	var value := super.outcome()
	value.survival = clampf(value.survival, 0.0, 1.0)
	value.effort = effort
	var infrastructure := planned.keys()
	var disruptions := disrupted.keys()
	infrastructure.sort()
	disruptions.sort()
	value.infrastructure = infrastructure
	value.disruptions = disruptions
	value.command_positions = COMMANDS.filter(func(id): return id in supplied.allied)
	value.node_owners = objectives.map(func(node): return node.owner)
	return value


func snapshot() -> Dictionary:
	var value := super.snapshot()
	value.lattice = {"version": 2, "pattern": pattern, "links": links.map(func(edge): return [edge.x, edge.y]),
		"effort": effort, "accomplishments": accomplishments.duplicate(), "planned": planned.duplicate(),
		"disrupted": {}, "convoy": convoy.duplicate(true), "recovered": recovered, "wreckage": {}}
	for key in disrupted: value.lattice.disrupted[str(key)] = disrupted[key]
	for key in wreckage: value.lattice.wreckage[str(key)] = wreckage[key]
	return value


func _valid_objective_count(count: int) -> bool:
	return count in [9, 12]


func _valid_consolidation(_records: Array[Dictionary], _saved: int) -> bool:
	# The lattice validates its connected command after restoring links and supply.
	return true


func restore(data: Variant, configuration: Resource) -> bool:
	if not data is Dictionary or not data.get("lattice") is Dictionary or not super.restore(data, configuration):
		return false
	var saved: Dictionary = data.lattice
	if saved.get("version") != 2 or not Defense.number(saved.get("pattern"), 0, Lattice.PATTERNS.size() - 1):
		return false
	if not saved.get("links") is Array or saved.links.size() > 24: return false
	links.clear()
	for pair in saved.links:
		if not pair is Array or pair.size() != 2 or not Defense.number(pair[0], 0, objectives.size() - 1) \
			or not Defense.number(pair[1], 0, objectives.size() - 1) or pair[0] >= pair[1]: return false
		var edge := Vector2i(int(pair[0]), int(pair[1]))
		if edge in links: return false
		links.append(edge)
	var all_nodes: Array[Dictionary] = []
	for node in objectives: all_nodes.append({"owner": "allied"})
	if Lattice.reachable(all_nodes, links, 0, "allied", {}).size() != objectives.size(): return false
	for fleet in fleets:
		if not Defense.number(fleet.get("at"), 0, objectives.size() - 1) \
			or not Defense.number(fleet.get("strength_limit"), fleet.strength, FLEET_LIMIT) \
			or not Defense.number(fleet.get("counter_target"), -1, objectives.size() - 1): return false
		if not fleet.get("withdrawing") is bool: return false
		if fleet.at != fleet.destination and fleet.destination not in Lattice.neighbors(int(fleet.at), links): return false
		fleet.counter_target = int(fleet.counter_target)
		fleet.at = int(fleet.at)
		fleet.strength_limit = int(fleet.strength_limit)
	if not Defense.number(saved.get("effort"), 0, 1000) or not saved.get("recovered") is bool:
		return false
	for key in ["accomplishments", "planned", "disrupted", "convoy"]:
		if not saved.get(key) is Dictionary or saved[key].size() > 60: return false
	var total := 0
	for key in saved.accomplishments:
		if not key is String or not Defense.number(saved.accomplishments[key], 1, 50): return false
		total += int(saved.accomplishments[key])
	if total != int(saved.effort): return false
	for key in saved.planned:
		if not key is String or saved.planned[key] != true: return false
	for key in saved.disrupted:
		if not str(key).is_valid_int() or not Defense.number(int(key), 0, objectives.size() - 1) \
			or not Defense.number(saved.disrupted[key], 1, tuning.sabotage_seconds): return false
		disrupted[int(key)] = int(saved.disrupted[key])
	if not saved.get("wreckage") is Dictionary or saved.wreckage.size() > objectives.size(): return false
	for key in saved.wreckage:
		if not str(key).is_valid_int() or not Defense.number(int(key), 0, objectives.size() - 1) \
			or not Defense.number(saved.wreckage[key], 1, 30): return false
		wreckage[int(key)] = int(saved.wreckage[key])
	if not saved.convoy.is_empty():
		var record: Dictionary = saved.convoy
		if record.get("side") not in ["allied", "hostile"] or not record.get("route") is Array \
			or record.route.size() < 2 or record.route.size() > objectives.size() \
			or not Defense.number(record.get("remaining"), 1, tuning.convoy_seconds): return false
		var route: Array[int] = []
		for id in record.route:
			if not Defense.number(id, 0, objectives.size() - 1) or int(id) in route: return false
			route.append(int(id))
		if record.get("origin") != route.front() or record.get("target") != route.back(): return false
		convoy = {"side": record.side, "origin": route.front(), "target": route.back(),
			"route": route, "remaining": int(record.remaining)}
	pattern = int(saved.pattern)
	effort = total
	accomplishments.clear()
	for key in saved.accomplishments:
		accomplishments[key] = int(saved.accomplishments[key])
	planned = saved.planned.duplicate()
	recovered = saved.recovered
	_refresh_supply()
	if not convoy.is_empty() and not _convoy_route_valid(convoy.side, convoy.route): return false
	return consolidation == 0 or (effort >= tuning.effort_goal and _command_ready())
