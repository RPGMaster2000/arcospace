extends "res://scripts/expedition/warzone_state.gd"
## Lattice rules for new sectors. The base state handles the existing clock, combat
## handoff, campaign outcome and historical three-objective saves.

const Lattice = preload("res://scripts/expedition/warzone_lattice.gd")
const Operations = preload("res://scripts/expedition/warzone_operations.gd")
const AlliedOrders = preload("res://scripts/expedition/warzone_allied_orders.gd")
const FLEET_LIMIT := 40
const MOVEMENT_STEP_MS := 100
const ALLIED_RESERVE := ALLIED_GROUPS + HOSTILE_GROUPS
const HOSTILE_RESERVE := ALLIED_RESERVE + 1
const REQUEST_FIRST := HOSTILE_RESERVE + 1
const REQUEST_LIMIT := 4
const PLAYER := -1
const Layout = preload("res://scripts/expedition/system_layout.gd")

var pattern := 0
var roles: Array[String] = []
var links: Array[Vector2i] = []
var disrupted := {}
var supplied: Dictionary = {"allied": [], "hostile": []}
var accomplishments := {}
var planned := {}
var effort := 0
var convoy := {}
var recovered := false
var wreckage := {}  # Older saves may still have pending wrecks.
var capture_cutoffs := {}
var reserve_launched := {}
var facility_cooldowns := {}
var final_command := -1
var player_intervened := false
var jam_until := 0
var offensive_target := -1
var offensive_until := 0
var scramble_until := 0
var scramble_site := -1
var _importance := {}
var _supply_signature: Array = []
var _player_position := Vector3.INF
var _route_cache := {}
# Alert is deliberately separate from War Effort. It only rises from player
# interventions, not autonomous allied captures.
var player_alert := 0
var player_hunter := -1
var hunter_until := 0
var hunter_contact_at := 0
var hunter_cooldown_until := 0
var hunter_count := 0
var response_sites: Array[int] = []


func is_lattice() -> bool:
	return true


func site(role: String) -> int:
	var index := roles.find(role) if not roles.is_empty() else Lattice.ROLES.find(role)
	return index if index < objectives.size() else -1


func role_index(index: int) -> int:
	return index if roles.is_empty() else Lattice.ROLES.find(roles[index])


func facility(index: int) -> String:
	return Lattice.FACILITIES[role_index(index)]


func command_sites() -> Array[int]:
	return [site("forward_command"), site("hostile_command")]


func root(side: String) -> int:
	return site("allied_command" if side == "allied" else "hostile_command")


func objective_name(index: int) -> String:
	return Lattice.TYPES[role_index(index)]


func objective_glyph(index: int) -> String:
	return Lattice.GLYPHS[role_index(index)]


func start_position(_expansion: float) -> Vector3:
	return objectives[site("allied_command")].position.lerp(objectives[site("junction")].position, 0.47)


func outpost_position(_expansion: float) -> Vector3:
	var origin: Vector3 = objectives[site("allied_command")].position
	return origin + (origin - (objectives[site("junction")].position as Vector3)).normalized() * 4.0


func reserve_entry(side: String, expansion: float) -> Vector3:
	var bounds := Layout.bounds(expansion)
	var origin: Vector3 = objectives[root(side)].position
	if roles.is_empty():
		return Vector3(bounds.position.x - 5.0 if side == "allied" else bounds.end.x + 5.0, 0, origin.z)
	var opponent: Vector3 = objectives[root("hostile" if side == "allied" else "allied")].position
	var direction := (origin - opponent).normalized()
	var edge_x := bounds.end.x if direction.x > 0 else bounds.position.x
	var edge_z := bounds.end.y if direction.z > 0 else bounds.position.y
	var distance_x := (edge_x - origin.x) / direction.x if absf(direction.x) > 0.001 else INF
	var distance_z := (edge_z - origin.z) / direction.z if absf(direction.z) > 0.001 else INF
	return origin + direction * (minf(distance_x, distance_z) + 5.0)


func setup_sector(configuration: Resource, strength: int, expansion: float, seed_value: int, system: int) -> void:
	tuning = configuration
	var generated := Lattice.generate(seed_value, system, expansion)
	objectives.assign(generated.nodes)
	links.assign(generated.links)
	roles.assign(generated.roles)
	pattern = generated.pattern
	initial_allied_strength = strength * ALLIED_GROUPS
	_add_front("allied", "Vanguard", site("allied_command"), site("junction"), strength, 0.47)
	_add_front("allied", "Vanguard", site("repair"), site("relay"), strength, 0.47)
	var hostile: int = maxi(tuning.hostile_strength, strength)
	_add_front("hostile", "Assault", site("junction"), site("allied_command"), hostile, 0.48)
	_add_front("hostile", "Patrol", site("relay"), site("repair"), hostile, 0.48)
	for deployment in [["Defender", "hostile_command", hostile],
			["Reinforcement", "shipyard", hostile - 2], ["Defender", "depot", hostile - 2]]:
		var at := site(deployment[1])
		_add_front("hostile", deployment[0], at, at, deployment[2], 0.0)
	for side in ["allied", "hostile"]:
		var at := root(side)
		_add_front(side, "Reinforcement", at, at, 0, 0.0)
		fleets.back().position = reserve_entry(side, expansion)
		fleets.back().arriving = false
	_refresh_supply()
	_assign_engagements(true)
	# Stations begin on their assigned nodes. Select the same onward order
	# that their first movement step would choose, without spending that step.
	for fleet in fleets:
		if active(fleet) and fleet.engaged < 0 and fleet.at == fleet.destination \
			and (fleet.position as Vector3).is_equal_approx(objectives[fleet.at].position):
			fleet.destination = _direct_target(fleet)
	_launch_convoy()
	_notice("%s · Allied forces are fighting on two fronts." % Lattice.PATTERNS[pattern])


