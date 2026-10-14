extends SceneTree
const Effects = preload("res://scripts/card_effects.gd")
const Library = preload("res://scripts/card_library.gd")
const Mod = preload("res://scripts/combat_modifier.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func state() -> Dictionary:
	return {"hull":30,"shields":20,"materials":40,"energy":40,"crew":40,"synthesizer":2,"reactor":2,"quarters":2}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var generator = RandomNumberGenerator.new()
	generator.seed = 3456
	var new_cards: Array = Library.CARDS.slice(35)
	check(new_cards.size() == 9, "Exactly nine new cards registered")
	for card in new_cards:
		var a = state()
		var b = state()
		Effects.play(card, a, b, generator)
		check(a[card.family] == 40 - card.cost or card.effects.has("random_gain"), "Cost paid once, cross gains exclude family")
		check(card.tier == (2 if card.card_name in ["Cataclysm Protocol", "Emergency Reserves"] else 1), "Proposed tiers preserved")
	var collapse = Library.CARDS[40]
	for strength in [0,9,10,11]:
		var a = state()
		var b = state()
		b.shields = strength
		Effects.play(collapse,a,b,generator)
		check(b.shields == 0, "Shield Collapse removes shields at all strengths")
	var a = state()
	var b = state()
	Effects.play(Library.CARDS[41],a,b,generator)
	check(a.hull == 26 and a.shields == 20 and b.shields == 10, "Warhead self damage bypasses shield")
	a = state()
	b = state()
	Effects.play(Library.CARDS[38],a,b,generator)
	check(a.reactor == 3 and a.energy == 45 and a.materials == 33, "Reactor salvage upgrades matching cross resource")
	var selection_counts = {"materials":0,"crew":0}
	for draw in range(4000):
		a = state()
		b = state()
		Effects.play(Library.CARDS[42],a,b,generator)
		var gain: int = a.materials - 40 + a.crew - 40
		check(gain >= 12 and gain <= 15 and a.energy == 27, "Reserve range and exclusion")
		selection_counts["materials" if a.materials > 40 else "crew"] += 1
	check(absi(selection_counts.materials - selection_counts.crew) < 250, "Cross resources have equal odds")
	var ai = load("res://scripts/enemy_ai.gd").new()
	a = state()
	b = state()
	var old_a = a.duplicate(true)
	var old_b = b.duplicate(true)
	var random_state: int = Effects.combat_rng.state
	ai.choose(new_cards,a,b,100)
	check(a == old_a and b == old_b and Effects.combat_rng.state == random_state, "AI cannot consume combat RNG or mutate live states")
	a.hull = 5
	a.shields = 0
	var move = ai.choose([Library.CARDS[43]],a,b,100)
	check(move.discard, "AI discards fatal conversion rather than falsely claiming resource victory")
	ai.free()
	var mod = Mod.new()
	mod.configure(2)
	mod.active = true
	for factor in [2.0,0.5]:
		mod.ion_factor = factor
		var preview = mod.preview(Library.CARDS[42])
		a = state()
		b = state()
		mod.play(Library.CARDS[42],a,b)
		var gained: int = a.materials - 40 + a.crew - 40
		check(gained >= preview.effects.random_gain_range_other.min and gained <= preview.effects.random_gain_range_other.max, "Ion preview range equals actual gain")
		check(mod.preview(collapse).effects.shield_collapse.threshold == 10, "Ion does not alter conditional threshold")
	mod.configure(4)
	mod.miss_rate = 70
	a = state()
	b = state()
	mod.play(Library.CARDS[41],a,b,0.0)
	check(a.hull == 26 and b == state(), "Miss preserves unavoidable self damage")
	mod.free()
	print("Tactical card checks: %d failures" % failures)
	quit(1 if failures else 0)
