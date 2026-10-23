extends SceneTree
const Targets = preload("res://scripts/cards/card_targets.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func ship() -> Dictionary:
	return {"hull":20,"hull_capacity":30,"shields":5,"materials":12,"energy":10,"crew":10,"synthesizer":2,"reactor":2,"quarters":2}
func preview(effects: Dictionary, context: Dictionary) -> Dictionary:
	var card = preload("res://scripts/cards/card_data.gd").new()
	card.family = "energy"
	card.cost = 2
	card.effects = effects
	return Targets.analyze(card, context)
func _initialize() -> void:
	var context: Dictionary = {"player":ship(), "enemy":ship(), "shields_disabled":false, "nebula_miss_rate":0}
	check(preview({"hull":4},context).has("player_hull"), "Repair identifies player Hull")
	var data = preview({"damage":3},context)
	check(data.has("enemy_shields") and not data.has("enemy_hull"), "Shield absorption identifies only Shields")
	check(data.player_energy == ["cost"], "Payment is distinct from effect")
	data = preview({"damage":8,"pierce":1.0},context)
	check(data.has("enemy_hull") and not data.has("enemy_shields"), "Piercing bypasses Shields")
	data = preview({"enemy_production":{"reactor":-1}},context)
	check(data.enemy_reactor == ["negative"] and not data.has("enemy_energy"), "Sabotage identifies production only")
	data = preview({"steal":{"energy":4}},context)
	check("positive" in data.player_energy and "cost" in data.player_energy and data.enemy_energy == ["negative"], "Theft communicates both sides and cost")
	data = preview({"random_sabotage":1},context)
	for key in Effects.PRODUCTION: check(data["enemy_" + key] == ["uncertain"], "Random sabotage is uncertain")
	data = preview({"conditional":{"attribute":"hull","threshold":20,"then":{"shields":3},"else":{"hull":2}}},context)
	check(data.has("player_shields") and not data.has("player_hull"), "Current condition chooses only one branch")
	data = preview({"hull":4,"conditional":{"attribute":"hull","threshold":20,"then":{"shields":3},"else":{"crew":2}}},context)
	check(data.has("player_crew") and not data.has("player_shields"), "Condition uses existing resolver ordering")
	context.nebula_miss_rate = 30
	check(preview({"damage":3},context).enemy_shields == ["uncertain"], "Nebula marks intended hits uncertain")
	context.nebula_miss_rate = 0
	context.shields_disabled = true
	data = preview({"damage":3,"shields":4},context)
	check(data.has("enemy_hull") and not data.has("enemy_shields") and not data.has("player_shields"), "Flare ignores reserved Shields")
	var modifier = preload("res://scripts/combat_modifier.gd").new()
	modifier.kind = 2
	modifier.active = true
	modifier.ion_factor = 2.0
	var energy = preload("res://scripts/cards/card_data.gd").new()
	energy.family = "energy"
	energy.effects = {"damage":4}
	context.shields_disabled = false
	data = Targets.analyze(modifier.preview(energy),context)
	check(data.has("enemy_hull") and data.has("enemy_shields"), "Ion effective damage reaches through Shields")
	modifier.free()
	var before: String = str(context)
	var rng_state: int = Effects.combat_rng.state
	for card in Cards.CARDS:
		for level in range(3):
			Targets.analyze(card.with_upgrade(level),context)
	check(str(context) == before and Effects.combat_rng.state == rng_state, "Every card and upgrade leaves state and RNG unchanged")
	print("Card targets: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
