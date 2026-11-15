extends SceneTree
## Copy unchanged to the baseline checkout. Output excludes only intended ship identities.
func _initialize() -> void:
	if OS.get_cmdline_user_args().size() != 1:
		push_error("Supply one output JSON path after --")
		quit(1)
		return
	var State = load("res://scripts/expedition_state.gd")
	var Save = load("res://scripts/persistence/expedition_save.gd")
	var records: Array = []
	for seed_value in range(1,21):
		var state = State.new()
		var rules = load("res://encounters/expedition_rules.tres").duplicate(true)
		rules.game_mode = "defense"
		rules.log_rolls = false
		state.start(0,rules,seed_value)
		for system in range(1,7):
			var data = Save.encode(state)
			for entry in data.encounters:
				if entry.kind == "battle":
					entry.erase("enemy_id")
					entry.erase("title")
			records.append(JSON.stringify(data).sha256_text())
			if system < 6:
				state.defense.complete = true
				state.generate_system()
	var output = FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE)
	output.store_string(JSON.stringify(records))
	quit()
