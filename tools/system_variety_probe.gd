extends SceneTree
## Optional before/after audit: run this absolute script against either checkout.
## VARIETY_PROBE_OUTPUT selects the JSON output; -- disabled tests the legacy preset.
## No baseline fixtures are created or updated in the repository.
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")


func _initialize():
	var records = []
	var disabled = OS.get_cmdline_user_args().has("disabled")
	for seed_value in range(1, 101):
		var rules = Rules.duplicate(true)
		rules.log_rolls = false
		if disabled and "system_variety" in rules:
			rules.system_variety.enabled = false
		var state = State.new()
		state.start(0, rules, seed_value)
		for i in 6:
			var data = Save.encode(state)
			records.append(data)
			if i < 5:
				state.defense.complete = true
				state.generate_system()
	var output = OS.get_environment("VARIETY_PROBE_OUTPUT")
	if output.is_empty():
		push_error("Set VARIETY_PROBE_OUTPUT to a writable audit JSON path")
		quit(1)
		return
	var file = FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write audit output")
		quit(1)
		return
	file.store_string(JSON.stringify(records))
	quit()
