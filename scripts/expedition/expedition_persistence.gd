extends RefCounted
## Coordinates the single active run's saves. Owns only the store and battle checkpoint,
## never a second live gameplay state. The existing codec owns format and disk recovery.
const Save = preload("res://scripts/persistence/expedition_save.gd")
var store = Save.new()
var enabled: bool = true
var battle_checkpoint: Dictionary = {}
var battle_marker: Dictionary = {}


func reset_battle() -> void:
	battle_checkpoint = {}
	battle_marker = {}


func save_candidate(candidate: Resource) -> bool:
	return not enabled or store.save_run(candidate)


# The controller checkpoints navigation first, even when persistence is disabled.
func save_progress(state: Resource, battle: Node) -> bool:
	if not enabled: return true
	if state == null: return false
	if state.run_ended or state.hull <= 0:
		return store.clear_run()
	if is_instance_valid(battle) and not battle.result_recorded:
		return store.save_data(battle_checkpoint, battle_marker)
	return store.save_run(state)


# Encode and select the seed before setup consumes bonuses. Failed writes retain the
# previous checkpoint, while returning the attempted seed for the existing retry UI.
func checkpoint_battle(state: Resource, index: int, battle_seed: int) -> Dictionary:
	var checkpoint: Dictionary = Save.encode(state)
	if battle_seed < 0:
		var generator := RandomNumberGenerator.new()
		generator.randomize()
		battle_seed = generator.randi()
	var marker: Dictionary = {"index": index, "seed": str(battle_seed)}
	if enabled and not store.save_data(checkpoint, marker):
		return {"saved": false, "seed": battle_seed}
	battle_checkpoint = checkpoint
	battle_marker = marker
	return {"saved": true, "seed": battle_seed}
