extends SceneTree
## Runs unchanged before/after extraction. Optional user argument writes comparison signatures.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Catalog = preload("res://scripts/expedition/defense_poi_approaches.gd")
const IDS = [
	"mining_operation",
	"research_station",
	"spatial_anomaly",
	"gas_giant",
	"distress_signal",
	"derelict_starship",
	"radiation_nebula",
	"pirate_debris_field",
	"raider_cache",
	"quarantined_colony",
	"fuel_depot",
	"sensor_relay",
	"ancient_navigation_array",
	"unstable_wormhole"
]
var checks := 0
var failures := 0
var signatures: Dictionary = {}


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func fresh(id: String, seed_value: int = 1042) -> Resource:
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	rules.defense_tuning = rules.defense_tuning.duplicate(true)
	rules.defense_tuning.enemy_speed = 0
	var state := State.new()
	state.start(0, rules, seed_value)
	for index in state.encounters.size():
		if state.encounters[index].kind == "poi":
			state.encounters[index].poi = load("res://encounters/" + id + ".tres")
			state.navigation_origin = index
			break
	# Rebuild derived construction sites after substituting the fixture's PoI Resource.
	state.defense.construction_sites = State.Defense.Installations.sites(
		state.defense.home, state.defense.anchors, state.encounters, state.layout_expansion
	)
	for category in State.PRODUCTION:
		state.production_upgrades[category] = 3
	state.hull = state.ship().hull_capacity - 10
	return state


func snapshot(state: Resource) -> Dictionary:
	# Compare persisted values after JSON numeric normalization (ints/floats share a wire type).
	return JSON.parse_string(
		JSON.stringify(
			{"save": Save.encode(state), "outcome": state.last_outcome, "ended": state.run_ended}
		)
	)


func attempt(state: Resource, slot: int, label: String) -> Dictionary:
	var before := snapshot(state)
	var events: Array = []
	var progress := func(): events.append({"signal": "progress", "state": snapshot(state)})
	var advanced := func(data):
		events.append({"signal": "time", "data": data.duplicate(true), "state": snapshot(state)})
	state.progress_committed.connect(progress)
	state.defense_advanced.connect(advanced)
	var ok: bool = state.resolve_approach(state.navigation_origin, slot)
	state.progress_committed.disconnect(progress)
	state.defense_advanced.disconnect(advanced)
	signatures[label] = (
		JSON
		. stringify({"before": before, "ok": ok, "events": events, "after": snapshot(state)})
		. sha256_text()
	)
	return {"ok": ok, "events": events, "before": before}


func rejected(state: Resource, slot: int, label: String) -> void:
	var result := attempt(state, slot, label)
	check(not result.ok and result.events.is_empty(), label + ": no transaction or notification")
	check(snapshot(state) == result.before, label + ": no mutation, time or RNG consumption")


func roundtrip(state: Resource, label: String) -> Resource:
	var data := Save.encode(state)
	var restored: Resource = Save.new().decode(JSON.parse_string(JSON.stringify(data)), state.rules)
	check(restored != null, label + ": save loads")
	if restored != null:
		check(
			(
				JSON.parse_string(JSON.stringify(Save.encode(restored)))
				== JSON.parse_string(JSON.stringify(data))
			),
			label + ": exact save roundtrip"
		)
	return restored


func matrix() -> void:
	for seed_value in [1, 42, 1042]:
		for id in IDS:
			for slot in Catalog.definitions(id).size():
				var state := fresh(id, seed_value)
				var index: int = state.navigation_origin
				var approach: Resource = state.poi_approaches(index)[slot]
				state.salvage = approach.salvage_cost
				var label := "%s:%d:%d" % [id, slot, seed_value]
				var loaded := roundtrip(state, label + " before")
				var result := attempt(state, slot, label)
				check(result.ok, label + ": guaranteed reward resolves")
				check(
					state.encounters[index].completed and state.last_poi_success == 1,
					label + ": completed exactly once"
				)
				check(
					state.rng.state == int(result.before.save.rng.rng.state),
					label + ": gameplay RNG unchanged"
				)
				check(
					(
						result.events.size() == 2
						and result.events[0].signal == "time"
						and result.events[1].signal == "progress"
					),
					label + ": one time event then one commit"
				)
				if result.events.size() == 2:
					var during: Dictionary = result.events[0].state.save
					check(
						(
							during.encounters[index].completed
							and during.salvage == result.before.save.salvage
						),
						label + ": completion precedes time, rewards follow time"
					)
				check(
					is_equal_approx(
						state.defense.pressure, maxf(0.0, float(approach.get_meta("strategic_seconds"))
							- float(approach.get_meta("strategic_reward").get("pressure_relief", 0.0)))
					),
					label + ": exact strategic cost"
				)
				if loaded != null:
					var continued := attempt(loaded, slot, label + ":continue")
					check(
						continued.ok and snapshot(state) == snapshot(loaded),
						label + ": continue gives identical rewards and state"
					)
				roundtrip(state, label + " after")
				rejected(state, slot, label + ":duplicate")


