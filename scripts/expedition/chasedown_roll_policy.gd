extends RefCounted

# Exploration risk policy only. Navigation owns whether a journey is active and where it goes.
# The cooldown is active gameplay time; loading or waiting outside gameplay cannot consume it.
const ROLL_COOLDOWN: float = 10.0
var rolled_this_leg: bool = false
var cooldown_remaining: float = 0.0

# A boundary resets only per-leg eligibility; system changes never reset cooldown.
func reset_leg() -> void:
	rolled_this_leg = false

func claim_roll(leg_active: bool) -> bool:
	if not leg_active or rolled_this_leg: return false
	# A skipped roll remains skipped for this entire uninterrupted journey.
	rolled_this_leg = true
	if cooldown_remaining > 0.0: return false
	cooldown_remaining = ROLL_COOLDOWN
	return true

func advance(seconds: float) -> void:
	if is_finite(seconds) and seconds > 0:
		cooldown_remaining = maxf(0, cooldown_remaining - seconds)

func snapshot() -> Dictionary:
	return {"rolled_this_leg": rolled_this_leg, "cooldown_remaining": cooldown_remaining}

func restore(data: Dictionary) -> bool:
	if not data.get("rolled_this_leg") is bool: return false
	var cooldown: Variant = data.get("cooldown_remaining")
	if not (cooldown is int or cooldown is float) or not is_finite(float(cooldown)) or cooldown < 0 or cooldown > ROLL_COOLDOWN: return false
	rolled_this_leg = data.rolled_this_leg
	cooldown_remaining = cooldown
	return true
