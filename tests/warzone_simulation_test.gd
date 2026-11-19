extends SceneTree

const Campaign = preload("res://scripts/expedition/campaign_support.gd")
const Tuning = preload("res://scripts/expedition/warzone_tuning.gd")
const Warzone = preload("res://scripts/expedition/warzone_state.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func opening(integrity: int, tuning: Resource) -> RefCounted:
	var support := Campaign.homeworld_package({"integrity": integrity, "maximum_integrity": 100}, tuning)
	var state := Warzone.new()
	state.setup(tuning, support.fleet_strength)
	return state


func player_capture(state: RefCounted, index: int) -> void:
	# Clear only the defenders at this objective. The player never has to remove every hostile group.
	for fleet in state.fleets:
		if fleet.side == "hostile" and fleet.destination == index:
			state.player_victory(fleet.id)
	var point: Vector3 = state.objectives[index].position
	state.advance(state.tuning.capture_seconds * Warzone.STEP_MS, point, point)


func run() -> void:
	var tuning := Tuning.new()
	for integrity in [1, 20, 50, 80]:
		var state = opening(integrity, tuning)
		check(state.controlled() == 1 and state.fleet_count("allied") == 2 and state.fleet_count("hostile") == 5,
			"Opening integrity %d gives the enemy two objectives and a numerical advantage" % integrity)
		check(state.initial_allied_strength >= 10 and state.outcome().hostile_strength > state.initial_allied_strength,
			"Each support package starts with working fleets and an enemy advantage")

	var whole = opening(1, tuning)
	var divided = opening(1, tuning)
	var origin := Warzone.START
	var destination := Vector3(-20, 0, 20)
	whole.advance(19500, origin, destination)
	var waypoint := origin.lerp(destination, 4500.0 / 19500.0)
	divided.advance(4500, origin, waypoint)
	divided.advance(15000, waypoint, destination)
	check(whole.snapshot() == divided.snapshot(), "Travel, engagements and captures agree across time partitions")
	check(whole.outcome().allied_strength < whole.initial_allied_strength, "NPCs exchange damage without player involvement")
	check(whole.events.any(func(event): return event.contains("contested")), "NPC conflict can contest an objective")
	check(whole.fleets[3].position != opening(1, tuning).fleets[3].position, "Fleets advance along their objective orders")

	var engaged = opening(80, tuning)
	engaged.advance(7500, origin, origin)
	check(not engaged.allied_support(2).is_empty(), "An ongoing NPC engagement exposes a participating ally")
	var payload: Dictionary = JSON.parse_string(JSON.stringify(engaged.snapshot()))
	var resumed := Warzone.new()
	check(resumed.restore(payload, tuning), "A checkpoint restores a contested battle and the fractional clock")
	check(resumed.snapshot() == engaged.snapshot(), "Checkpoint preserves positions, engagements and casualties")
	resumed.advance(22500, origin, origin)
	engaged.advance(22500, origin, origin)
	check(resumed.snapshot() == engaged.snapshot(), "Same committed time after load produces the same outcome and events")
	payload.fleets[0].destination = 3
	check(not resumed.restore(payload, tuning), "An invalid route is rejected")

	var pyrrhic = opening(1, tuning)
	pyrrhic.advance(120000, origin, origin)
	check(pyrrhic.fleet_count("allied") == 0 and not pyrrhic.complete, "NPCs can destroy every ally without ending the operation")
	player_capture(pyrrhic, 0)
	check(pyrrhic.controlled() == 1 and pyrrhic.consolidation == 0, "One objective alone cannot start consolidation")
	player_capture(pyrrhic, 1)
	# If the enemy retasked, securing the second objective still leaves its defender at the Array.
	check(pyrrhic.controlled() == 2 and not pyrrhic.complete, "The player can capture two objectives without allies")
	var point: Vector3 = pyrrhic.objectives[1].position
	pyrrhic.advance((tuning.consolidation_seconds - 2) * Warzone.STEP_MS, point, point)
	check(not pyrrhic.complete, "Consolidation has a real waiting period")
	pyrrhic.advance(Warzone.STEP_MS, point, point)
	check(pyrrhic.complete and pyrrhic.fleet_count("hostile") > 0, "Objectives unlock victory with hostiles still active")
	check(pyrrhic.outcome().grade == "Pyrrhic Victory" and pyrrhic.outcome().salvage == tuning.pyrrhic_salvage,
		"A Pyrrhic Victory receives its campaign grade and bonus")
	check(resumed.restore(pyrrhic.snapshot(), tuning) and resumed.outcome() == pyrrhic.outcome(), "Pyrrhic victory survives a checkpoint")

	print("Warzone simulation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
