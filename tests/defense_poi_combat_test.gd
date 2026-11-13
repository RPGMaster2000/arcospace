extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Card = preload("res://scripts/cards/card_data.gd")
const Execution = preload("res://scripts/combat/combat_execution.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Persistence = preload("res://scripts/expedition/expedition_persistence.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func stats() -> Dictionary:
	return {"hull":100,"hull_capacity":100,"shields":100,"materials":100,"energy":100,"crew":100,"synthesizer":2,"reactor":2,"quarters":2}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var card := Card.new()
	card.family = "materials"
	card.cost = 0
	card.effects = {"damage":5,"shields":4,"hull":3,"reactor":1,"self_damage":2}
	var modifier := Modifier.new()
	var actor := stats()
	var target := stats()
	Execution.resolve(card,false,actor,target,modifier,null,"penetration")
	check(target.hull == 95 and target.shields == 100, "Penetration applies player attack to Hull without deleting Shields")
	check(actor.hull == 101 and actor.shields == 104 and actor.reactor == 3, "Penetration leaves healing, Shields, production and self-damage alone")
	actor = stats(); target = stats()
	Execution.resolve(card,false,actor,target,modifier,null,"damage")
	check(target.hull == 100 and target.shields == 92, "Odd integer damage rounds half upward: five becomes eight")
	check(actor.hull == 101 and actor.shields == 104 and actor.reactor == 3, "Damage bonus does not scale non-attack effects")
	actor = stats(); target = stats()
	Execution.resolve(card,false,actor,target,modifier)
	check(target.shields == 95, "Default card execution remains unchanged")
	card.effects = {"damage":3,"conditional":{"attribute":"hull","comparison":"at_most","threshold":200,"then":{"damage":5}}}
	actor = stats(); target = stats()
	Execution.resolve(card,false,actor,target,modifier,null,"damage")
	check(target.shields == 87, "Both ordinary and selected conditional attack packets receive rounded bonus")
	var unrelated := stats()
	modifier.shielded_hit(unrelated,5)
	check(unrelated.shields == 95 and unrelated.hull == 100, "Turret/environmental hit helper has no card advantage")
	var state := State.new()
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	state.start(0,rules,1042)
	state.poi_effects.mothership = "damage"
	var boss: int = state.defense.mothership_index()
	var frozen: Dictionary = state.battle_environment(boss)
	check(frozen.get("mothership_advantage") == "damage" and frozen.is_read_only(), "Boss entry freezes the selected advantage")
	check(not state.battle_environment(0).has("mothership_advantage"), "Normal enemy entry never receives mothership advantage")
	state.defense.revealed = true
	state.defense.pressure = 50
	state.defense.contact = boss
	state.defense.missiles.countdown = 8
	var persistence := Persistence.new()
	persistence.enabled = false
	var entry: Dictionary = persistence.checkpoint_battle(state,boss,987)
	var store := Save.new()
	store.path = "user://defense_poi_boss_checkpoint.json"
	check(entry.saved and store.save_data(persistence.battle_checkpoint,persistence.battle_marker), "Boss advantage uses the existing battle-entry checkpoint")
	var loaded: Dictionary = store.load_run()
	check(not loaded.is_empty() and loaded.get("battle",{}).get("environment",{}).get("mothership_advantage") == "damage", "Unfinished boss restoration preserves effective card damage rules")
	store.clear_run()
	state.poi_effects.leave_system()
	check(frozen.mothership_advantage == "damage" and state.poi_effects.mothership.is_empty(), "World expiry cannot mutate an active battle snapshot")
	modifier.free()
	print("Defense PoI combat advantages: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
