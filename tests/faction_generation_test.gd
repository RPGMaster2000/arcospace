extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Catalog = preload("res://scripts/expedition/faction_catalog.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func fresh(seed_value: int, configuration: Resource = null) -> Resource:
	var state := State.new()
	var rules: Resource = configuration if configuration != null else Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.warzone_campaign_enabled = false
	rules.fixed_opening_factions = false
	rules.log_rolls = false
	state.start(0, rules, seed_value)
	return state


func next(state: Resource) -> void:
	state.defense.complete = true
	check(state.generate_system(), "Completed defense advances")


func _initialize() -> void:
	call_deferred("run")


func opening_progression() -> void:
	var developer := {}
	for seed_value in range(1, 13):
		var state := State.new()
		state.start(0, Rules, seed_value)
		check(state.faction_id == "scavenger_clans", "Normal System 1 fields Scavenger Clans")
		state.defense.complete = true
		check(state.generate_system() and state.faction_id == "axiom_collective", "Normal System 2 fields AXIOM Collective")
		var axiom: Resource = Catalog.find(Rules, state.faction_id)
		for entry in state.encounters:
			if entry.kind == "battle":
				check(entry.enemy_data in axiom.standard_roster or entry.enemy_data == axiom.mothership,
					"Opening Warzone contact belongs to AXIOM")
		state.start(0, Rules, seed_value, {"mode": "warzone", "stage": 2, "rank": -1})
		developer[state.faction_id] = true
	check(developer.size() > 1 and developer.has("hollow_choir"), "Developer Warzone launches retain procedural faction selection")


func run() -> void:
	opening_progression()
	var seen: Dictionary = {}
	for seed_value in range(1, 21):
		var state := fresh(seed_value)
		var twin := fresh(seed_value)
		var previous := ""
		for system in range(1, 7):
			var profile: Resource = Catalog.find(state.rules, state.faction_id)
			check(profile != null, "Valid faction")
			seen[state.faction_id] = true
			check(state.faction_id != previous, "No consecutive faction repeats")
			check(
				state.faction_id == twin.faction_id and state.rng.state == twin.rng.state,
				"Deterministic faction and gameplay RNG"
			)
			for i in state.encounters.size():
				var entry: Dictionary = state.encounters[i]
				if entry.kind != "battle":
					continue
				var ship: Resource = entry.enemy_data
				if i == state.defense.mothership_index():
					check(ship.enemy_rank == 2, "Valid existing boss")
				else:
					check(
						ship in profile.standard_roster,
						"Starting and reserve ships belong to faction"
					)
				check(ship == twin.encounters[i].enemy_data, "Deterministic ship identity")
			var encoded := Save.encode(state)
			var restored: Resource = Save.new().decode(encoded, state.rules)
			check(restored != null, "Faction save valid")
			if restored != null:
				check(
					restored.faction_id == state.faction_id and Save.encode(restored) == encoded,
					"Exact faction/roster/deployment/save roundtrip"
				)
			previous = state.faction_id
			if system < 6:
				next(state)
				next(twin)
				if restored != null:
					next(restored)
					check(
						Save.encode(restored) == Save.encode(state),
						"Continue preserves next-system faction and fleet"
					)
	check(seen.size() == 4, "All four factions appear from eligible seeded systems")
	var old := fresh(99)
	var legacy := Save.encode(old)
	legacy.erase("faction_id")
	legacy.encounters[0].enemy_id = "res://ships/enemy/marauder.tres"
	legacy.encounters[1].enemy_id = "res://ships/enemy/sentinel.tres"
	var restored: Resource = Save.new().decode(legacy, old.rules)
	check(
		restored != null and restored.faction_id.is_empty(),
		"Legacy save remains unassigned without retroactive generation"
	)
	if restored != null:
		check(
			(
				restored.encounters[0].enemy_data.resource_path == legacy.encounters[0].enemy_id
				and restored.encounters[1].enemy_data.resource_path == legacy.encounters[1].enemy_id
			),
			"Legacy mixed-faction encounters retained"
		)
		next(restored)
		check(not restored.faction_id.is_empty(), "Legacy next system receives faction")
	var unknown := legacy.duplicate(true)
	unknown.faction_id = "removed_faction"
	var unknown_state: Resource = Save.new().decode(unknown, old.rules)
	check(
		unknown_state != null and unknown_state.faction_id == "removed_faction",
		"Unknown saved identity is retained without selection"
	)
	for invalid_id in [null, 12, "x".repeat(129)]:
		var malformed := legacy.duplicate(true)
		malformed.faction_id = invalid_id
		check(
			Save.new().decode(malformed, old.rules) == null,
			"Invalid saved faction identity rejected"
		)
	for profile in Catalog.DEFAULTS:
		var rules := Rules.duplicate(true)
		rules.factions.assign([profile])
		var state := fresh(17, rules)
		for system in range(1, 7):
			check(state.faction_id == profile.id, "Single/limited roster usable at all early tiers")
			if system < 6:
				next(state)
	var rules := Rules.duplicate(true)
	var invalid := preload("res://scripts/expedition/faction_profile.gd").new()
	invalid.id = "invalid"
	invalid.standard_roster.assign([Resource.new(), null])
	rules.factions.assign([null, invalid])
	check(
		Catalog.find(rules, fresh(42, rules).faction_id) != null,
		"Invalid definitions safely use defaults"
	)
	print("Faction generation: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
