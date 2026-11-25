extends SceneTree
## Deliberate policy probes, outside the fast regression selection.
## godot --headless --path . --script res://tools/warzone_economy_audit.gd

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const CASES := ["unattended", "capture rush", "station support", "discovery detour", "weak Homeworld"]

func _initialize() -> void:
	run.call_deferred()


func travel(state: Resource, destination: Vector3) -> void:
	var start := State.Defense.point(state.navigation.position)
	state.advance_warzone_map(start.distance_to(destination) / state.rules.defense_tuning.player_speed, start, destination)
	state.navigation.checkpoint_position(State.Defense.wire(destination))


func capture_candidate(op: RefCounted, point: Vector3) -> int:
	var index := -1
	var best := INF
	for site in op.objectives.size():
		if op.objectives[site].owner == "allied" or not op._capture_connected(site, "allied"): continue
		var distance: float = point.distance_squared_to(op.objectives[site].position)
		if site == op.final_command: distance *= 0.15
		if distance < best:
			index = site
			best = distance
	return index


func probe(seed_value: int, strategy: String, legacy: bool) -> Dictionary:
	var state := State.new()
	state.start(0, Rules, seed_value)
	state.defense.complete = true
	state.defense.integrity = 12 if strategy == "weak Homeworld" else 74
	state.generate_system()
	var op = state.warzone
	if legacy:
		op.economy = null
		for entry in state.encounters: entry.erase("warzone_detour")
	var visits := 0
	var prepared_total := 0
	var last_event: int = op.event_revision
	var interrupted := false
	for step in 24:
		if op.complete: break
		if strategy == "capture rush":
			var target := capture_candidate(op, State.Defense.point(state.navigation.position))
			if target >= 0: travel(state, op.objectives[target].position)
		elif strategy == "station support" and step < 12:
			var roles := ["relay", "repair", "depot", "allied_command", "shipyard"]
			var site: int = op.site(roles[step % roles.size()])
			travel(state, op.objectives[site].position)
			var offer: Dictionary = op.operations(site, state.salvage).front()
			if offer.enabled and state.warzone_operate(site + op.HOSTILE_GROUPS, offer.id): visits += 1
		elif strategy == "discovery detour" and step == 2 and not state.encounter_positions.is_empty():
			var index := int(state.encounter_positions.keys().front())
			travel(state, State.Defense.point(state.warzone_discovery(index)))
			if state.resolve_approach(index, 0):
				visits += 1
				if state.pending_choice == "resource": state.choose_attribute("energy")
				if state.pending_choice == "card" and state.choose_card(0) and state.pending_choice == "replace":
					state.decline_card()
				if state.pending_choice == "upgrade" and not state.upgrade_candidates().is_empty():
					state.choose_upgrade(state.upgrade_candidates()[0].identity_key())
		var point := State.Defense.point(state.navigation.position)
		state._commit_activity_time(12 if strategy == "capture rush" else 5)
		if op.player_hunter_contact(point) >= 0 and strategy == "capture rush":
			interrupted = true
			break
		for event in op.events_since(last_event):
			if event.contains("Combat Resupply") or event.contains("Shield Reinforcement") \
				or event.contains("Production Optimization") or event.contains("Signal Disruption") or event.contains("Emergency Repairs"):
				prepared_total += 1
		last_event = op.event_revision
	return {"wins": int(op.complete), "allied": op.fleet_count("allied"), "hostile": op.fleet_count("hostile"),
		"effort": op.effort, "seconds": op.clock_ms / 1000.0, "visits": visits,
		"intercepted": int(interrupted), "services": prepared_total,
		"allied_wallet": 0 if legacy else op.economy.wallets.allied,
		"hostile_wallet": 0 if legacy else op.economy.wallets.hostile}


func run() -> void:
	var count := 20
	if not OS.get_cmdline_user_args().is_empty(): count = maxi(1, int(OS.get_cmdline_user_args()[0]))
	for legacy: bool in [true, false]:
		for strategy: String in CASES:
			var sums := {}
			for seed_value in range(1, count + 1):
				var result := probe(seed_value, strategy, legacy)
				for key in result: sums[key] = sums.get(key, 0) + result[key]
			print("ECONOMY AUDIT ", "baseline" if legacy else "current", " · ", strategy, " · ", count, " · ", JSON.stringify(sums))
	quit()