func guards() -> void:
	for slot in [-1, 999]:
		rejected(fresh("mining_operation"), slot, "invalid:%d" % slot)
	var state := fresh("mining_operation")
	state.production_upgrades.synthesizer = 0
	check(state.production("synthesizer") < 3, "Prerequisite fixture is below threshold")
	rejected(state, 3, "production")
	state = fresh("derelict_starship")
	state.decoys = State.DECOY_CAPACITY
	rejected(state, 3, "decoy full")
	state = fresh("mining_operation")
	state.poi_effects.start_extraction(state.navigation_origin)
	rejected(state, 4, "extraction already online")
	state = fresh("research_station")
	state.poi_effects.mothership = "damage"
	rejected(state, 2, "research already active")
	state = fresh("research_station")
	for card in state.available_reward_cards():
		if card.tier == 1:
			state._deck.acquired_cards.append(card)
	rejected(state, 0, "cards exhausted")
	state = fresh("mining_operation")
	check(state.deploy_poi_turret(state.navigation_origin), "Install existing free turret")
	rejected(state, 2, "free turret already used")
	for spec in [
		["mining_operation", 4],
		["research_station", 2],
		["spatial_anomaly", 0],
		["spatial_anomaly", 1]
	]:
		state = fresh(spec[0])
		state.defense.complete = true
		rejected(state, spec[1], "secured:" + str(spec))
	state = fresh("quarantined_colony")
	state.hull = state.ship().hull_capacity
	rejected(state, 2, "full hull")


func timing() -> void:
	var state := fresh("mining_operation")
	var index: int = state.navigation_origin
	state.defense.integrity = 1
	state.defense.tuning.enemy_speed = 1
	state.defense.unit_for(0).position = state.defense.home + Vector3(0.1, 0, 0)
	var result := attempt(state, 0, "ended during activity")
	check(
		result.ok and state.run_ended and state.encounters[index].completed,
		"Fatal time advancement preserves consumed encounter"
	)
	check(
		(
			state.salvage == 0
			and state.last_poi_success == -1
			and state.last_outcome == "The invasion ended the expedition during this operation."
		),
		"Interrupted activity awards nothing and preserves outcome semantics"
	)
	check(
		result.events.size() == 2 and result.events[-1].signal == "progress",
		"Fatal activity commits once"
	)
	state = fresh("mining_operation")
	state.poi_effects.grant_production("synthesizer", 2, 2)
	check(attempt(state, 1, "stack production").ok, "Production reward applies")
	check(
		state.poi_effects.production.synthesizer == {"amount": 2, "battles": 3},
		"Production retains stronger magnitude and longer duration"
	)
	state.poi_effects.completed_battle()
	check(
		state.poi_effects.production.synthesizer.battles == 2,
		"Only completed battles consume duration"
	)
	state = fresh("spatial_anomaly")
	state.poi_effects.pause = 5
	check(
		attempt(state, 0, "pause refresh").ok and state.poi_effects.pause == 12,
		"Existing duration consumed before reward refresh"
	)
	state = fresh("research_station")
	state.rules.max_deck_identities = state.player_pool().size()
	check(
		attempt(state, 0, "full deck batch").ok and state.card_offers.size() == 2,
		"Full deck retains two promised cards"
	)
	check(
		state.confirm_card_batch() and state.pending_choice == "replace",
		"Existing replacement flow handles capacity"
	)
	roundtrip(state, "pending replacement")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	matrix()
	guards()
	timing()
	if not OS.get_cmdline_user_args().is_empty():
		var output := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
		output.store_string(JSON.stringify(signatures))
	print("Defense PoI resolver: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
