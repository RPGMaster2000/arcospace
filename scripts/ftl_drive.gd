extends Node

# RESPONSIBILITY: Player-only FTL charge and temporary disruption state.
# DOES NOT: Advance turns, resolve damage, or declare the match winner.
const FULL_CHARGE: int = 8
const DISABLED_TURNS: int = 5
const FAILURE_CHANCE: float = 0.2
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

func take_hull_damage(amount: int, roll: float = -1.0) -> bool:
	if amount <= 0 or disabled_turns > 0:
		return false
	var chance_roll: float = rng.randf() if roll < 0.0 else roll
	if chance_roll >= FAILURE_CHANCE:
		return false
	disabled_turns = DISABLED_TURNS
	disabled_turn_started = false
	return true

func can_warp() -> bool:
	return charge == FULL_CHARGE and disabled_turns == 0
