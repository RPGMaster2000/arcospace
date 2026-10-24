extends RefCounted
# Read-only numerical possibilities, not AI policy or a second effect resolver.
const Modifier = preload("res://scripts/combat_modifier.gd")
const Rules = preload("res://scripts/match_rules.gd")
# Bound resolver replays, not recursion or authored effect depth. Incomplete => no guarantees.
const MAX_REPLAYS = 64

# Replay explicit draw indices. Unknown draws fork the next replay; never sample an RNG.
class Draws extends RefCounted:
	var prefix: Array = []
	var index: int = 0
	var fork_size: int = 0
	var fork_prefix: Array = []
	var path: Array = []
	func pick(count: int) -> int:
		var selected: int = int(prefix[index]) if index < prefix.size() else 0
		if index >= prefix.size() and count > 1 and fork_size == 0:
			fork_size = count
			fork_prefix = path.duplicate()
		path.append(selected)
		index += 1
		return selected
	func randi_range(low: int, high: int) -> int:
		return low + pick(high - low + 1)
	func randf() -> float:
		# Endpoints span every < chance outcome, including native randf's inclusive 1.
		return float(pick(2))

# Context is Modifier.forecast_context(): kind, active, ion_factor, miss_rate; no Node/RNG.
# Outcomes are attainable detached states, not expected values or equally weighted samples.
# complete=false means a bounded subset only; never infer guarantees from that subset.
static func predict(card: Resource, actor: Dictionary, target: Dictionary, context: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {"affordable":card != null and actor.get(card.family,0) >= card.cost,"outcomes":[],"complete":true,"uncertain":false,"possible_win":false,"guaranteed_win":false,"possible_self_destruction":false,"guaranteed_self_destruction":false,"limitations":[],"replays":0}
	if not result.affordable: return result
	var miss_rate: float = float(context.get("miss_rate",30)) / 100.0 if context.get("kind",0) == 4 and Modifier.is_combat(card.effects) else 0.0
	result["miss_probability"] = miss_rate
	var queue: Array = []
	if miss_rate < 1.0: queue.append({"miss":false,"prefix":[]})
	if miss_rate > 0.0: queue.append({"miss":true,"prefix":[]})
	var seen: Dictionary = {}
	while not queue.is_empty() and result.replays < MAX_REPLAYS:
		var request: Dictionary = queue.pop_front()
		var draws = Draws.new()
		draws.prefix = request.prefix
		var a: Dictionary = actor.duplicate(true)
		var b: Dictionary = target.duplicate(true)
		var report: Dictionary = {}
		Modifier.resolve_effects(card,a,b,context,null,report,draws,request.miss)
		result.replays += 1
		if draws.fork_size > 1 and result.replays + queue.size() + draws.fork_size <= MAX_REPLAYS:
			for choice in range(draws.fork_size):
				queue.append({"miss":request.miss,"prefix":draws.fork_prefix + [choice]})
			continue
		if draws.fork_size > 1: result.complete = false
		var outcome: Dictionary = {"actor":a,"target":b,"damage":report,"miss":request.miss}
		var key: String = JSON.stringify(outcome)
		if not seen.has(key):
			seen[key] = true
			result.outcomes.append(outcome)
	if not queue.is_empty(): result.complete = false
	if not result.complete: result.limitations.append("Outcome budget reached; possible states are a subset, guarantees unavailable")
	result.uncertain = not result.complete or result.outcomes.size() > 1
	var all_win: bool = not result.outcomes.is_empty()
	var all_dead: bool = all_win
	for outcome in result.outcomes:
		var wins: bool = outcome.actor.hull > 0 and Rules.wins(outcome.actor,outcome.target)
		var dead: bool = outcome.actor.hull <= 0
		result.possible_win = result.possible_win or wins
		result.possible_self_destruction = result.possible_self_destruction or dead
		all_win = all_win and wins
		all_dead = all_dead and dead
	result.guaranteed_win = result.complete and all_win
	result.guaranteed_self_destruction = result.complete and all_dead
	return result
