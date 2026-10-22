extends SceneTree
const State = preload("res://scripts/combat/ship_combat_state.gd")
const Board = preload("res://scripts/board.gd")

func _initialize() -> void:
	var ship = State.new()
	var snapshot: Dictionary = ship.snapshot()
	snapshot.hull = 1
	assert(ship.hull == 30)
	var copy = ship.copy()
	copy.energy = 0
	assert(ship.energy == 16)
	var board = Board.new()
	board.player_hull = 47
	board.enemy_reactor = 0
	assert(board.ship_snapshot("player").hull == 47)
	assert(board.ship_snapshot("enemy").reactor == 0)
	var values: Dictionary = board.ship_snapshot("player")
	values.materials = 91
	values.systems_failure_remaining = 0
	board.apply_ship_snapshot("player", values)
	assert(board.player_materials == 91)
	assert(not board.ship_snapshot("player").has("systems_failure_remaining"))
	board.free()
	print("Combat state ownership checks passed")
	quit()
