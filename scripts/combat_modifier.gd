extends Node

# RESPONSIBILITY: Schedule one encounter modifier and resolve its card adjustments.
# DOES NOT: Advance turns, change hands, or present animations.
const Effects = preload("res://scripts/card_effects.gd")
const NAMES = ["None", "Asteroid belt", "Ion storm", "Solar flare", "Nebula", "Temporal Rift"]
## TUNE: Full rounds between events, counted after an event ends.
const TEMPORAL_DROP_MULTIPLIER: float = 2.0 # TUNE: Tier 2 draw multiplier for the whole battle.
const MIN_INTERVAL: int = 3
const MAX_INTERVAL: int = 6
## TUNE: Event duration in complete player/enemy rounds.
const ACTIVE_ROUNDS: int = 3
## TUNE: Independent hit chance for EACH ship when the battlefield launches a shower.
const ASTEROID_CHANCE: float = 0.50
## TUNE: Damage per asteroid hit; shields absorb it first.
const ASTEROID_DAMAGE: int = 10
## TUNE: Internal miss rate: 30 means 70% starting sensor efficiency.
## Change MAX to set minimum efficiency (100 - MAX); STEP controls drift per round.
const NEBULA_START: int = 30
const NEBULA_STEP: int = 5
const NEBULA_MAX: int = 70
var kind: int = 0
var active: bool = false
# One announced multiplier applies to every blue card for the entire storm.
var ion_factor: float = 1.0
var next_round: int = 0
var ends_round: int = 0
var miss_rate: int = NEBULA_START
var last_hull_damage: Dictionary = {"actor":0,"target":0}
var rng := RandomNumberGenerator.new()

func configure(selection: int) -> void:
	kind = clampi(selection, 0, NAMES.size() - 1)
	rng.randomize()
	active = false
	ion_factor = 1.0
	miss_rate = NEBULA_START
	next_round = 1 + rng.randi_range(MIN_INTERVAL, MAX_INTERVAL)

func begin_round(round_number: int) -> String:
	if kind == 0 or kind == 5:
		return ""
	if kind == 4:
		if round_number > 1:
			miss_rate = clampi(miss_rate + rng.randi_range(-NEBULA_STEP, NEBULA_STEP), 0, NEBULA_MAX)
		return "NEBULA · SENSORS UNSTABLE" if round_number == 1 else ""
	if active and round_number >= ends_round:
		active = false
		ion_factor = 1.0
		next_round = round_number + rng.randi_range(MIN_INTERVAL, MAX_INTERVAL)
	if not active and round_number >= next_round:
		if kind == 1:
			# Asteroids are an instant third-party attack, not a round-long card effect.
			next_round = round_number + rng.randi_range(MIN_INTERVAL, MAX_INTERVAL)
			return "ASTEROID SHOWER"
		active = true
		ends_round = round_number + ACTIVE_ROUNDS
		if kind == 2:
			ion_factor = 2.0 if rng.randf() < 0.5 else 0.5
			return "ION STORM · " + ion_text()
		return ["", "ASTEROIDS PASSING", "ION STORM ACTIVE", "SOLAR FLARE · SHIELDS OFFLINE"][kind]
	return ""

func shields_disabled() -> bool:
	return kind == 3 and active

func status_text(round_number: int) -> String:
	if kind == 5:
		return "TEMPORAL RIFT · Tier 2 drop rate ×%.0f" % TEMPORAL_DROP_MULTIPLIER
	if kind == 0:
		return ""
	if kind == 4:
		return "Targeting Sensor Efficiency · Hit rate: %d%%" % (100 - miss_rate)
	if active:
		return NAMES[kind].to_upper() + " ACTIVE · " + ("Shields offline" if kind == 3 else ion_text()) + " · %d rounds left" % maxi(0, ends_round - round_number)
	var phrases: Array[String] = ["", "asteroids pass by", "next ion storm", "next solar flare"]
	return "%d turns until %s" % [maxi(0, next_round - round_number), phrases[kind]]

func meter_value(round_number: int) -> float:
	if kind == 5:
		return 100.0
	if kind == 4:
		return float(100 - miss_rate)
	return 100.0 if active else clampf(100.0 * (1.0 - float(next_round - round_number) / MAX_INTERVAL), 0, 100)

static func is_combat(effects: Dictionary) -> bool:
	for key in ["damage", "break_shields", "drain", "steal", "sabotage", "swap_shields", "shield_collapse_below"]:
		if effects.get(key, false):
			return true
	return false

func _scaled(effects: Dictionary, factor: float) -> Dictionary:
	var result: Dictionary = effects.duplicate(true)
	for key in result:
		if key == "sabotage" and result[key] is bool:
			# Legacy true means -1 to each enemy production; ion scales this amount too.
			result[key] = int(floor((1.0 if result[key] else 0.0) * factor))
		elif result[key] is Dictionary:
			result[key] = _scaled(result[key], factor)
		elif key not in ["pierce", "shield_collapse_below"] and (result[key] is int or result[key] is float):
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
		# A miss cancels target/bonus effects; explicit self-damage remains an unavoidable cost.
		modified.effects = {"self_damage": card.effects.self_damage} if card.effects.has("self_damage") else {}
		notice = "MISS · NEBULA INTERFERENCE"
	elif kind == 2 and active and card.family == "energy":
		# The already announced storm multiplier also drives the card previews.
		var factor: float = ion_factor
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
	Effects.play(modified, actor, target, rng, false, last_hull_damage)
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

func ion_text() -> String:
	return "BLUE CARDS ×2 · Energy amplified" if ion_factor == 2.0 else "BLUE CARDS ×½ · Energy suppressed"

func preview(card: Resource) -> Resource:
	if card == null or kind != 2 or not active or card.family != "energy":
		return card
	var shown = card.duplicate(true)
	shown.effects = _scaled(card.effects, ion_factor)
	var lines: Array[String] = ["ION ×2" if ion_factor == 2.0 else "ION ×½"]
	for key in shown.effects:
		var value = shown.effects[key]
		match key:
			"damage": lines.append("Deal %d damage" % value)
			"break_shields": lines.append("Enemy Shields −%d" % value)
			"pierce": lines.append("%d%% bypasses Shields" % roundi(value * 100))
			"drain", "steal":
				for resource in value:
					lines.append(("Steal %d %s" if key == "steal" else "Enemy −%d %s") % [value[resource], resource.capitalize()])
			"sabotage": lines.append("Enemy production −%d each (min 1)" % int(value))
			"swap_shields": lines.append("Swap Shields")
			"random_gain": lines.append("Gain %d random resource" % value)
			"random_gain_other": lines.append("Gain %d random other resource" % value)
			"random_gain_range_other": lines.append("Gain %d–%d random other resource" % [value.min, value.max])
			"production_other": lines.append("+%d %s, +%d corresponding resource" % [value.production, str(value.type).capitalize(), value.resource])
			"self_damage": lines.append("Take %d direct Hull damage" % value)
			"shield_collapse_below": lines.append("Remove enemy Shields if below %d" % value)
			_: lines.append("%+d %s" % [value, str(key).capitalize()])
	if card.play_again:
		lines.append("Play again")
	shown.description = " · ".join(lines)
	return shown
