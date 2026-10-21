extends RefCounted
# RESPONSIBILITY: One deterministic production-failure countdown per ship.
# Production remains in Board; this coordinator never repairs it or advances combat.
const Rules = preload("res://scripts/match_rules.gd")
var remaining: Dictionary = {"player": -1, "enemy": -1}
var skip_activation_end: Dictionary = {"player": false, "enemy": false}


func sync(states: Dictionary, acting_side: String, duration: int) -> PackedStringArray:
	var notices: PackedStringArray = []
	for side in ["player", "enemy"]:
		var offline: Array[String] = Rules.offline_systems(states[side])
		if offline.is_empty():
			if remaining[side] >= 0:
				notices.append(("YOUR" if side == "player" else "ENEMY") + " SYSTEMS RECOVERED")
			remaining[side] = -1
			skip_activation_end[side] = false
		elif remaining[side] < 0:
			remaining[side] = maxi(1, duration)
			# A reduction during this ship's own turn does not consume that activation turn.
			skip_activation_end[side] = side == acting_side
			notices.append(("YOUR" if side == "player" else "ENEMY") + " SYSTEMS FAILURE")
	return notices


func end_turn(side: String) -> void:
	if remaining[side] <= 0:
		return
	if skip_activation_end[side]:
		skip_activation_end[side] = false
	else:
		remaining[side] -= 1


func snapshot(states: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for side in ["player", "enemy"]:
		result[side] = {
			"remaining": remaining[side], "offline": Rules.offline_systems(states[side])
		}
	return result
