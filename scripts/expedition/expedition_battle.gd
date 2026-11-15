extends RefCounted
## Owns the live board handle and its setup/removal, not combat results or rewards.
## The controller supplies the scene and callbacks and retains routing/lifecycle guards.
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
var current: Node
var returning: Node
var return_in_progress := false
var _viewport_mode := 4


# Configure before the controller adds the board to the tree, as required by Board._ready.
func create(scene: PackedScene, state: Resource, index: int, battle_seed: int,
		finished: Callable, restarted: Callable, exited: Callable, environment: Dictionary = {}) -> Node:
	current = scene.instantiate()
	current.expedition = state
	var setup = state.prepare_battle(index, null, environment)
	setup.battle_seed = battle_seed
	Adapter.configure(current, setup)
	current.expedition_continue.connect(finished.bind(current))
	current.expedition_restart.connect(restarted.bind(current))
	current.expedition_exit.connect(exited.bind(current))
	return current


func remove(parent: Node) -> void:
	var previous: Node = current if is_instance_valid(current) else null
	current = null
	if is_instance_valid(previous):
		if not previous.result_recorded:
			previous.checkpoint_exit = true
		parent.remove_child(previous)
		previous.queue_free()

# Retain the original board through required reward/upgrade UI, with its viewport off.
# This is an ephemeral presentation handle, not another battle or state snapshot.
func retain_return() -> void:
	returning = current
	current = null
	returning.hide()
	returning.process_mode = Node.PROCESS_MODE_DISABLED
	var viewport: SubViewport = returning.get_node("BattleView/Viewport")
	_viewport_mode = viewport.render_target_update_mode
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var sync := Callable(returning,"_sync_expedition_hand")
	if returning.expedition.deck_changed.is_connected(sync): returning.expedition.deck_changed.disconnect(sync)

func reveal_return() -> Node:
	returning.process_mode = Node.PROCESS_MODE_INHERIT
	returning.get_node("BattleView/Viewport").render_target_update_mode = _viewport_mode
	returning.show()
	return returning

func release_return(parent: Node) -> void:
	var previous: Node = returning if is_instance_valid(returning) else null
	returning = null
	return_in_progress = false
	if is_instance_valid(previous):
		if previous.get_parent() == parent: parent.remove_child(previous)
		previous.queue_free()
