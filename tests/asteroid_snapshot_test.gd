extends SceneTree
const Regions = preload("res://scripts/expedition/asteroid_regions.gd")
const EnvironmentData = preload("res://scripts/expedition/battle_environment.gd")
const Modifiers = preload("res://scripts/combat_modifier.gd")
class WorldIdentity extends Resource:
	var seed_used: int = 1042
	var system_number: int = 1
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var state := WorldIdentity.new()
	var records: Array = Regions.generate(1042, 1, [[12.0, 0.0, 0.0]])
	check(EnvironmentData.valid_instances(records), "Physical records pass shared wire validation")
	var selected: Dictionary = EnvironmentData.evaluate(state, [12.0,0.0,0.0], records, 2)
	check(EnvironmentData.valid_snapshot(selected) and selected.type == EnvironmentData.ASTEROID_FIELD, "Valid physical snapshot")
	check(selected == EnvironmentData.evaluate(state, [12.0,0.0,0.0], records, 2), "Pure repeated selection")
	check(EnvironmentData.snapshot(JSON.parse_string(JSON.stringify(selected))) == selected, "Snapshot restores exactly at wire precision")
	check(selected.is_read_only() and selected.configuration.region.is_read_only() and selected.visual.is_read_only(), "Snapshot recursively frozen")
	records[0].position = [100,0,100]
	check(selected.configuration.position == [0.0,0.0,0.0], "Snapshot has no mutable world aliases")
	check(EnvironmentData.modifier_id(EnvironmentData.evaluate(state, [], records, 2)) == 0, "Unknown location is neutral")
	for legacy in range(8):
		var snapshot: Dictionary = EnvironmentData.evaluate(state, [], records, 2, legacy)
		check(EnvironmentData.valid_snapshot(snapshot) and EnvironmentData.modifier_id(snapshot) == legacy, "Legacy IDs preserve original behavior")
	var physical = Modifiers.new()
	var legacy = Modifiers.new()
	physical.configure(EnvironmentData.modifier_id(selected), 778899)
	legacy.configure(1, 778899)
	var a: Dictionary = {"hull": 1000, "shields": 15}
	var b: Dictionary = {"hull": 1000, "shields": 5}
	var c: Dictionary = a.duplicate()
	var d: Dictionary = b.duplicate()
	for round_number in range(1,100):
		var event: String = physical.begin_round(round_number)
		check(event == legacy.begin_round(round_number) and physical.next_round == legacy.next_round, "Physical selection preserves existing event scheduling")
		if event == "ASTEROID SHOWER":
			check(physical.asteroid_strike(a,b) == legacy.asteroid_strike(c,d), "Same independent hit rolls and notifications")
		check(a == c and b == d and physical.rng.state == legacy.rng.state, "Damage, shields and combat RNG identical to existing ID 1")
	var shielded: Dictionary = {"hull": 30, "shields": 15}
	var exposed: Dictionary = {"hull": 30, "shields": 5}
	physical.asteroid_strike(shielded, exposed, [0.49,0.49])
	check(shielded == {"hull":30,"shields":5} and exposed == {"hull":25,"shields":0}, "Existing 10 damage uses shields first")
	physical.asteroid_strike(shielded, exposed, [0.5,0.99])
	check(shielded == {"hull":30,"shields":5} and exposed == {"hull":25,"shields":0}, "Existing strict 50 percent threshold unchanged")
	physical.free()
	legacy.free()
	print("Asteroid snapshots: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
