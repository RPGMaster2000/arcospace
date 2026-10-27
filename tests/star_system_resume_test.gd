extends SceneTree
const Save = preload("res://scripts/persistence/expedition_save.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for i in range(12):
		await process_frame
func run() -> void:
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate(true)
	host.rules.debug_seed = 1042
	host.rules.chasedown_chance = 1.0
	host.rules.maximum_chasedown_chance = 1.0
	host.rules.log_rolls = false
	root.add_child(host)
	await settle()
	# Select generated actionable PoIs without removing objective graph entries.
	var destinations: Array[int] = []
	for index in host.state.encounters.size():
		if host.state.encounters[index].kind == "poi" and not host.state.objective_locked(index): destinations.append(index)
	var origin: int = destinations[0]
	var destination: int = destinations[1]
	host.star_map.travel_duration = 0.06
	host.star_map.travel(origin)
	await create_timer(0.15).timeout
	check(host.state.navigation_origin == origin, "Initial travel arrives normally")
	host.show_system()
	await create_timer(0.9).timeout
	host.star_map.travel_duration = 1.0
	host.star_map.travel(destination)
	check(host.state.pending_destination == destination and host.state.travel_destination == -1, "Chasedown cancels authoritative travel immediately")
	await create_timer(0.65).timeout
	var stopped: Vector3 = host.star_map.ship.position
	await create_timer(0.3).timeout
	check(host.star_map.ship.position == stopped and host.state.navigation_origin == origin and not host.state.encounters[destination].completed, "Interception stops without visiting destination")
	await create_timer(0.7).timeout
	check(host.view_kind == "chasedown", "Existing interception choices open")
	var snapshot: Dictionary = Save.encode(host.state)
	var codec = Save.new()
	var restored: Resource = codec.decode(snapshot, host.rules)
	check(restored != null, "Existing save codec accepts intercepted 3D travel")
	var selected: int = host.state.player_ship
	host.queue_free()
	await settle()
	var resumed = preload("res://scenes/expedition.tscn").instantiate()
	resumed.persistence_enabled = false
	resumed.rules = restored.rules
	resumed.resume_data = {"state":restored, "battle":{}}
	root.add_child(resumed)
	await settle()
	check(resumed.state.player_ship == selected and resumed.state.pending_destination == destination and resumed.view_kind == "chasedown", "Continue preserves selected ship and pending interception")
	check(resumed.star_map != null and resumed.star_map.ship != null, "Resumed interception retains 3D ship presentation")
	# Resolution still uses State, but no former command resumes.
	var chase: int = resumed.state.chasedown_index
	check(resumed.state.choose_chasedown_response(0), "Existing response accepted")
	resumed.state.encounters[chase].completed = true
	resumed.state.encounters[chase].resolution = "escaped"
	resumed.state.active_battle = -1
	resumed.show_system()
	await settle()
	check(resumed.star_map != null and not resumed.star_map.traveling, "Resolved interception returns stationary")
	check(resumed.star_map.ship.position.is_equal_approx(stopped), "Actual intercepted position survives save/resume")
	await create_timer(1.6).timeout
	check(resumed.state.navigation_origin == origin and resumed.star_map.selected_index == -1 and resumed.view_kind == "system", "No unsolicited arrival or selection")
	resumed.star_map.travel(destination)
	await create_timer(1.6).timeout
	check(resumed.state.navigation_origin == destination and resumed.selected_encounter == destination, "Explicit reselection travels and arrives once")
	resumed.queue_free()
	await settle()
	print("Star system resume: %d failures" % failures)
	quit(failures)