func _add_front(side: String, role: String, at: int, next: int, strength: int, fraction: float) -> void:
	var position: Vector3 = objectives[at].position.lerp(objectives[next].position, fraction)
	_add_fleet(side, role, position, next, strength)
	fleets.back().at = at
	fleets.back().strength_limit = strength
	fleets.back().counter_target = -1
	fleets.back().withdrawing = false


func _refresh_supply(announce: bool = true) -> void:
	var signature := [objectives.map(func(node): return node.owner), disrupted.keys(), links.duplicate()]
	if signature != _supply_signature:
		_supply_signature = signature
		_importance.clear()
		_route_cache.clear()
		supplied.allied = Lattice.reachable(objectives, links, root("allied"), "allied", disrupted)
		supplied.hostile = Lattice.reachable(objectives, links, root("hostile"), "hostile", disrupted)
	for index in objectives.size():
		var site: Dictionary = objectives[index]
		if site.progress <= 0 or _capture_connected(index, site.capturing):
			continue
		var present := _capture_presence(index, site.capturing, _player_position)
		if not announce and site.capturing == "allied" and not present.has(PLAYER):
			present.append(PLAYER) # Historical saves may have had the player holding this site.
		capture_cutoffs[index] = {"side": site.capturing, "present": present}
		site.progress = 0
		site.capturing = "neutral"
		if announce: _notice("Capture link severed · " + objective_name(index))


func note_player_position(point: Vector3) -> void:
	_player_position = point


func _capture_connected(index: int, side: String) -> bool:
	return Lattice.neighbors(index, links, disrupted).any(func(site): return site in supplied.get(side, []))


func _capture_presence(index: int, side: String, player: Vector3) -> Array[int]:
	var present: Array[int] = []
	var position: Vector3 = objectives[index].position
	if side == "allied" and player.distance_to(position) <= tuning.objective_radius:
		present.append(PLAYER)
	for fleet in fleets:
		if fleet.side == side and active(fleet) and not fleet.withdrawing \
			and fleet.position.distance_to(position) <= tuning.objective_radius:
			present.append(fleet.id)
	return present


func _refresh_capture_presence(index: int, player: Vector3) -> void:
	var cutoff: Dictionary = capture_cutoffs.get(index, {})
	if not cutoff.is_empty():
		var present := _capture_presence(index, cutoff.side, player)
		if present.is_empty():
			capture_cutoffs.erase(index)
		else:
			cutoff.present = cutoff.present.filter(func(id): return id in present)


func capture_requirement(index: int, side: String, player: Vector3) -> int:
	if side == "allied" and player.distance_to(objectives[index].position) <= tuning.objective_radius:
		# A real allied formation on site completes the same job in six seconds.
		if _capture_presence(index, "allied", player).size() == 1:
			return tuning.capture_seconds * tuning.solo_capture_multiplier
	return tuning.capture_seconds


func _capture_save_limit(configuration: Resource) -> int:
	return configuration.capture_seconds * configuration.solo_capture_multiplier - 1


func player_capture_requirement(index: int, player: Vector3) -> int:
	return capture_requirement(index, "allied", player)


func _capture(index: int, player: Vector3) -> void:
	_refresh_capture_presence(index, player)
	var previous_progress: int = objectives[index].progress
	super._capture(index, player)
	if previous_progress == 0 and objectives[index].progress == 1 \
			and objectives[index].capturing == "allied" \
			and player.distance_to(objectives[index].position) <= tuning.objective_radius \
			and _capture_presence(index, "allied", player).size() == 1:
		_proactive_response(index, player)


# A warning and one existing patrol respond before a solo capture completes.
# Never spawn ships, remove an engaged combatant, or redirect a command defender.
func _proactive_response(index: int, player: Vector3) -> void:
	if index in response_sites or objectives[index].owner != "hostile":
		return
	if index not in command_sites() and index not in [site("shipyard"), site("depot")] and player_alert == 0:
		return
	var chosen := {}
	var best := tuning.response_range
	for fleet in fleets:
		if fleet.side != "hostile" or not active(fleet) or fleet.engaged >= 0 \
				or fleet.withdrawing or fleet.get("arriving", false) or fleet.role == "Defender" \
				or fleet.id == player_hunter or not _fleet_supplied(fleet) \
				or not route_valid("hostile", fleet.at, index):
			continue
		var distance: float = (fleet.position as Vector3).distance_to(player)
		if distance < best and distance > tuning.objective_radius:
			best = distance
			chosen = fleet
	if chosen.is_empty(): return
	response_sites.append(index)
	chosen.counter_target = index
	chosen.destination = index
	_notice("Hostile patrol responding to capture at %s." % objective_name(index))


