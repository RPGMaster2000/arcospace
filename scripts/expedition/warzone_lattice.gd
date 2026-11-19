extends RefCounted
## Deterministic sector geometry and graph queries. Node ownership is owned by WarzoneState.

const PATTERNS := ["Central Bottleneck", "Multiple Fronts", "Encirclement",
	"Broken Network", "Long Supply Corridor", "Fragmented Battlefield"]
const TYPES := ["Repair Dock", "Allied Command", "Isolated Outpost", "Communications Array",
	"Strategic Junction", "Supply Depot", "Forward Command", "Hostile Command",
	"Shipyard", "West Logistics Hub", "Defensive Outpost", "East Logistics Hub"]
const GLYPHS := ["✚", "◆", "□", "⌁", "◇", "▽", "◆", "◆", "▣", "▽", "□", "▽"]


static func generate(seed_value: int, system: int, expansion: float) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%d:warzone-lattice:v1" % [seed_value, system])
	var pattern := rng.randi_range(0, PATTERNS.size() - 1)
	var columns := 4 if pattern in [4, 5] or rng.randf() < 0.20 else 3
	var scale := clampf(expansion, 1.0, 1.8)
	var angle := rng.randf_range(-0.85, 0.85)
	var nodes: Array[Dictionary] = []
	var links: Array[Vector2i] = []
	for col in columns:
		for lane in 3:
			var id := nodes.size()
			var x := (col - (columns - 1) * 0.5) * (13.0 if pattern == 4 else 10.0)
			var z := (lane - 1) * 8.2
			if pattern == 2: z *= lerpf(0.8, 1.35, float(col) / (columns - 1))
			var position := Vector3(x + rng.randf_range(-1.2, 1.2), 0, z + rng.randf_range(-1.4, 1.4))
			nodes.append({"position": position.rotated(Vector3.UP, angle) * scale,
				"owner": "allied" if col == 0 else "hostile", "contested": false,
				"capturing": "neutral", "progress": 0, "held": 0})
	# Each lane has an unbroken trunk. Cross-links between columns vary the
	# number of independent approaches while keeping junction degrees small.
	for col in columns - 1:
		for lane in 3:
			if col == 1 and lane == 0 and pattern in [0, 4, 5]: continue
			links.append(Vector2i(col * 3 + lane, (col + 1) * 3 + lane))
	links.append_array([Vector2i(0, 1), Vector2i(7, 8), Vector2i(6, 7)])
	if pattern != 3: links.append(Vector2i(1, 2))
	else: links.append(Vector2i(3, 5))
	if pattern != 4: links.append(Vector2i(3, 4))
	if pattern in [0, 1, 2, 5]: links.append(Vector2i(4, 5))
	if columns == 4:
		links.append_array([Vector2i(9, 10), Vector2i(10, 11)])
	return {"nodes": nodes, "links": links, "pattern": pattern}


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
