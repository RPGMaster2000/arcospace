extends SceneTree
## Export comparable gameplay/save data for the base and feature revisions.
## Only environmental records and deliberately adjusted cosmetic battle anchors
## are excluded. Everything else, including all persisted RNG states, is compared.
func _initialize() -> void:
	var records := []
	for mode in ["defense","exploration"]:
		for seed_value in range(1,21):
			var rules: Resource = preload("res://encounters/expedition_rules.tres").duplicate(true)
			rules.game_mode = mode
			rules.log_rolls = false
			var state = preload("res://scripts/expedition_state.gd").new()
			state.start(0,rules,seed_value)
			var data: Dictionary = preload("res://scripts/persistence/expedition_save.gd").encode(state)
			data.erase("environmental_instances")
			data.erase("encounter_positions")
			records.append(data)
	var file := FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	file.store_string(JSON.stringify(records))
	file.close()
	print("Exported 40 generation signatures")
	quit()