func note_player_aggression(amount: int = 1) -> void:
	if complete or amount <= 0: return
	var previous: int = player_alert
	player_alert = mini(3, player_alert + amount)
	if previous < tuning.alert_to_hunt and player_alert >= tuning.alert_to_hunt:
		_notice("Hostile alert elevated · patrols searching for your ship.")


func _finish_player_hunt(reason: String = "") -> void:
	if player_hunter < 0: return
	var fleet := fleet_at(player_hunter)
	if active(fleet) and not fleet.withdrawing:
		fleet.counter_target = -1
		fleet.destination = fleet.at
	player_hunter = -1
	hunter_until = 0
	hunter_contact_at = 0
	hunter_cooldown_until = clock_ms + tuning.hunt_cooldown_seconds * STEP_MS
	player_alert = maxi(0, player_alert - 1)
	if not reason.is_empty(): _notice(reason)


func _update_player_hunt(player: Vector3) -> void:
	if player_hunter >= 0:
		var hunter := fleet_at(player_hunter)
		if not active(hunter) or hunter.withdrawing or hunter.engaged >= 0 \
				or not _fleet_supplied(hunter) or clock_ms >= hunter_until:
			_finish_player_hunt("Hostile pursuit disengaged.")
		else:
			return
	if player_alert < tuning.alert_to_hunt or hunter_count >= tuning.max_player_hunts \
			or clock_ms < hunter_cooldown_until or clock_ms < jam_until:
		return
	var chosen := {}
	var best := 1000000.0
	for fleet in fleets:
		if fleet.side != "hostile" or not active(fleet) or fleet.engaged >= 0 \
				or fleet.withdrawing or fleet.get("arriving", false) or fleet.role == "Defender" \
				or not _fleet_supplied(fleet):
			continue
		var distance: float = (fleet.position as Vector3).distance_to(player)
		if distance > tuning.objective_radius * 2.5 and distance < best:
			best = distance
			chosen = fleet
	if chosen.is_empty(): return
	player_hunter = chosen.id
	hunter_count += 1
	hunter_until = clock_ms + tuning.hunt_duration_seconds * STEP_MS
	hunter_contact_at = clock_ms + 3 * STEP_MS # Always show a warning before contact.
	chosen.counter_target = -1
	_notice("Hostile pursuit inbound · avoid or fight the marked patrol.")


func player_hunter_contact(player: Vector3) -> int:
	if player_hunter < 0 or clock_ms < hunter_contact_at: return -1
	var hunter := fleet_at(player_hunter)
	if not active(hunter) or hunter.engaged >= 0 or hunter.withdrawing: return -1
	return encounter_for_fleet(hunter) if (hunter.position as Vector3).distance_to(player) <= INTERCEPT_RADIUS else -1


func consume_player_hunter_contact() -> void:
	_finish_player_hunt("Hostile pursuit intercepted the player.")



func _capture_allowed(index: int, side: String, player: Vector3) -> bool:
	if not _capture_eligible(index, side, player): return false
	capture_cutoffs.erase(index)
	return true


func _capture_eligible(index: int, side: String, player: Vector3) -> bool:
	if not _capture_connected(index, side): return false
	var cutoff: Dictionary = capture_cutoffs.get(index, {})
	if cutoff.is_empty() or cutoff.side != side: return true
	return _capture_presence(index, side, player).any(func(id): return id not in cutoff.present)


func capture_hold_block(index: int, player: Vector3) -> String:
	if index < 0 or index >= objectives.size(): return "Objective unavailable"
	var objective: Dictionary = objectives[index]
	if objective.owner == "allied": return "Objective secured"
	if complete: return "Objective unavailable"
	if player.distance_to(objective.position) > tuning.objective_radius: return "Outside capture range"
	if not _capture_connected(index, "allied"): return "Supply disconnected"
	if not _capture_eligible(index, "allied", player): return "Leave and return to retry"
	if not _capture_presence(index, "hostile", player).is_empty(): return "Objective contested"
	return ""


func encounter_for_fleet(fleet: Dictionary) -> int:
	if fleet.id == HOSTILE_RESERVE:
		return HOSTILE_GROUPS + objectives.size()
	return super.encounter_for_fleet(fleet)


func has_reserves() -> bool:
	return fleets.size() >= REQUEST_FIRST


func _valid_fleet_count(count: int) -> bool:
	return super._valid_fleet_count(count) or count in range(REQUEST_FIRST, REQUEST_FIRST + REQUEST_LIMIT + 1)


func _fleet_side(id: int) -> String:
	return "allied" if id == ALLIED_RESERVE or id >= REQUEST_FIRST else super._fleet_side(id)


func _dispatch_reserves() -> void:
	if not has_reserves(): return
	for order in [[ALLIED_RESERVE, 22, root("allied")], [HOSTILE_RESERVE, 30, root("hostile")]]:
		var id: int = order[0]
		if reserve_launched.has(id) or clock_ms < order[1] * STEP_MS: continue
		if id == HOSTILE_RESERVE and clock_ms < jam_until: continue
		if id == ALLIED_RESERVE and fleet_count("allied") >= tuning.max_allied_fleets: continue
		var fleet := fleet_at(id)
		var network: Array = supplied[fleet.side]
		if network.size() < 2: continue
		_launch_reserve(fleet, order[2], network)


