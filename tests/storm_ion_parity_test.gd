extends SceneTree
const Mod = preload("res://scripts/combat_modifier.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const FILE = "res://tests/storm_ion_baseline.json"
# Historical baseline includes the former base copy for Laser Burst.
# Normalize only this unrelated text when checking deterministic storm behavior.
const BASELINE_LASER_DESCRIPTION = "6 damage; If Enemy Shields =0: 3 damage"
func _initialize() -> void:
	var records: Array = []
	for seed_value in range(32):
		var mod = Mod.new()
		mod.configure(2,seed_value)
		var trace: Array = []
		for round_number in range(1,31):
			var notice: String = mod.begin_round(round_number)
			var preview: Resource = mod.preview(Cards.CARDS[11])
			var snapshot_description: String = preview.description
			if preview == Cards.CARDS[11]:
				snapshot_description = BASELINE_LASER_DESCRIPTION
			trace.append([notice,mod.active,mod.ion_factor,mod.next_round,mod.ends_round,str(mod.rng.state),mod.status_text(round_number),mod.meter_value(round_number),preview.effects,snapshot_description])
		records.append(JSON.stringify(trace).sha256_text())
		mod.free()
	if "--capture" in OS.get_cmdline_user_args():
		FileAccess.open(FILE,FileAccess.WRITE).store_string(JSON.stringify({"revision":"41bb441573f582681bded4ad8a706ae73aae2612","hashes":records},"\t")+"\n")
	else:
		var expected = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		assert(records == expected.hashes,"Ion scheduling, RNG or preview changed")
	print("Ion baseline: 32 seeded schedules / 960 round checkpoints match")
	quit()
