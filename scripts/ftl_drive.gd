extends Node

# RESPONSIBILITY: Player-only FTL charge and temporary disruption state.
# DOES NOT: Advance turns, resolve damage, or declare the match winner.
## TUNE: Increase this for more player turns before warp; the counter and bar follow automatically.
const FULL_CHARGE: int = 14
## TUNE: Number of player turns with no charging or warp after an FTL failure.
const DISABLED_TURNS: int = 5
## TUNE: Failure chance added per actual hull damage point; 0.05 = 5%. Shield damage does not count.
const FAILURE_CHANCE_PER_DAMAGE: float = 0.05
## TUNE: Maximum failure chance per damaging action; 0.60 = 60%, reached at 12 hull damage.
const MAX_FAILURE_CHANCE: float = 0.60
var charge: int = 0
var disabled_turns: int = 0
var disabled_turn_started: bool = false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()

func begin_player_turn() -> void:
	# A disabled turn counts only after the player has actually had that turn.
	if disabled_turn_started:
		disabled_turns = maxi(0, disabled_turns - 1)
	disabled_turn_started = disabled_turns > 0
	if not disabled_turn_started:
		charge = mini(FULL_CHARGE, charge + 1)

func failure_chance(amount: int) -> float:
	return clampf(amount * FAILURE_CHANCE_PER_DAMAGE, 0.0, MAX_FAILURE_CHANCE)

func take_hull_damage(amount: int, roll: float = -1.0) -> bool:
	if amount <= 0 or disabled_turns > 0:
		return false
	var chance_roll: float = rng.randf() if roll < 0.0 else roll
	if chance_roll >= failure_chance(amount):
		return false
	disabled_turns = DISABLED_TURNS
	disabled_turn_started = false
	return true

func can_warp() -> bool:
	return charge == FULL_CHARGE and disabled_turns == 0
