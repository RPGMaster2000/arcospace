extends SceneTree
## Run this unchanged in both checkouts; compare JSON outputs, not a golden fixture.


func _initialize():
	if OS.get_cmdline_user_args().size() != 1:
		push_error("Usage: --script tools/faction_generation_signature.gd -- output.json")
		quit(1)
		return
	var State = load("res://scripts/expedition_state.gd")
	var Save = load("res://scripts/persistence/expedition_save.gd")
	var output: Array = []
	for seed_value in range(1, 21):
		var s = State.new()
		var rules = load("res://encounters/expedition_rules.tres").duplicate(true)
		rules.game_mode = "defense"
		rules.log_rolls = false
		s.start(0, rules, seed_value)
		for system in range(1, 7):
			var data = Save.encode(s)
			data.erase("faction_id")
			for entry in data.encounters:
				if entry.kind == "battle":
					entry.erase("enemy_id")
					entry.erase("title")
			output.append(JSON.stringify(data).sha256_text())
			if system < 6:
				s.defense.complete = true
				s.generate_system()
	var f = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	f.store_string(JSON.stringify(output))
	quit()
