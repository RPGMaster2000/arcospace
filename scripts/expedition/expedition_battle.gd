extends RefCounted
## Owns the live board handle and its setup/removal, not combat results or rewards.
## The controller supplies the scene and callbacks and retains routing/lifecycle guards.
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
var current: Node


# Configure before the controller adds the board to the tree, as required by Board._ready.
func create(scene: PackedScene, state: Resource, index: int, battle_seed: int,
		finished: Callable, restarted: Callable, exited: Callable) -> Node:
	current = scene.instantiate()
	current.expedition = state
	var setup = state.prepare_battle(index)
	setup.battle_seed = battle_seed
	Adapter.configure(current, setup)
	current.expedition_continue.connect(finished.bind(current))
	current.expedition_restart.connect(restarted.bind(current))
	current.expedition_exit.connect(exited.bind(current))
	return current


func remove(parent: Node) -> void:
	var previous: Node = current
	current = null
	if is_instance_valid(previous):
		if not previous.result_recorded:
			previous.checkpoint_exit = true
		parent.remove_child(previous)
		previous.queue_free()
