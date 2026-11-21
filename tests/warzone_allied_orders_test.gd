extends SceneTree

const Sector = preload("res://scripts/expedition/warzone_sector.gd")
const Orders = preload("res://scripts/expedition/warzone_allied_orders.gd")
const Tuning = preload("res://scripts/expedition/warzone_tuning.gd")

var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func scenario(seed_value: int) -> RefCounted:
	var op := Sector.new()
	op.setup_sector(Tuning.new(), 8, 1.0, seed_value, 2)
	var root := op.root("allied")
	var junction := op.site("junction")
	var repair := op.site("repair")
	var relay := op.site("relay")
	var hostile := op.root("hostile")
	# Reposition a generated sector into a controlled tactical scenario.
	op.links.assign([Vector2i(root, junction), Vector2i(junction, repair), Vector2i(junction, relay),
		Vector2i(hostile, junction), Vector2i(hostile, repair)])
	for edge in op.links.duplicate():
		if edge.x > edge.y:
			op.links.erase(edge)
			op.links.append(Vector2i(edge.y, edge.x))
	for i in op.objectives.size():
		op.objectives[i].owner = "hostile"
		if i not in [root, junction, repair, relay, hostile]:
			op.links.append(Vector2i(mini(hostile, i), maxi(hostile, i)))
	for i in [root, junction, repair, relay]:
		op.objectives[i].owner = "allied"
	op.objectives[root].position = Vector3(-10, 0, 2)
	op.objectives[junction].position = Vector3.ZERO
	op.objectives[relay].position = Vector3(-5, 0, -6)
	op.objectives[repair].position = Vector3(7, 0, -9)
	op.objectives[hostile].position = Vector3(14, 0, 0)
	op.convoy.clear()
	for fleet in op.fleets:
		fleet.engaged = -1
		fleet.strength = 0
	var ally: Dictionary = op.fleets[0]
	ally.strength = 8
	ally.at = junction
	ally.destination = hostile
	ally.position = Vector3(5, 0, -4)
	var enemy: Dictionary = op.fleets[2]
	enemy.strength = 8
	enemy.at = hostile
	enemy.destination = junction
	enemy.position = Vector3(10, 0, 0)
	op._refresh_supply()
	return op

func run() -> void:
	for seed_value in [2, 17, 111]:
		var op := scenario(seed_value)
		var ally: Dictionary = op.fleets[0]
		var enemy: Dictionary = op.fleets[2]
		var junction: int = op.site("junction")
		var yard: int = op.site("shipyard")
		var capture: Dictionary = op.objectives[yard]
		capture.position = ally.position
		capture.capturing = "allied"
		capture.progress = 1
		op.links.append(Vector2i(mini(junction, yard), maxi(junction, yard)))
		op._refresh_supply()
		ally.destination = yard
		check(op.allied_site_importance(junction) > op.allied_site_importance(op.site("repair")),
			"Junction importance reflects installations it supplies")
		Orders.assign(op, false)
		check(ally.get("intercept") == enemy.id, "Fleet leaves a peripheral capture to protect the junction")
		var lead: Vector3 = op.fleet_target_position(ally)
		check(lead.x > 0.0 and lead.x < enemy.position.x, "Interception leads the hostile along its actual route")
		var saved: Dictionary = op.snapshot()
		var restored := Sector.new()
		check(restored.restore(saved, op.tuning) and restored.fleets[0].get("intercept") == enemy.id,
			"An interception persists through restore")
		op.advance(6000, Vector3(-20, 0, 15), Vector3(-20, 0, 15))
		check(capture.progress == 0 and capture.owner == "hostile" and ally.engaged == enemy.id and enemy.position.x > 0.5,
			"Capture resets normally and the fleets meet before the enemy reaches the junction")

	var op := scenario(17)
	var ally: Dictionary = op.fleets[0]
	var enemy: Dictionary = op.fleets[2]
	var yard: int = op.site("shipyard")
	var capture: Dictionary = op.objectives[yard]
	capture.position = ally.position
	capture.capturing = "allied"
	capture.progress = 5
	ally.destination = yard
	enemy.destination = op.site("repair")
	Orders.assign(op, false)
	check(not ally.has("intercept"), "Near-complete capture wins over a peripheral threat")

	var partner: Dictionary = op.fleets[1]
	partner.position = enemy.position + Vector3(0, 0, 1)
	partner.strength = 5
	partner.at = op.site("junction")
	partner.engaged = enemy.id
	enemy.engaged = partner.id
	capture.progress = 0
	capture.capturing = "neutral"
	Orders.assign(op, false)
	check(ally.get("assignment") == "Assisting" and partner.engaged == enemy.id,
		"Available formation assists a losing engagement without redeploying its fighting partner")

	op = scenario(17)
	ally = op.fleets[0]
	enemy = op.fleets[2]
	partner = op.fleets[1]
	partner.at = ally.at
	partner.position = Vector3(4, 0, 5)
	ally.strength = 7
	partner.strength = 7
	Orders.assign(op, false)
	check(ally.get("intercept") == enemy.id and partner.get("intercept") == enemy.id,
		"Two moderate formations converge against a stronger threat")
	Orders.clear_interception(op, ally)
	Orders.clear_interception(op, partner)
	ally.strength = 8
	partner.strength = 8
	var second: Dictionary = op.fleets[3]
	partner.position = Vector3(5, 0, -8)
	ally.position = Vector3(5, 0, 2)
	second.strength = 7
	second.at = enemy.at
	second.destination = op.site("repair")
	second.position = Vector3(9, 0, -5)
	enemy.strength = 7
	Orders.assign(op, false)
	check(ally.has("intercept") and partner.has("intercept") and ally.intercept != partner.intercept,
		"Fleets distribute adequate strength across simultaneous threats")
	ally.strength = 2
	ally.engaged = enemy.id
	Orders.assign(op, false)
	check(ally.withdrawing and op.is_supplied(ally.destination), "Critically damaged ally withdraws toward supply")

	op = scenario(17)
	ally = op.fleets[0]
	enemy = op.fleets[2]
	enemy.destination = enemy.at
	Orders.assign(op, false)
	check(not ally.has("intercept"), "Autonomous fleet ignores hostile ships holding an unrelated position")
	op.scramble(op.root("allied"))
	check(ally.get("intercept") == enemy.id, "Scramble redirects an available formation")
	enemy.strength = 0
	op.advance(20000, Vector3(-20, 0, 15), Vector3(-20, 0, 15))
	check(op.scramble_until == 0 and not ally.has("intercept"), "Scramble expires on strategic time and clears pursuit")
	print("Warzone allied orders: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
