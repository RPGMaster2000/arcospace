extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Text = preload("res://scripts/ui/expedition_text.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func fresh(id: String, seed_value: int = 1042) -> Resource:
	var state := State.new()
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	state.start(0,rules,seed_value)
	state.defense_poi_version = 1 # Not enabled in live generation until all integrations finish.
	state.defense.tuning = state.defense.tuning.duplicate(true)
	state.defense.tuning.enemy_speed = 0
	for index in state.encounters.size():
		if state.encounters[index].kind == "poi":
			state.encounters[index].poi = load("res://encounters/"+id+".tres")
			state.navigation_origin = index
			break
	return state
func run_resolution_checks() -> void:
	var state := fresh("mining_operation")
	var index: int = state.navigation_origin
	var rng: int = state.rng.state
	check(state.resolve_approach(index,0,1.0), "Guaranteed outcome succeeds even with a forced failure roll")
	check(state.salvage == 12 and state.defense.pressure == 2, "Exact Salvage and strategic cost")
	check(state.rng.state == rng, "Guaranteed fixed reward does not draw a success roll")
	check(not state.resolve_approach(index,0) and state.salvage == 12 and state.defense.pressure == 2, "Repeated interaction cannot spend time or claim loot")
	state = fresh("spatial_anomaly")
	index = state.navigation_origin
	check(state.resolve_approach(index,0), "Pressure pause resolves")
	check(state.defense.pressure == 3 and state.poi_effects.pause == 15, "Acquisition cost occurs before the new effect activates")
	state = fresh("mining_operation")
	index = state.navigation_origin
	check(state.resolve_approach(index,2), "Free turret resolves through ordinary PoI entry")
	check(state.salvage == 0 and State.Defense.Installations.free_count(state.defense.turrets) == 1 and state.defense.pressure == 5, "Free turret transaction applies cost once and charges no Salvage")
	var restored: Resource = Save.new().decode(JSON.parse_string(JSON.stringify(Save.encode(state))),state.rules)
	check(restored != null and restored.defense_poi_version == 1 and restored.encounters[index].completed, "Rule version and completed reward persist")
	state = fresh("research_station")
	index = state.navigation_origin
	var reward_entry_rng: int = state.rng.state
	check(state.resolve_approach(index,0) and state.pending_choice == "card_batch", "Research reward generates two-card confirmation")
	check(state.rng.state == reward_entry_rng, "Two-card PoI reward never changes future encounter RNG")
	check(state.defense.pressure == 4 and state.card_offers.size() == 2, "Card confirmation does not defer or repeat strategic cost")
	var saved := Save.encode(state)
	restored = Save.new().decode(JSON.parse_string(JSON.stringify(saved)),state.rules)
	check(restored != null and restored.pending_choice == "card_batch", "Completed PoI and unconfirmed cards survive restoration")
	state = fresh("mining_operation")
	index = state.navigation_origin
	state.production_upgrades.synthesizer = 0
	# Use explicit actual requirements so ships with different base profiles remain valid.
	var gated: Resource = state.poi_approaches(index)[3]
	var allowed: bool = state.production("synthesizer") >= 3
	check(state.resolve_approach(index,3) == allowed, "Production prerequisite is enforced by authoritative resolver")
	var quantities := {}
	for seed_value in range(20):
		state = fresh("pirate_debris_field",seed_value+1)
		var generation_rng: int = state.rng.state
		index = state.navigation_origin
		check(state.resolve_approach(index,0) and state.salvage >= 8 and state.salvage <= 12, "Randomized guaranteed reward stays in its stated range")
		check(state.rng.state == generation_rng, "Loot quantity never consumes future-generation RNG")
		quantities[state.salvage] = true
		var exact: int = state.salvage
		check(not state.resolve_approach(index,0) and state.salvage == exact, "Resolved range reward never rerolls")
	check(quantities.size() > 1, "Different expedition seeds produce reward variation")
	state = fresh("research_station")
	index = state.navigation_origin
	for approach in state.poi_approaches(index):
		var preview: String = Text.approach_text(state,approach)
		check(preview.contains("strategic seconds") and not preview.contains("% —") and not preview.contains("failure"), "Defense preview shows cost without probability or failure branches")
	saved = Save.encode(state)
	saved.erase("defense_poi_version")
	restored = Save.new().decode(saved,state.rules)
	check(restored != null and restored.defense_poi_version == 0, "Unmarked saved system retains historical PoI rules")
	if restored != null:
		check(restored.poi_approaches(index) == restored.encounters[index].poi.approaches, "Legacy system uses original resource approach list")
	var exploration := State.new()
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "exploration"
	rules.log_rolls = false
	exploration.start(0,rules,1042)
	for slot in exploration.encounters.size():
		if exploration.encounters[slot].kind == "poi":
			check(exploration.poi_approaches(slot) == exploration.encounters[slot].poi.approaches, "Exploration approach resources remain original")
	print("Defense PoI transactions: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
func _initialize() -> void: call_deferred("run_resolution_checks")
