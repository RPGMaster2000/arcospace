extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func fresh(rules: Resource) -> Resource:
	var state := State.new()
	state.start(0, rules, 17891)
	return state


func secure(state: Resource) -> void:
	state.defense.revealed = true
	for unit in state.defense.units:
		state.defense.neutralize(unit.encounter)
	for unit in state.defense.units:
		if unit.status in ["neutralized", "secured"]:
			state.encounters[unit.encounter].completed = true
	state._secure_defense()


func run() -> void:
	var rules := Rules.duplicate(true)
	rules.game_mode = "defense"
	var store := Save.new()
	store.path = "user://warzone-campaign-test.json"
	store.clear_run()
	var state := fresh(rules)
	check(state.is_defense() and state.next_campaign_operation() == "warzone", "Homeworld is Defense and the next campaign operation is Warzone")
	check(not state.generate_system() and state.homeworld_outcome.is_empty(), "An unsecured Homeworld cannot generate a campaign outcome")
	check(not Save.encode(state).has("homeworld_outcome"), "Incomplete and older runs need no artificial history")

	var tuning: Resource = rules.warzone_tuning
	var support = State.CampaignSupport
	var last_strength := 0
	for entry in [[1, "emergency"], [19, "emergency"], [20, "limited"], [49, "limited"],
			[50, "standard"], [79, "standard"], [80, "strong"], [100, "strong"]]:
		var package: Dictionary = support.homeworld_package({"integrity": entry[0], "maximum_integrity": 100}, tuning)
		check(package.tier == entry[1] and package.fleet_strength >= last_strength, "Threshold and fleet strength at %d%% integrity" % entry[0])
		check(package.salvage > 0 and package.shields > 0, "Every tier provides supplies and a shield boon")
		last_strength = package.fleet_strength
	check(support.homeworld_package({"integrity": 40, "maximum_integrity": 50}, tuning).tier == "strong", "Thresholds use relative integrity")
	check(state.warzone_support_package().tier == "standard", "Old checkpoints without Homeworld history use standard support")

	state.defense.integrity = 19
	state.production_upgrades = {"reactor": 2}
	var card: Resource = state.upgrade_candidates()[0]
	state.upgraded_cards = {card.identity_key(): card.with_upgrade(1)}
	secure(state)
	check(state.can_jump() and state.homeworld_outcome.secured and state.homeworld_outcome.integrity == 19, "Securing Defense captures the live integrity")
	check(state.warzone_support_package().tier == "emergency" and state.defense.integrity == 19, "Deriving support preserves the live Homeworld")
	check(store.save_run(state), "Write secured Homeworld checkpoint: " + store.error)
	var restored = store.load_run().get("state")
	check(restored != null, "Read secured Homeworld checkpoint from disk")
	if restored != null:
		check(restored.homeworld_outcome.integrity == 19 and restored.homeworld_outcome.production_upgrades.reactor == 2, "History preserves integrity and production upgrades across saves")
		check(restored.homeworld_outcome.card_upgrades.get(card.identity_key()) == 1, "History preserves card upgrades across saves")
		restored.salvage += 7
		var departing_salvage: int = restored.salvage
		var package: Dictionary = restored.warzone_support_package()
		check(restored.generate_system() and restored.system_number == 2 and restored.is_warzone(), "Campaign transition uses the existing jump gate to enter Warzone")
		check(restored.homeworld_outcome.integrity == 19 and restored.homeworld_outcome.salvage == departing_salvage, "Departure preserves Homeworld and records the final player inventory")
		check(restored.salvage == departing_salvage + package.salvage and restored.pending_bonuses.shields == package.shields,
			"Entry grants the historical support package once")
		var post_jump: Dictionary = Save.encode(restored)
		check(store.decode(post_jump, rules) != null, "History survives in a later-system checkpoint")
		post_jump.homeworld_outcome.integrity = 101
		check(store.decode(post_jump, rules) == null, "Impossible historical integrity is rejected")
		var legacy: Dictionary = Save.encode(state)
		legacy.erase("homeworld_outcome")
		check(store.decode(legacy, rules) != null, "Legacy Defense saves stay loadable")
	store.clear_run()

	rules.game_mode = "exploration"
	state = fresh(rules)
	check(state.next_campaign_operation() == "exploration" and not Save.encode(state).has("homeworld_outcome"), "Exploration has no Defense campaign history")
	print("Warzone campaign: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