func reinforcement_lock() -> String:
	if not has_reserves() or supplied.allied.size() < 2:
		return "Requires a connected supply network"
	if fleets.size() - REQUEST_FIRST >= tuning.reinforcement_budget:
		return "Reinforcement budget spent"
	if fleet_count("allied") >= tuning.max_allied_fleets:
		return "Allied fleet limit reached"
	return ""


func deploy_allied(site: int) -> void:
	var entry := reserve_entry("allied", Layout.MAX_EXPANSION)
	_add_fleet("allied", "Reinforcement", entry, site, 0)
	_launch_reserve(fleets.back(), site, supplied.allied)


func scramble(site: int) -> void:
	scramble_until = clock_ms + tuning.scramble_seconds * STEP_MS
	scramble_site = site
	AlliedOrders.assign(self, true, true)


func allied_site_importance(index: int) -> float:
	if not _importance.has(index):
		var command := index in command_sites()
		var disconnected := 0
		if index in supplied.allied and index != root("allied"):
			var blocked := disrupted.duplicate()
			blocked[index] = true
			disconnected = maxi(0, supplied.allied.size() - 1 \
				- Lattice.reachable(objectives, links, root("allied"), "allied", blocked).size())
		_importance[index] = (8.0 if command else 2.0) + minf(9.0, disconnected * 3.0)
	return _importance[index]


func fleet_speed(fleet: Dictionary) -> float:
	return tuning.fleet_speed * (1.0 if _fleet_supplied(fleet) else 0.72)


func fleet_target_position(fleet: Dictionary) -> Vector3:
	if fleet.id == player_hunter and _player_position.is_finite():
		return _player_position
	var enemy := fleet_at(fleet.get("intercept", -1))
	if active(enemy) and not enemy.withdrawing:
		return AlliedOrders.interception_point(self, fleet, enemy)
	return objectives[fleet.destination].position


func fleet_order_text(fleet: Dictionary) -> String:
	if fleet.id == player_hunter: return "Player ship"
	var enemy := fleet_at(fleet.get("intercept", -1))
	if active(enemy) and not enemy.withdrawing:
		return "Hostile %s %d" % [enemy.role, enemy.id - ALLIED_GROUPS + 1]
	return objective_name(fleet.destination)


func fleet_status(fleet: Dictionary) -> String:
	if active(fleet) and fleet.id == player_hunter and fleet.engaged < 0: return "Pursuing"
	if active(fleet) and fleet.engaged < 0:
		if fleet.get("arriving", false): return "Reinforcing"
		if fleet.has("recover_until") and not fleet.withdrawing: return "Regrouping"
		if active(fleet_at(fleet.get("intercept", -1))): return fleet.assignment
	return super.fleet_status(fleet)


func _launch_reserve(fleet: Dictionary, root: int, network: Array) -> void:
	var strength := mini(6, 2 + network.size() + int(site("shipyard") in network))
	fleet.strength = strength
	fleet.strength_limit = strength
	fleet.at = root
	fleet.destination = root
	fleet.arriving = true
	fleet.withdrawing = false
	fleet.counter_target = -1
	fleet.engaged = -1
	if fleet.id < REQUEST_FIRST: reserve_launched[fleet.id] = true
	_notice("%s reinforcements entering the sector." % fleet.side.capitalize())


func is_supplied(index: int) -> bool:
	var owner: String = objectives[index].owner
	return index in supplied.get(owner, [])


func _fleet_supplied(fleet: Dictionary) -> bool:
	return fleet.at in supplied[fleet.side]


func link_active(link: Vector2i) -> bool:
	return not disrupted.has(link.x) and not disrupted.has(link.y)


func objective_brief(index: int) -> String:
	var status := super.objective_brief(index)
	var objective: Dictionary = objectives[index]
	if objective.progress > 0 and objective.capturing == "allied":
		status = "Allied capturing · %ds / %ds" % [objective.progress,
			player_capture_requirement(index, _player_position)]
	if disrupted.has(index): return status + " · disrupted %ds" % disrupted[index]
	return status + (" · supplied" if is_supplied(index) else " · isolated")


func _award(key: String, amount: int, reason: String) -> void:
	if accomplishments.has(key): return
	accomplishments[key] = amount
	effort += amount
	_notice("+%d War Effort · %s" % [amount, reason])


func motion_step_ms() -> int:
	return MOVEMENT_STEP_MS


func _advance_step(player: Vector3, allow_victory: bool) -> void:
	_player_position = player
	for index in capture_cutoffs.keys():
		_refresh_capture_presence(index, player)
	var second := clock_ms % STEP_MS == 0
	if second:
		for site in facility_cooldowns.keys():
			facility_cooldowns[site] -= 1
			if facility_cooldowns[site] <= 0: facility_cooldowns.erase(site)
		for site in disrupted.keys():
			disrupted[site] -= 1
			if disrupted[site] <= 0: disrupted.erase(site)
		_refresh_supply()
		_dispatch_reserves()
		_update_player_hunt(player)
	_assign_engagements(true)
	var expired := scramble_until > 0 and clock_ms >= scramble_until
	if expired:
		scramble_until = 0
		scramble_site = -1
		for fleet in fleets: AlliedOrders.clear_interception(self, fleet)
	if expired or clock_ms % AlliedOrders.INTERVAL_MS == 0:
		AlliedOrders.assign(self, scramble_until > clock_ms)
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
		if index != root("allied"): _capture(index, player)
		if before != objectives[index].owner:
			_refresh_supply()
			if objectives[index].owner == "allied":
				if player.distance_to(objectives[index].position) <= tuning.objective_radius:
					player_intervened = true
					note_player_aggression(2 if index in command_sites() else 1)
				var value: int = tuning.capture_effort + (4 if index in command_sites() else 0)
				_award("capture:%d" % index, value, "Captured " + objective_name(index))
				if supplied.allied.size() > prior.size() + 1:
					_award("reconnect:%d" % index, 6, "Reconnected allied installations")
	_update_convoy()
	for site in wreckage.keys():
		wreckage[site] -= 1
		if wreckage[site] <= 0: wreckage.erase(site)
	_update_final_offensive(allow_victory)


