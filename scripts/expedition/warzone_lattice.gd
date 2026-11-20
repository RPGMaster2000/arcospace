extends RefCounted
## Deterministic sector geometry and graph queries. Node ownership is owned by WarzoneState.

const Layout = preload("res://scripts/expedition/system_layout.gd")
const PATTERNS := ["Central Bottleneck", "Multiple Fronts", "Encirclement",
	"Branching Front", "Long Supply Corridor", "Fragmented Battlefield", "Asymmetric Sector"]
const ROLES := ["repair", "allied_command", "outpost", "relay", "junction", "depot",
	"forward_command", "hostile_command", "shipyard", "west_hub", "defense", "east_hub"]
const TYPES := ["Repair Dock", "Allied Command", "Isolated Outpost", "Communications Array",
	"Strategic Junction", "Supply Depot", "Forward Command", "Hostile Command",
	"Shipyard", "West Logistics Hub", "Defensive Outpost", "East Logistics Hub"]
const GLYPHS := ["✚", "◆", "□", "⌁", "◇", "▽", "◆", "◆", "▣", "▽", "□", "▽"]
const FACILITIES := ["repair", "coordinate", "fortify", "jam", "fortify", "sabotage",
	"coordinate", "coordinate", "deploy", "sabotage", "fortify", "sabotage"]
const MIN_NODES := 9
const MAX_NODES := 12


