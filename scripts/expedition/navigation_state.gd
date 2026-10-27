extends RefCounted
# Authoritative journey eligibility and active-gameplay cooldown, shared by all destinations.
const ROLL_COOLDOWN: float = 10.0
var position: Array = []
var target: Array = []
var leg_active: bool = false
var rolled_this_leg: bool = false
var cooldown_remaining: float = 0.0

static func valid_point(value: Variant, allow_empty: bool = true) -> bool:
	if not value is Array: return false
	if value.is_empty(): return allow_empty
	if value.size() != 3: return false
	for coordinate in value:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or absf(float(coordinate)) > 10000: return false
	return true

func begin(point: Array = []) -> bool:
	target = point.duplicate()
	if leg_active: return false
	leg_active = true
	# A skipped roll remains skipped for this entire uninterrupted journey.
	rolled_this_leg = false
	return true

func claim_roll() -> bool:
	if not leg_active or rolled_this_leg: return false
	rolled_this_leg = true
	if cooldown_remaining > 0.0: return false
	cooldown_remaining = ROLL_COOLDOWN
	return true

func advance(seconds: float) -> void:
	if is_finite(seconds) and seconds > 0: cooldown_remaining = maxf(0, cooldown_remaining - seconds)

func stop() -> void:
	leg_active = false
	rolled_this_leg = false
	target.clear()

func reset_system() -> void:
	# Cooldown spans system transitions; a jump cannot farm a fresh roll.
	stop()
	position.clear()

func snapshot() -> Dictionary:
	return {"position": position.duplicate(), "target": target.duplicate(), "leg_active": leg_active,
		"rolled_this_leg": rolled_this_leg, "cooldown_remaining": cooldown_remaining}

func restore(data: Dictionary) -> bool:
	if not valid_point(data.get("position")) or not valid_point(data.get("target")): return false
	if not data.get("leg_active") is bool or not data.get("rolled_this_leg") is bool: return false
	var cooldown: Variant = data.get("cooldown_remaining")
	if not (cooldown is int or cooldown is float) or not is_finite(float(cooldown)) or cooldown < 0 or cooldown > ROLL_COOLDOWN: return false
	if not data.leg_active and (data.rolled_this_leg or not data.target.is_empty()): return false
	position = data.position.duplicate()
	target = data.target.duplicate()
	leg_active = data.leg_active
	rolled_this_leg = data.rolled_this_leg
	cooldown_remaining = cooldown
	return true
