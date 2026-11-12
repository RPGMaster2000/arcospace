extends SceneTree
const Effects = preload("res://scripts/expedition/defense_poi_effects.gd")
var failures := 0
var checks := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void:
	var effects := Effects.new()
	effects.grant_production("synthesizer",1,3)
	effects.grant_production("reactor",2,2)
	effects.grant_production("reactor",1,3)
	check(effects.bonus("reactor") == 2, "Identical categories do not add or multiply")
	check(effects.bonus("synthesizer") == 1, "Different categories coexist")
	effects.mothership = "penetration"
	effects.pause = 15
	effects.reduction = 30
	effects.fuel = 30
	var copy := Effects.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(effects.snapshot()))), "Wire roundtrip accepts canonical values")
	copy.production.reactor.battles = 1
	check(effects.production.reactor.battles == 3, "Restore owns detached mutable state")
	check(effects.pressure_multiplier() == 0 and effects.next_boundary() == 15, "Pause takes precedence without negative rate")
	effects.advance_seconds(15)
	check(effects.pressure_multiplier() == 0.5 and effects.next_boundary() == 15, "Pause expiry reveals remaining reduction")
	effects.advance_seconds(15)
	check(effects.pressure_multiplier() == 1 and effects.next_boundary() == INF, "Reduction expires")
	effects.consume_distance(12)
	effects.leave_system()
	check(effects.fuel == 18 and effects.bonus("reactor") == 2, "Expedition scopes survive system departure")
	check(effects.mothership.is_empty(), "System combat advantage expires")
	for battle in range(3):
		check(effects.bonus("synthesizer") == 1, "Effect remains until completed battle")
		effects.completed_battle()
	check(effects.production.is_empty(), "Exactly three completions remove production")
	for invalid in [{}, {"production":{},"mothership":"unknown","pause":0,"reduction":0,"fuel":0},
		{"production":{},"mothership":"","pause":-1,"reduction":0,"fuel":0},
		{"production":{"reactor":{"amount":1.5,"battles":3}},"mothership":"","pause":0,"reduction":0,"fuel":0}]:
		check(not copy.restore(invalid), "Malformed identifiers, bounds and fractional charges rejected")
	print("Defense PoI effect ledger: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
