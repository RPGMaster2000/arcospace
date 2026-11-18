extends RefCounted
## Optional battle marker for settled player turns after a prototype action.
## The expedition entry checkpoint still owns bonuses, rewards and environment.
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const SPECIAL = preload("res://cards/enemy/iron_counterbattery.tres")
const STATS = Ship.ATTRIBUTES + ["hull_capacity"]
const COUNTERS = ["turn_number", "last_turret_round", "player_hull_damage_taken", "charge_hull", "beam"]
const DRIVE = ["charge", "disabled_turns"]
const WEATHER = ["next_round", "ends_round", "miss_rate", "ion_factor"]
const SIDES = ["player", "enemy"]


static func _values(source: Object, keys: Array) -> Dictionary:
	var result := {}
	for key in keys:
		result[key] = source.get(key)
	return result


static func capture(board: Node) -> Dictionary:
	var result := {
		"ships": board._both_states(), "counters": _values(board, COUNTERS.slice(0, 3)),
		"drive": _values(board.ftl, DRIVE), "weather": _values(board.modifier, WEATHER),
		"weather_active": board.modifier.active, "offline_started": board.ftl.disabled_turn_started,
		"failure": board.systems_failure.remaining.duplicate(),
		"failure_skip": board.systems_failure.skip_activation_end.duplicate(),
		"used": board.progression_actions.overdrive_used, "hands": {},
		"rng": [str(board.enemy_ai.rng.state), str(board.modifier.rng.state),
			str(board.ftl.rng.state), str(board.progression_actions.rng.state)],
	}
	result.counters.merge(_values(board.progression_actions, ["charge_hull", "beam"]))
	for side in SIDES:
		var hand: Node = board.hand if side == "player" else board.enemy_hand
		result.hands[side] = {
			"cards": hand.cards.map(func(card): return "" if card == null else card.identity_key()),
			"pending": board.pending_card_draws[side].duplicate(),
			"rng": str(hand.rng.state), "last": hand.last_replaced_identity,
			"allocation": hand.allocation_mode,
		}
	return result


static func restore(board: Node, data: Dictionary) -> void:
	for key in COUNTERS.slice(0, 3): board.set(key, int(data.counters[key]))
	for key in ["charge_hull", "beam"]: board.progression_actions.set(key, int(data.counters[key]))
	board.progression_actions.overdrive_used = data.used
	for key in DRIVE: board.ftl.set(key, int(data.drive[key]))
	for key in WEATHER: board.modifier.set(key, float(data.weather[key]) if key == "ion_factor" else int(data.weather[key]))
	board.ftl.disabled_turn_started = data.offline_started
	board.modifier.active = data.weather_active
	board.enemy_ai.rng.state = int(data.rng[0])
	board.modifier.rng.state = int(data.rng[1])
	board.ftl.rng.state = int(data.rng[2])
	board.progression_actions.rng.state = int(data.rng[3])
	for side in SIDES:
		board.apply_ship_snapshot(side, data.ships[side])
		board.systems_failure.remaining[side] = int(data.failure[side])
		board.systems_failure.skip_activation_end[side] = data.failure_skip[side]
		var hand: Node = board.hand if side == "player" else board.enemy_hand
		var saved: Dictionary = data.hands[side]
		var cards := {}
		for card in hand.card_pool: cards[card.identity_key()] = card
		hand.cards.assign(saved.cards.map(func(id): return cards.get(id)))
		hand.current_round = board.turn_number
		hand.last_replaced_identity = saved.last
		hand.rng.state = int(saved.rng)
		hand.select_allocation(saved.allocation)
		board.pending_card_draws[side] = saved.pending.map(func(slot): return int(slot))


static func _number(value: Variant, minimum: int = 0, maximum: int = 1000000000) -> bool:
	return (value is int or value is float) and value == floor(value) and value >= minimum and value <= maximum


static func _numbers(value: Variant, keys: Array) -> bool:
	if not value is Dictionary: return false
	for key in keys:
		if not _number(value.get(key)): return false
	return true


static func _seed(value: Variant) -> bool:
	return value is String and value.is_valid_int()


static func valid(data: Variant) -> bool:
	if not data is Dictionary or not _numbers(data.get("counters"), COUNTERS): return false
	if data.counters.turn_number < 1 or data.counters.beam > 3: return false
	if data.counters.beam in [1, 2] and data.counters.charge_hull < 1: return false
	if not _numbers(data.get("drive"), DRIVE) or not _numbers(data.get("weather"), WEATHER): return false
	for key in ["used", "weather_active", "offline_started"]:
		if not data.get(key) is bool: return false
	if not data.get("rng") is Array or data.rng.size() != 4 or not data.rng.all(_seed): return false
	for key in ["ships", "hands", "failure", "failure_skip"]:
		if not data.get(key) is Dictionary: return false
	var identities := {}
	for card in Cards.CARDS + [SPECIAL]: identities[card.identity_key()] = true
	for side in SIDES:
		if not _numbers(data.ships.get(side), STATS): return false
		if data.ships[side].hull <= 0 or data.ships[side].hull_capacity < 1: return false
		if not _number(data.failure.get(side), -1) or not data.failure_skip.get(side) is bool: return false
		var hand: Variant = data.hands.get(side)
		if not hand is Dictionary or not _seed(hand.get("rng")) or not hand.get("last") is String: return false
		if hand.get("allocation") not in ["balanced", "offense", "defense", "systems"]: return false
		if not hand.get("cards") is Array or hand.cards.size() != 6: return false
		if not hand.get("pending") is Array or hand.pending.size() > 6: return false
		for slot in hand.pending:
			if not _number(slot, 0, 5): return false
		for id in hand.cards:
			if not id is String or (id != "" and not identities.has(id)): return false
	return true
