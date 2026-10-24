extends SceneTree
const AI = preload("res://scripts/enemy_ai.gd")
const Cases = preload("res://tests/ai_forecast_cases.gd")
const FIXTURE = "res://tests/ai_forecast_baseline.json"
func _initialize() -> void:
	var records: Array = []
	for item in Cases.cases():
		var ai = AI.new()
		ai.rng.seed = item.seed
		ai.tactical_weights = item.weights
		var move: Dictionary = ai.choose(item.cards,item.actor,item.enemy)
		records.append({"id":item.id,"inputs":Cases.fingerprint(item),"move":move,"rng":str(ai.rng.state)})
		ai.free()
	if "--capture-baseline" in OS.get_cmdline_user_args():
		FileAccess.open(FIXTURE,FileAccess.WRITE).store_string(JSON.stringify({"revision":"9ec97c6f3d8aca31422839830eb4e5577f358c29","records":records},"\t")+"\n")
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		assert(records.size() == expected.records.size(),"Baseline size")
		for index in range(records.size()):
			var row: Dictionary = expected.records[index]
			# JSON numbers load as float; decision slots are native ints. Fixture values stay unchanged.
			row.move.slot = int(row.move.slot)
			assert(records[index] == row,"Legacy AI decision/input/RNG changed: " + row.id)
	print("AI forecast compatibility: %d baseline decisions and RNG states match" % records.size())
	quit()