func _update_final_offensive(allow_victory: bool) -> void:
	if final_command < 0 and player_intervened and effort >= tuning.effort_goal:
		# A deep command facility anchors the last offensive. Prefer one we
		# already hold or can approach from supplied territory.
		var next: int = command_sites().front()
		for site in command_sites():
			if site in supplied.allied or _capture_connected(site, "allied"):
				next = site
				break
		final_command = next
		_notice("Final offensive · Secure " + objective_name(final_command) + ".")
		_counterattack(final_command)
	var can_hold := final_command >= 0 and _command_ready()
	# Battle time may advance the offensive, but victory commits only on the map.
	var limit: int = tuning.consolidation_seconds if allow_victory else tuning.consolidation_seconds - 1
	consolidation = mini(limit, consolidation + 1) if can_hold else 0
	if allow_victory and consolidation >= tuning.consolidation_seconds:
		complete = true
		_notice(outcome().grade + " · Sector secured.")


func _command_ready() -> bool:
	return final_command in supplied.allied and not objectives[final_command].contested


func _move_fleet(fleet: Dictionary, seconds: float = 1.0) -> void:
	if fleet.id == player_hunter and _player_position.is_finite() and not fleet.withdrawing:
		fleet.position = (fleet.position as Vector3).move_toward(
			_player_position, fleet_speed(fleet) * tuning.hunt_speed_multiplier * seconds)
		return
	if fleet.get("arriving", false):
		if supplied[fleet.side].size() < 2: return
		if fleet.destination not in supplied[fleet.side]:
			fleet.destination = root(fleet.side)
			fleet.at = fleet.destination
	if fleet.has("intercept"):
		var enemy := fleet_at(fleet.intercept)
		if active(enemy) and not enemy.withdrawing and _fleet_supplied(fleet):
			var position: Vector3 = fleet.position
			fleet.position = position.move_toward(fleet_target_position(fleet), fleet_speed(fleet) * seconds)
			return
		AlliedOrders.clear_interception(self, fleet)
	while seconds > 0.00001:
		var at: int = fleet.at
		var next: int = fleet.destination
		var position: Vector3 = fleet.position
		if at != next and not fleet.withdrawing and not route_valid(fleet.side, at, next):
			next = _direct_target(fleet)
			fleet.destination = next
		var target: Vector3 = objectives[next].position
		var distance := position.distance_to(target)
		if distance <= 0.00001:
			fleet.at = next
			if fleet.has("arriving"): fleet.arriving = false
			fleet.withdrawing = false
			if fleet.has("recover_until"):
				if clock_ms < fleet.recover_until or fleet.strength < AlliedOrders.MIN_RESPONSE_STRENGTH:
					return
				fleet.erase("recover_until")
			if objectives[next].owner != fleet.side and fleet.strength > 2 and _capture_connected(next, fleet.side):
				return
			fleet.destination = _direct_target(fleet)
			if fleet.destination == next:
				return
			continue
		var speed := fleet_speed(fleet)
		fleet.position = position.move_toward(target, speed * seconds)
		seconds -= distance / speed


func route_valid(side: String, origin: int, target: int) -> bool:
	if origin == target: return true
	var key := Vector3i(origin, target, int(side == "hostile"))
	if not _route_cache.has(key):
		_route_cache[key] = (objectives[target].owner == side or _capture_connected(target, side)) \
			and not _supply_route(side, origin, target, true).is_empty()
	return _route_cache[key]


func _direct_target(fleet: Dictionary) -> int:
	var at: int = fleet.at
	var side: String = fleet.side
	var retreat: bool = fleet.strength <= 2 or at not in supplied[side]
	var goal: int = -1 if side == "hostile" and clock_ms < jam_until else fleet.counter_target
	if not retreat and side == "allied":
		# Let a previously saved Coordinate Offensive finish on its old terms.
		if clock_ms < offensive_until and offensive_target >= 0 and route_valid(side, at, offensive_target):
			return offensive_target
		return AlliedOrders.frontier_target(self, fleet)
	if not retreat and goal >= 0 and goal != at and route_valid(side, at, goal):
		return goal
	if goal >= 0: fleet.counter_target = -1
	if retreat:
		var closest := INF
		var safe := at
		for site in supplied[side]:
			var distance: float = fleet.position.distance_squared_to(objectives[site].position)
			if distance < closest and route_valid(side, at, site):
				closest = distance
				safe = site
		return safe
	var queued: Array[int] = [at]
	var visited := {at: true}
	var cursor := 0
	while cursor < queued.size():
		var site := queued[cursor]
		cursor += 1
		for next in Lattice.neighbors(site, links, disrupted):
			if visited.has(next): continue
			visited[next] = true
			if objectives[next].owner == side:
				queued.append(next)
			elif fleet.role != "Defender" or side != "hostile" or objectives[next].owner == "allied":
				return next
	return at


