extends SceneTree
const Mod = preload("res://scripts/combat_modifier.gd")

func _initialize() -> void:
	var checks := 0
	for kind in [2, 6, 7]:
		for seed_value in range(32):
			var mod := Mod.new()
			mod.configure(kind, seed_value)
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var next := 1 + rng.randi_range(3, 6)
			var end := 0
			for round_number in range(1, 61):
				if round_number == end: next = round_number + rng.randi_range(3, 6)
				if round_number == next:
					rng.randf()
					end = round_number + 3
				mod.begin_round(round_number)
				assert(mod.next_round == next and mod.rng.state == rng.state)
				assert(mod.ion_factor == (2.0 if round_number < end else 1.0))
				checks += 1
			mod.free()
	print("Storm amplification: %d checks, 0 failures" % checks)
	quit()
