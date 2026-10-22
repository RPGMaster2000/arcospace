extends RefCounted
# Shared rule sequence for live presentation and headless diagnostics.
# Callers own hands, RNG policy and impact cues; existing modules own effect formulas.
const Rules = preload("res://scripts/match_rules.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")

class Resolution extends RefCounted:
	var announcement: String = ""
	var hull_damage: Dictionary = {"actor": 0, "target": 0}
	var extra_action: bool = false


static func can_play(card: Resource, discard: bool, actor: Dictionary) -> bool:
	return card != null and (discard or actor[card.family] >= card.cost)


# Resolve into caller-owned snapshots. Live combat may stage Hull loss before committing them.
static func resolve(
	card: Resource, discard: bool, actor: Dictionary, target: Dictionary,
	modifier: Node = null, generator: RandomNumberGenerator = null
) -> Resolution:
	if not can_play(card, discard, actor):
		return null
	var result = Resolution.new()
	if discard:
		actor[card.family] += floori(card.cost / 3.0)
	elif modifier != null:
		result.announcement = modifier.play(card, actor, target)
		result.hull_damage = modifier.last_hull_damage.duplicate(true)
	else:
		Effects.play(card, actor, target, generator, false, result.hull_damage)
	result.extra_action = not discard and card.play_again
	return result


static func begin_turn(actor: Dictionary) -> void:
	Rules.income(actor)


# Sync before decrementing: recovery and own-turn activation exemption precede expiry.
static func end_turn(states: Dictionary, clock: RefCounted, side: String, duration: int) -> PackedStringArray:
	var notices: PackedStringArray = clock.sync(states, side, duration)
	clock.end_turn(side)
	return notices


static func next_turn(side: String, round_number: int) -> Dictionary:
	return {"side": "enemy" if side == "player" else "player",
		"round": round_number + int(side == "enemy")}


# Hull precedence includes simultaneous losses, before Systems Failure outcomes.
static func outcome(states: Dictionary, clock: RefCounted) -> String:
	var player: Dictionary = states.player
	var enemy: Dictionary = states.enemy
	if player.hull <= 0 and enemy.hull <= 0:
		return "draw_hull"
	if enemy.hull <= 0:
		return "win_hull"
	if player.hull <= 0:
		return "loss_hull"
	var player_failed: bool = clock.remaining.player == 0 and Rules.systems_failure_triggered(player)
	var enemy_failed: bool = clock.remaining.enemy == 0 and Rules.systems_failure_triggered(enemy)
	if player_failed and enemy_failed:
		return "draw_systems"
	if enemy_failed:
		return "win_systems"
	if player_failed:
		return "loss_systems"
	return ""
