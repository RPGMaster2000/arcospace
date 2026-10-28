extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	root.add_child(host)
	await process_frame
	var map = host.star_map
	host.state.navigation.checkpoint_position([0, 0, 0])
	host.state.begin_travel(0)
	host.phase = host.Phase.TRAVELING
	map.traveling = true
	map.ship.position = Vector3(1, 0, 0)
	host.visit(0)
	check(host.state.defense.contact < 0 and host.phase == host.Phase.OVERVIEW and not host.state.navigation.leg_active, "Arrival at a hostile's stale position never starts combat")
	check(not is_instance_valid(host.battle) and host.state.active_battle < 0, "Only simulation contact can initiate battle")
	host.state.navigation.checkpoint_position([0, 0, 0])
	host.state.begin_travel(0)
	host.state.defense.units[0].status = "arrived"
	host.state.encounters[0].completed = true
	host.phase = host.Phase.TRAVELING
	map.traveling = true
	map.ship.position = Vector3(1, 0, 0)
	host.visit(0)
	check(host.phase == host.Phase.OVERVIEW and not host.state.navigation.leg_active, "An attacker arriving before its selected destination cannot strand navigation")
	host.queue_free()
	await process_frame
	print("Starfront interception: %d failures" % failures)
	quit(1 if failures else 0)