func _counterattack(index: int) -> void:
	_refresh_supply()
	var candidates := fleets.filter(func(fleet):
		return (fleet.side == "hostile" and active(fleet) and fleet.engaged < 0
			and fleet.strength > 2 and fleet.at in supplied.hostile and route_valid("hostile", fleet.at, index)))
	var point: Vector3 = objectives[index].position
	candidates.sort_custom(func(a, b):
		var first: float = a.position.distance_squared_to(point)
		var second: float = b.position.distance_squared_to(point)
		return a.id < b.id if is_equal_approx(first, second) else first < second)
	for fleet in candidates.slice(0, 2):
		fleet.counter_target = index
	if not candidates.is_empty():
		if clock_ms < jam_until:
			_notice("Hostile counterattack orders delayed.")
		else:
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
			if supplied_fleet and fleet.strength < fleet.strength_limit and fleet.destination == fleet.at \
				and (not fleet.has("recover_until") or (fleet.position as Vector3).distance_squared_to(objectives[fleet.at].position) < 0.01):
				fleet.strength += 1
			continue
		volley.append(Vector2i(fleet.id, fleet.engaged))
		damage[fleet.engaged] += _shot_damage(fleet)
	for fleet in fleets:
		if damage[fleet.id] <= 0: continue
		_damage(fleet, damage[fleet.id])
		if not active(fleet) and fleet.side == "hostile":
			_award("fleet:%d" % fleet.id, tuning.npc_victory_effort, "Allied strategic victory")


func _shot_damage(fleet: Dictionary) -> int:
	var supported := _fleet_supplied(fleet)
	var damage := 2 if supported and (fleet.side == "hostile" or fleet.strength >= tuning.heavy_damage_strength) else 1
	if supported and fleet.side == "allied" and clock_ms < offensive_until:
		if (fleet.position as Vector3).distance_to(objectives[offensive_target].position) <= tuning.objective_radius * 2.0:
			damage += 1
	var target := fleet_at(fleet.engaged)
	if fleet.side == "hostile" and not target.is_empty():
		for site in facility_cooldowns:
			if facility(site) == "fortify" and site in supplied.allied \
				and (target.position as Vector3).distance_to(objectives[site].position) <= tuning.objective_radius:
				return maxi(1, damage - 1)
	return damage


# One forecast per connected fight. Estimate from the same per-target attrition
# as a volley. Estimates are conditional on the fleets keeping current targets.
func engagement_predictions() -> Dictionary:
	var predictions := {}
	var visited := {}
	for fleet in fleets:
		if not active(fleet) or fleet.engaged < 0 or visited.has(fleet.id): continue
		var component: Array[int] = [fleet.id]
		visited[fleet.id] = true
		var cursor := 0
		while cursor < component.size():
			var id := component[cursor]
			cursor += 1
			for member in fleets:
				if not active(member) or visited.has(member.id): continue
				if member.engaged == id or fleet_at(id).engaged == member.id:
					visited[member.id] = true
					component.append(member.id)
		var damage := {"allied": 0, "hostile": 0}
		var strength := {"allied": 0, "hostile": 0}
		var anchor := HOSTILE_RESERVE + 1
		for id in component:
			var member := fleet_at(id)
			strength[member.side] += member.strength
			if member.engaged in component: damage[member.side] += _shot_damage(member)
			if member.side == "hostile": anchor = mini(anchor, id)
		if damage.allied == 0 or damage.hostile == 0 or anchor > HOSTILE_RESERVE: continue
		var allied_endurance: float = float(strength.allied) / damage.hostile
		var hostile_endurance: float = float(strength.hostile) / damage.allied
		var intervals: int = tuning.exchange_seconds * STEP_MS
		var volleys := ceili(minf(allied_endurance, hostile_endurance))
		var remaining := intervals - posmod(clock_ms, intervals)
		predictions[anchor] = {
			"allied_share": allied_endurance / (allied_endurance + hostile_endurance),
			"seconds": ceili((remaining + (volleys - 1) * intervals) / float(STEP_MS))}
	return predictions


func player_victory(hostile_id: int) -> bool:
	if not super.player_victory(hostile_id): return false
	player_intervened = true
	note_player_aggression(1)
	_award("fleet:%d" % hostile_id, tuning.victory_effort, "Hostile formation defeated")
	return true


func allied_support(hostile_id: int) -> Dictionary:
	var ally := super.allied_support(hostile_id)
	if not ally.is_empty() and ally.at not in supplied.allied:
		ally = ally.duplicate()
		ally.strength = maxi(1, ally.strength - 2)
	return ally


func _launch_convoy(side: String = "hostile") -> void:
	var origin := root(side)
	var options: Array = supplied[side]
	var priorities := ["depot", "shipyard", "forward_command", "junction", "relay", "west_hub", "east_hub"] \
		if side == "hostile" else ["repair", "outpost", "junction", "relay", "shipyard", "forward_command"]
	for role in priorities:
		var site := site(role)
		if site not in options: continue
		var route := _supply_route(side, origin, site)
		if route.is_empty(): continue
		convoy = {"side": side, "origin": origin, "target": site, "route": route, "remaining": int(tuning.convoy_seconds)}
		return


