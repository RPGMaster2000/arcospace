extends SceneTree
const Effects = preload("res://scripts/cards/card_effects.gd")
const Library = preload("res://scripts/cards/card_library.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func state() -> Dictionary:
	return {"hull":30,"shields":20,"materials":50,"energy":50,"crew":50,"synthesizer":2,"reactor":2,"quarters":2}
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for index in [20,31]:
		var lance = Library.CARDS[index]
		var amount: int = lance.effects.damage
		for shields in [0,3,6,30]:
			var a = state()
			var b = state()
			b.shields = shields
			Effects.play(lance,a,b)
			var blocked: int = mini(shields, amount/2)
			check(b.hull == 30-amount+blocked and b.shields == shields-blocked, "Piercing plus regular spillover is exact")
	var a = state()
	var b = state()
	a.energy = 0
	Effects.play(Library.CARDS[13],a,b)
	check(a.energy == 3 and Library.CARDS[13].play_again, "Energy surge free three and extra action")
	a = state()
	b = state()
	Effects.play(Library.CARDS[24],a,b)
	check(a.energy == 42 and b.materials == 43 and b.energy == 43 and b.crew == 43, "EMP eight cost seven each")
	for pair in [[29,18],[30,20],[31,20],[32,16],[33,18],[34,23],[37,26],[42,13]]:
		check(Library.CARDS[pair[0]].cost == pair[1], "Tier two costs increased and rounded up")
	var rng = RandomNumberGenerator.new()
	rng.seed = 765
	var hits: int = 0
	for trial in range(2000):
		a = state()
		b = state()
		a.shields = 6
		b.shields = 10
		Effects.play(Library.CARDS[40],a,b,rng)
		check(b.shields == 0, "Collapse always removes shields")
		if a.hull == 26:
			hits += 1
			check(a.shields == 0, "Backlash consumes six shields then four hull")
		else: check(a.hull == 30 and a.shields == 6, "Missed backlash leaves actor alone")
	check(hits > 900 and hits < 1100, "Backlash has half probability")
	a = state()
	b = state()
	b.shields = 9
	Effects.play(Library.CARDS[40],a,b,rng)
	check(a.shields == 20 and a.hull == 30, "Low shields remain risk free")
	a = state()
	b = state()
	a.shields = 3
	Effects.play(Library.CARDS[43],a,b,rng)
	check(a.crew == 41 and a.shields == 0 and a.hull == 25 and a.materials+a.energy == 120, "Conversion costs nine crew and eight regular damage")
	print("Card balance checks: %d failures" % failures)
	quit(1 if failures else 0)
