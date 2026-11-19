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
		check(state.engagement_count() == 2 and state.objectives[1].contested and not state.allied_support(2).is_empty(),
			"Each support package opens with two real engagements and an allied contact")
	for scale in [1.0, 1.2, 1.5]:
		var scaled := Warzone.new()
		scaled.setup(tuning, 9, scale)
		check(scaled.engagement_count() == 2 and (scaled.fleets[2].position as Vector3).distance_to(Warzone.START * scale) <= Warzone.INTERCEPT_RADIUS,
			"System expansion preserves the two engagements and accessible contact")

	var whole = opening(1, tuning)
	var divided = opening(1, tuning)
	var origin := Warzone.START
	var destination := Vector3(-20, 0, 20)
	whole.advance(19500, origin, destination)
	var waypoint := origin.lerp(destination, 4500.25 / 19500.0)
	divided.advance(4500.25, origin, waypoint)
	divided.advance(14999.75, waypoint, destination)
	check(whole.snapshot() == divided.snapshot(), "Travel, engagements and captures agree across time partitions")
	check(whole.outcome().allied_strength < whole.initial_allied_strength, "NPCs exchange damage without player involvement")
	check(whole.volley_tick > 0 and not whole.volley.is_empty(), "Actual NPC exchanges emit presentation cues")
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

	var reaction = opening(100, tuning)
	player_capture(reaction, 1)
	check(reaction.objectives[1].owner == "allied" and reaction.fleets[3].destination == 1,
		"Player capture redirects an unengaged hostile group")
	check(reaction.fleets[2].engaged == 0 and reaction.fleets[2].destination == 0,
		"An ongoing hostile engagement keeps its assignment during a counterattack")
	check(reaction.events.any(func(event): return event.contains("counterattack")) and reaction.fleets.size() == 7,
		"The counterattack is reported and reuses the existing fleet")
	while reaction.fleets[1].engaged >= 0:
		reaction.player_victory(reaction.fleets[1].engaged)
	reaction.advance(12000, origin, origin)
	check(reaction.fleets[1].destination != 1 or reaction.fleet_status(reaction.fleets[1]) in ["Defending", "Engaged", "Destroyed"],
		"The victorious vanguard may hold against the counterattack")
	var assault = opening(100, tuning)
	for fleet in assault.fleets:
		if fleet.id != 2: assault._damage(fleet, fleet.strength)
	assault.fleets[2].position = assault.objectives[0].position
	assault.objectives[2].owner = "allied"
	assault.advance((tuning.capture_seconds + 1) * Warzone.STEP_MS, Vector3.ZERO, Vector3.ZERO)
	check(assault.objectives[0].owner == "hostile" and assault.fleets[2].destination == 2,
		"A hostile assault continues toward another allied objective after capturing the Relay")

	var pyrrhic = opening(1, tuning)
	pyrrhic.advance(120000, origin, origin)
	check(pyrrhic.fleet_count("allied") == 0 and not pyrrhic.complete, "NPCs can destroy every ally without ending the operation")
	player_capture(pyrrhic, 0)
	check(pyrrhic.controlled() == 1 and pyrrhic.consolidation == 0, "One objective alone cannot start consolidation")
	for fleet in pyrrhic.fleets:
		if fleet.side == "hostile" and fleet.role != "Defender": pyrrhic.player_victory(fleet.id)
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
