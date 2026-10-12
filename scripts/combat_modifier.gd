extends Node

# RESPONSIBILITY: Schedule one encounter modifier and resolve its card adjustments.
# DOES NOT: Advance turns, change hands, or present animations.
const Effects = preload("res://scripts/card_effects.gd")
const NAMES = ["None", "Asteroid belt", "Ion storm", "Solar flare", "Nebula"]
## TUNE: Full rounds between events, counted after an event ends.
const MIN_INTERVAL: int = 3
const MAX_INTERVAL: int = 6
## TUNE: Event duration in complete player/enemy rounds.
const ACTIVE_ROUNDS: int = 1
## TUNE: Independent hit chance for EACH ship when the battlefield launches a shower.
const ASTEROID_CHANCE: float = 0.50
## TUNE: Damage per asteroid hit; shields absorb it first.
const ASTEROID_DAMAGE: int = 10
## TUNE: Nebula starts here; each full round moves by at most NEBULA_STEP percentage points.
const NEBULA_START: int = 25
const NEBULA_STEP: int = 5
const NEBULA_MAX: int = 60
var kind: int = 0
var active: bool = false
var next_round: int = 0
var ends_round: int = 0
var miss_rate: int = NEBULA_START
var rng := RandomNumberGenerator.new()

func configure(selection: int) -> void:
	kind = clampi(selection, 0, NAMES.size() - 1)
	rng.randomize()
	active = false
	miss_rate = NEBULA_START
	next_round = 1 + rng.randi_range(MIN_INTERVAL, MAX_INTERVAL)

func begin_round(round_number: int) -> String:
	if kind == 0:
		return ""
	if kind == 4:
		if round_number > 1:
			miss_rate = clampi(miss_rate + rng.randi_range(-NEBULA_STEP, NEBULA_STEP), 0, NEBULA_MAX)
		return "NEBULA · SENSORS UNSTABLE" if round_number == 1 else ""
	if active and round_number >= ends_round:
		active = false
		next_round = round_number + rng.randi_range(MIN_INTERVAL, MAX_INTERVAL)
	if not active and round_number >= next_round:
		if kind == 1:
			# Asteroids are an instant third-party attack, not a round-long card effect.
			next_round = round_number + rng.randi_range(MIN_INTERVAL, MAX_INTERVAL)
			return "ASTEROID SHOWER"
		active = true
		ends_round = round_number + ACTIVE_ROUNDS
		return ["", "ASTEROIDS PASSING", "ION STORM ACTIVE", "SOLAR FLARE · SHIELDS OFFLINE"][kind]
	return ""

func shields_disabled() -> bool:
	return kind == 3 and active

func status_text(round_number: int) -> String:
	if kind == 0:
		return ""
	if kind == 4:
		return "Targeting Sensors Affected - Miss rate: %d%%" % [miss_rate, miss_rate]
	if active:
		return NAMES[kind].to_upper() + " ACTIVE · " + ("Shields offline" if kind == 3 else "Both ships affected")
	var phrases: Array[String] = ["", "asteroids pass by", "next ion storm", "next solar flare"]
	return "%d turns until %s" % [maxi(0, next_round - round_number), phrases[kind]]

func meter_value(round_number: int) -> float:
	if kind == 4:
		return float(miss_rate) / NEBULA_MAX * 100.0
	return 100.0 if active else clampf(100.0 * (1.0 - float(next_round - round_number) / MAX_INTERVAL), 0, 100)

static func is_combat(effects: Dictionary) -> bool:
	for key in ["damage", "break_shields", "drain", "steal", "sabotage", "swap_shields"]:
		if effects.get(key, false):
			return true
	return false

func _scaled(effects: Dictionary, factor: float) -> Dictionary:
	var result: Dictionary = effects.duplicate(true)
	for key in result:
		if result[key] is Dictionary:
			result[key] = _scaled(result[key], factor)
		elif key != "pierce" and (result[key] is int or result[key] is float):
			# TUNE: Half effects round down, including +1 production becoming zero.
			result[key] = int(floor(float(result[key]) * factor))
	return result

func play(card: Resource, actor: Dictionary, target: Dictionary, roll: float = -1.0) -> String:
	if actor[card.family] < card.cost:
		return ""
	var modified: Resource = card.duplicate(true)
	var notice: String = ""
	var chance: float = rng.randf() if roll < 0.0 else roll
	if kind == 4 and is_combat(card.effects) and chance < miss_rate / 100.0:
		# A miss spends the card/cost and cancels its effects, including mixed repairs.
		modified.effects = {}
		notice = "MISS · NEBULA INTERFERENCE"
	elif kind == 2 and active and card.family == "energy":
		# TUNE: Equal chance of doubling or halving each blue card; costs never change.
		var factor: float = 2.0 if chance < 0.5 else 0.5
		modified.effects = _scaled(card.effects, factor)
		notice = "ION STORM · BLUE CARD " + ("×2" if factor == 2.0 else "×½")
	var saved_actor_shields: int = actor.shields
	var saved_target_shields: int = target.shields
	if shields_disabled():
		actor.shields = 0
		target.shields = 0
		modified.effects = modified.effects.duplicate(true)
		modified.effects.erase("shields")
		modified.effects.erase("swap_shields")
	Effects.play(modified, actor, target)
	if shields_disabled():
		# Shield strength is reserved during the flare, not destroyed or regenerated.
		actor.shields = saved_actor_shields
		target.shields = saved_target_shields
	return notice

func asteroid_strike(player: Dictionary, enemy: Dictionary, rolls: Array = []) -> String:
	var outcomes: Array[String] = []
	var ships: Array[Dictionary] = [player, enemy]
	for index in range(2):
		var roll: float = rng.randf() if rolls.is_empty() else float(rolls[index])
		var hit: bool = roll < ASTEROID_CHANCE
		if hit:
			var blocked: int = mini(ships[index].shields, ASTEROID_DAMAGE)
			ships[index].shields -= blocked
			ships[index].hull = maxi(0, ships[index].hull - ASTEROID_DAMAGE + blocked)
		outcomes.append(("YOU" if index == 0 else "ENEMY") + (" HIT" if hit else " MISSED"))
	return "ASTEROID SHOWER · " + " / ".join(outcomes)