func _supply_route(side: String, origin: int, target: int, allow_hostile_target: bool = false) -> Array[int]:
	if disrupted.has(origin): return []
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


func operate(index: int, action: Dictionary) -> void:
	Operations.apply(self, index, action)


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
	value.command_positions = [final_command] if final_command >= 0 and complete else command_sites().filter(func(id): return id in supplied.allied)
	value.node_owners = objectives.map(func(node): return node.owner)
	return value


func snapshot() -> Dictionary:
	var value := super.snapshot()
	value.lattice = {"version": 2 if roles.is_empty() else 3, "pattern": pattern, "links": links.map(func(edge): return [edge.x, edge.y]),
		"effort": effort, "accomplishments": accomplishments.duplicate(), "planned": planned.duplicate(),
		"disrupted": {}, "convoy": convoy.duplicate(true), "recovered": recovered, "wreckage": {},
		"reserve_launched": reserve_launched.keys(), "capture_cutoffs": {},
		"facility_cooldowns": {}, "player_intervened": player_intervened, "final_command": final_command,
		"jam_until": jam_until, "offensive_target": offensive_target, "offensive_until": offensive_until,
		"scramble_until": scramble_until, "scramble_site": scramble_site,
		"player_alert": player_alert, "player_hunter": player_hunter,
		"hunter_until": hunter_until, "hunter_contact_at": hunter_contact_at,
		"hunter_cooldown_until": hunter_cooldown_until, "hunter_count": hunter_count,
		"response_sites": response_sites.duplicate()}
	if not roles.is_empty(): value.lattice.roles = Array(roles)
	for key in facility_cooldowns: value.lattice.facility_cooldowns[str(key)] = facility_cooldowns[key]
	for key in disrupted: value.lattice.disrupted[str(key)] = disrupted[key]
	for key in wreckage: value.lattice.wreckage[str(key)] = wreckage[key]
	for key in capture_cutoffs: value.lattice.capture_cutoffs[str(key)] = capture_cutoffs[key].duplicate(true)
	return value


func _valid_objective_count(count: int) -> bool:
	return count >= Lattice.MIN_NODES and count <= Lattice.MAX_NODES


func _valid_consolidation(_records: Array[Dictionary], _saved: int) -> bool:
	# The lattice validates its connected command after restoring links and supply.
	return true


func restore(data: Variant, configuration: Resource) -> bool:
	if not data is Dictionary or not data.get("lattice") is Dictionary or not super.restore(data, configuration):
		return false
	var saved: Dictionary = data.lattice
	if not Defense.number(saved.get("version"), 2, 3): return false
	var version := int(saved.version)
	if not Defense.number(saved.get("pattern"), 0, 5 if version == 2 else Lattice.PATTERNS.size() - 1):
		return false
	if version == 2:
		if objectives.size() not in [9, 12]: return false
	else:
		var values: Variant = saved.get("roles")
		if not values is Array or values.size() != objectives.size(): return false
		for role in values:
			if role not in Lattice.ROLES or role in roles: return false
			roles.append(role)
		for role in Lattice.ROLES.slice(0, Lattice.MIN_NODES):
			if role not in roles: return false
		if objectives[root("allied")].owner != "allied": return false
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
		fleet.counter_target = int(fleet.counter_target)
		fleet.at = int(fleet.at)
		fleet.strength_limit = int(fleet.strength_limit)
		if fleet.has("intercept"):
			if fleet.side != "allied" or not Defense.number(fleet.intercept, ALLIED_GROUPS, HOSTILE_RESERVE) \
				or fleet_at(int(fleet.intercept)).get("side") != "hostile" \
				or fleet.get("assignment") not in ["Intercepting", "Assisting"] \
				or not Defense.number(fleet.get("commit_until"), 0, clock_ms + AlliedOrders.COMMIT_MS):
				return false
			fleet.intercept = int(fleet.intercept)
			fleet.commit_until = int(fleet.commit_until)
		if fleet.has("recover_until"):
			if fleet.side != "allied" or not Defense.number(fleet.recover_until, 0, clock_ms + AlliedOrders.RECOVERY_MS):
				return false
			fleet.recover_until = int(fleet.recover_until)
		if fleet.id >= REQUEST_FIRST and not fleet.get("arriving") is bool: return false
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
	if not _restore_logistics(saved) or not _restore_facilities(saved) or not _restore_player_alert(saved): return false
	_refresh_supply(false)
	if not convoy.is_empty() and not _convoy_route_valid(convoy.side, convoy.route): return false
	if not saved.has("final_command"):
		# Older active operations must secure a deep command; earned victories
		# already have a committed campaign outcome.
		if not complete: consolidation = 0
		return true
	if complete and final_command == -1: return true  # Previously earned legacy victory.
	return consolidation == 0 or (effort >= tuning.effort_goal and _command_ready())