static func generate(seed_value: int, system: int, expansion: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:warzone-graph:v3" % [seed_value, system])
	var pattern := rng.randi_range(0, PATTERNS.size() - 1)
	var count := rng.randi_range(MIN_NODES, MAX_NODES)
	var scale := Layout.scale_factor(expansion)
	for attempt in 48:
		var graph := _sample(rng, pattern, count, scale)
		if not graph.is_empty(): return graph
	# Retry with the smallest supported graph to leave more clearance.
	for attempt in 48:
		var graph := _sample(rng, 1, MIN_NODES, scale)
		if not graph.is_empty(): return graph
	return _fallback(rng.randf_range(0.0, TAU), scale)


static func _fallback(angle: float, scale: float) -> Dictionary:
	# Keep the operation playable even if both bounded rejection passes exhaust.
	var points := [Vector2(-7, 8), Vector2(-6, -5), Vector2(-14, 1), Vector2(5, 7),
		Vector2(4, -6), Vector2(10, 1), Vector2(16, -7), Vector2(20, 2), Vector2(14, 10)]
	var nodes: Array[Dictionary] = []
	for index in points.size():
		var at: Vector2 = points[index].rotated(angle) * scale
		nodes.append({"position": Vector3(at.x, 0, at.y), "owner": "allied" if index < 3 else "hostile",
			"contested": false, "capturing": "neutral", "progress": 0, "held": 0})
	var links: Array[Vector2i] = [Vector2i(0, 2), Vector2i(1, 2), Vector2i(1, 4), Vector2i(0, 3),
		Vector2i(3, 5), Vector2i(4, 5), Vector2i(5, 6), Vector2i(5, 8), Vector2i(6, 7), Vector2i(7, 8)]
	return {"nodes": nodes, "links": links, "roles": ROLES.slice(0, MIN_NODES), "pattern": 1}


static func _sample(rng: RandomNumberGenerator, pattern: int, count: int, scale: float) -> Dictionary:
	var angle := rng.randf_range(0, TAU)
	var span := rng.randf_range(5.2, 6.5) if pattern == 6 else rng.randf_range(6.0, 8.8)
	var bend := rng.randf_range(-4.0, 4.0)
	# Two real opening contacts. Their paired endpoints place both fleets
	# close together without fixing the rest of the network to lanes.
	var points := {
		"allied_command": Vector2(-rng.randf_range(4.0, 7.0), -span),
		"junction": Vector2(rng.randf_range(3.0, 5.0), -span + bend),
		"repair": Vector2(-rng.randf_range(4.0, 9.0), span),
		"relay": Vector2(rng.randf_range(3.0, 7.0), span - bend * 0.5),
	}
	var allied_roles := ["allied_command", "repair"]
	if pattern != 2 and (count == MIN_NODES or rng.randf() < 0.8): allied_roles.append("outpost")
	if pattern == 6 and count == MAX_NODES: allied_roles.append("defense")
	var roles := ROLES.slice(0, 9)
	var extras := ROLES.slice(9)
	_shuffle(extras, rng)
	if "defense" in allied_roles:
		extras.erase("defense")
		extras.push_front("defense")
	roles.append_array(extras.slice(0, count - MIN_NODES))
	for role in roles:
		if points.has(role): continue
		var allied: bool = role in allied_roles
		var low := -21.0 if allied else (10.0 if role == "hostile_command" else 4.5)
		var high := -9.0 if allied else 21.0
		if role == "outpost" and pattern == 2:
			low = 12.0
			allied_roles.append(role)
		var spread := 12.0 if pattern == 4 else 19.0
		var placed := false
		for attempt in 32:
			var z := rng.randf_range(-spread, spread)
			if pattern == 5 and not allied:
				z = rng.randf_range(3.0, spread) * (-1.0 if role in ["hostile_command", "shipyard", "west_hub"] else 1.0)
			var point := Vector2(rng.randf_range(low, high), z)
			if point.length() > 24.0: continue
			if points.values().any(func(other): return point.distance_to(other) < 5.4): continue
			points[role] = point
			placed = true
			break
		if not placed: return {}
	var pocket := pattern == 2
	_shuffle(roles, rng)
	var nodes: Array[Dictionary] = []
	var allies: Array[int] = []
	var enemies: Array[int] = []
	for role in roles:
		var point: Vector2 = points[role].rotated(angle) * scale
		var owned: bool = role in allied_roles
		var index := nodes.size()
		if not (pocket and role == "outpost"):
			(allies if owned else enemies).append(index)
		nodes.append({"position": Vector3(point.x, 0, point.y), "owner": "allied" if owned else "hostile",
			"contested": false, "capturing": "neutral", "progress": 0, "held": 0})
	var links: Array[Vector2i] = []
	_tree(allies, nodes, links)
	var junction := roles.find("junction")
	var relay := roles.find("relay")
	var depot := roles.find("depot")
	if pattern in [0, 4]:
		var front: Array[int] = [junction, relay, depot]
		var back: Array[int] = enemies.filter(func(id): return id not in [junction, relay])
		_tree(front, nodes, links)
		_tree(back, nodes, links)
	else:
		_tree(enemies, nodes, links)
	_add_link(links, roles.find("allied_command"), junction)
	_add_link(links, roles.find("repair"), relay)
	if pocket:
		_add_link(links, roles.find("outpost"), roles.find("forward_command"))
	var candidates: Array[Vector2i] = []
	for first in nodes.size():
		for second in range(first + 1, nodes.size()):
			if pocket and roles.find("outpost") in [first, second]: continue
			if pattern in [0, 4] and not (first in allies and second in allies): continue
			if pattern in [3, 5] and nodes[first].owner != nodes[second].owner: continue
			candidates.append(Vector2i(first, second))
	_shuffle(candidates, rng)
	var extra := rng.randi_range(0, 1) if pattern in [0, 4] else rng.randi_range(2, 5)
	for edge in candidates:
		if extra <= 0: break
		if edge in links or neighbors(edge.x, links).size() >= 4 or neighbors(edge.y, links).size() >= 4: continue
		if nodes[edge.x].position.distance_to(nodes[edge.y].position) > 16.0 * scale: continue
		if _crosses(edge, links, nodes): continue
		links.append(edge)
		extra -= 1
	var outpost := nodes[roles.find("allied_command")].position as Vector3
	outpost += (outpost - (nodes[junction].position as Vector3)).normalized() * 4.0
	if nodes.any(func(node): return node.position.distance_to(outpost) < 2.6): return {}
	for edge in links:
		if _crosses(edge, links, nodes): return {}
		var first: Vector3 = nodes[edge.x].position
		var last: Vector3 = nodes[edge.y].position
		for other in nodes.size():
			if other in [edge.x, edge.y]: continue
			var point: Vector3 = nodes[other].position
			if point.distance_to(Geometry3D.get_closest_point_to_segment(point, first, last)) < 1.15 * scale:
				return {}
	return {"nodes": nodes, "links": links, "roles": roles, "pattern": pattern}


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for i in range(values.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var swap = values[i]
		values[i] = values[other]
		values[other] = swap


static func _add_link(links: Array[Vector2i], a: int, b: int) -> void:
	links.append(Vector2i(mini(a, b), maxi(a, b)))


static func _tree(group: Array[int], nodes: Array[Dictionary], links: Array[Vector2i]) -> void:
	var joined: Array[int] = [group.front()]
	var unjoined := group.slice(1)
	while not unjoined.is_empty():
		var best := Vector2i(joined.front(), unjoined.front())
		var length := INF
		for first in joined:
			for second in unjoined:
				var distance: float = nodes[first].position.distance_squared_to(nodes[second].position)
				if distance < length:
					length = distance
					best = Vector2i(first, second)
		_add_link(links, best.x, best.y)
		joined.append(best.y)
		unjoined.erase(best.y)


static func _crosses(edge: Vector2i, links: Array[Vector2i], nodes: Array[Dictionary]) -> bool:
	var a: Vector3 = nodes[edge.x].position
	var b: Vector3 = nodes[edge.y].position
	for link in links:
		if edge.x in [link.x, link.y] or edge.y in [link.x, link.y]: continue
		var c: Vector3 = nodes[link.x].position
		var d: Vector3 = nodes[link.y].position
		if Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(b.x, b.z),
			Vector2(c.x, c.z), Vector2(d.x, d.z)) != null:
			return true
	return false


static func reachable(nodes: Array[Dictionary], links: Array[Vector2i],
		root: int, side: String, disrupted: Dictionary) -> Array[int]:
	var seen: Array[int] = []
	if nodes[root].owner != side or disrupted.has(root): return seen
	seen.append(root)
	var cursor := 0
	while cursor < seen.size():
		var site := seen[cursor]
		cursor += 1
		for link in links:
			var next := other(link, site)
			if next >= 0 and next not in seen and not disrupted.has(next) and nodes[next].owner == side:
				seen.append(next)
	return seen


static func other(link: Vector2i, site: int) -> int:
	if link.x == site: return link.y
	return link.x if link.y == site else -1


static func neighbors(site: int, links: Array[Vector2i], disrupted: Dictionary = {}) -> Array[int]:
	var result: Array[int] = []
	if disrupted.has(site): return result
	for link in links:
		var next := other(link, site)
		if next >= 0 and not disrupted.has(next): result.append(next)
	return result


static func bottlenecks(nodes: Array[Dictionary], links: Array[Vector2i]) -> Array[int]:
	var result: Array[int] = []
	var network: Array[Dictionary] = []
	for index in nodes.size(): network.append({"owner": "allied"})
	for index in nodes.size():
		if neighbors(index, links).size() < 2: continue
		var origin := 1 if index == 0 else 0
		if reachable(network, links, origin, "allied", {index: true}).size() < nodes.size() - 1:
			result.append(index)
	return result
