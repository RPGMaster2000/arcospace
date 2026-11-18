extends RefCounted
## Prototype actions outside card hands. Board owns turn and presentation timing.
const Modifier = preload("res://scripts/combat_modifier.gd")
const PAYMENTS = ["materials", "energy", "crew"]
const OVERDRIVE = [
	{"title": "Shield Boost", "cost": 30, "payments": PAYMENTS, "shields": 25, "damage": 0},
	{"title": "Powerful Attack", "cost": 30, "payments": PAYMENTS, "shields": 0, "damage": 24},
]
const BEAM_DAMAGE = 25
enum Beam { READY, CHARGING, DISRUPTED, SPENT }

var beam := Beam.READY
var charge_hull := 0
var overdrive_used := false
var rng := RandomNumberGenerator.new()


static func overdrive(action: int, payment: String, actor: Dictionary, target: Dictionary) -> bool:
	if action < 0 or action >= OVERDRIVE.size():
		return false
	var option: Dictionary = OVERDRIVE[action]
	if payment not in option.payments or int(actor.get(payment, 0)) < option.cost:
		return false
	actor[payment] -= option.cost
	actor.shields += option.shields
	Modifier.shielded_hit(target, option.damage)
	return true


static func interrupt_chance(damage: int, hull_at_charge: int) -> float:
	return minf(0.85, 2.5 * maxi(0, damage) / maxi(1, hull_at_charge))


func interrupt(damage: int) -> bool:
	if beam != Beam.CHARGING or damage <= 0:
		return false
	if rng.randf() >= interrupt_chance(damage, charge_hull):
		return false
	beam = Beam.DISRUPTED
	return true