# Optional v3 data: pre-change sectors load at Quiet, with no active hunter.
func _restore_player_alert(saved: Dictionary) -> bool:
	for pair in [["player_alert", 3], ["hunter_count", tuning.max_player_hunts]]:
		if not Defense.number(saved.get(pair[0], 0), 0, pair[1]): return false
	var hunter: Variant = saved.get("player_hunter", -1)
	if not Defense.number(hunter, -1, HOSTILE_RESERVE): return false
	if int(hunter) >= 0 and (not active(fleet_at(int(hunter))) \
			or fleet_at(int(hunter)).side != "hostile" or int(saved.get("hunter_count", 0)) == 0):
		return false
	for field in ["hunter_until", "hunter_contact_at", "hunter_cooldown_until"]:
		if not Defense.number(saved.get(field, 0), 0,
				clock_ms + maxi(tuning.hunt_duration_seconds, tuning.hunt_cooldown_seconds) * STEP_MS + 3000):
			return false
	var sites: Variant = saved.get("response_sites", [])
	if not sites is Array or sites.size() > objectives.size(): return false
	var unique_sites: Array[int] = []
	for node in sites:
		if not Defense.number(node, 0, objectives.size() - 1) or int(node) in unique_sites:
			return false
		unique_sites.append(int(node))
	player_alert = int(saved.get("player_alert", 0))
	player_hunter = int(hunter)
	hunter_until = int(saved.get("hunter_until", 0))
	hunter_contact_at = int(saved.get("hunter_contact_at", 0))
	hunter_cooldown_until = int(saved.get("hunter_cooldown_until", 0))
	hunter_count = int(saved.get("hunter_count", 0))
	response_sites = unique_sites
	for objective in objectives:
		if objective.capturing == "hostile" and objective.progress >= tuning.capture_seconds:
			return false
	return true


func _restore_facilities(saved: Dictionary) -> bool:
	var cooldowns: Variant = saved.get("facility_cooldowns", {})
	if not cooldowns is Dictionary or cooldowns.size() > objectives.size(): return false
	for key in cooldowns:
		if not str(key).is_valid_int() or not Defense.number(int(key), 0, objectives.size() - 1): return false
		var site := int(key)
		if not Defense.number(cooldowns[key], 1, maxi(35 if facility(site) == "deploy" else 0, Operations.cooldown(facility(site), tuning))): return false
		facility_cooldowns[site] = int(cooldowns[key])
	var intervened: Variant = saved.get("player_intervened", player_victories > 0 or not planned.is_empty())
	var command: Variant = saved.get("final_command", -1)
	var target: Variant = saved.get("offensive_target", -1)
	if not intervened is bool or not Defense.number(command, -1, objectives.size() - 1) \
		or (int(command) != -1 and (int(command) not in command_sites() or not intervened or effort < tuning.effort_goal)) \
		or not Defense.number(target, -1, objectives.size() - 1): return false
	for field in ["jam_until", "offensive_until"]:
		if not Defense.number(saved.get(field, 0), 0, clock_ms + 35 * STEP_MS): return false
	if int(saved.get("offensive_until", 0)) > clock_ms and int(target) < 0: return false
	player_intervened = intervened
	final_command = int(command)
	offensive_target = int(target)
	jam_until = int(saved.get("jam_until", 0))
	offensive_until = int(saved.get("offensive_until", 0))
	var deadline: Variant = saved.get("scramble_until", 0)
	var origin: Variant = saved.get("scramble_site", -1)
	if not Defense.number(deadline, 0, clock_ms + 60 * STEP_MS) \
		or not Defense.number(origin, -1, objectives.size() - 1): return false
	if int(deadline) > 0 and (int(origin) < 0 or facility(int(origin)) != "coordinate"): return false
	scramble_until = int(deadline)
	scramble_site = int(origin)
	return true


func _restore_logistics(saved: Dictionary) -> bool:
	for site in objectives:
		if site.progress > 0 and (site.capturing == "neutral" or site.capturing == site.owner): return false
	var launched: Variant = saved.get("reserve_launched", [])
	if not launched is Array or launched.size() > 2 or (not has_reserves() and not launched.is_empty()): return false
	for id in launched:
		if not Defense.number(id, ALLIED_RESERVE, HOSTILE_RESERVE) or reserve_launched.has(int(id)): return false
		reserve_launched[int(id)] = true
	if has_reserves():
		for id in [ALLIED_RESERVE, HOSTILE_RESERVE]:
			var reserve := fleet_at(id)
			if not reserve.get("arriving") is bool: return false
			if not reserve_launched.has(id) and (active(reserve) or reserve.arriving): return false
	var cutoffs: Variant = saved.get("capture_cutoffs", {})
	if not cutoffs is Dictionary or cutoffs.size() > objectives.size(): return false
	for key in cutoffs:
		if not str(key).is_valid_int() or not Defense.number(int(key), 0, objectives.size() - 1): return false
		var record: Variant = cutoffs[key]
		if not record is Dictionary or record.get("side") not in ["allied", "hostile"] or not record.get("present") is Array: return false
		if record.present.size() > fleets.size() + 1 or objectives[int(key)].progress > 0: return false
		var present: Array[int] = []
		for id in record.present:
			if not Defense.number(id, PLAYER, fleets.size() - 1) or int(id) in present: return false
			if (id == PLAYER and record.side != "allied") or (id != PLAYER and fleet_at(int(id)).side != record.side): return false
			present.append(int(id))
		capture_cutoffs[int(key)] = {"side": record.side, "present": present}
	return true
