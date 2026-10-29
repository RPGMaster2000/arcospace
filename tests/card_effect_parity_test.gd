extends SceneTree
# Captured from 30a7a9bdc308 before contract changes. Never refresh to hide a mismatch.
const Cards = preload("res://scripts/cards/card_library.gd")
const Execution = preload("res://scripts/combat/combat_execution.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Modifier = preload("res://scripts/combat_modifier.gd")
const Targets = preload("res://scripts/cards/card_targets.gd")
const Text = preload("res://scripts/ui/card_effect_text.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const Ship = preload("res://scripts/combat/ship_combat_state.gd")
const FIXTURE = "res://tests/card_effect_baseline.json"

# The frozen fixture predates VFX provenance. Preserve every existing report field;
# combat_beam_test separately checks the new presentation-only metadata.
func baseline_report(report: Dictionary) -> Dictionary:
	var result := report.duplicate(true)
	result.erase("direct_damage")
	return result

func _initialize() -> void:
	var hashes: Array = []
	for base in Cards.CARDS:
		for level in range(base.max_upgrades + 1):
			var card: Resource = base if level == 0 else base.with_upgrade(level)
			for seed_value in [7, 43]:
				for mode in range(5):
					var actor: Dictionary = Ship.new().snapshot()
					for resource in Ship.RESOURCES: actor[resource] = 40
					actor.hull = 17 if seed_value == 7 else 29
					actor.shields = 5 if seed_value == 7 else 0
					var enemy: Dictionary = Ship.new().snapshot()
					enemy.hull = 24 if seed_value == 7 else 7
					enemy.shields = 12 if seed_value == 7 else 3
					enemy.reactor = 0
					var before: Array = [actor.duplicate(true), enemy.duplicate(true), card.effects.duplicate(true)]
					var modifier = Modifier.new()
					modifier.configure([0, 2, 2, 3, 4][mode], seed_value)
					modifier.active = true
					modifier.ion_factor = 0.5 if mode == 1 else 2.0
					var random_state: int = Effects.combat_rng.state
					var preview: Dictionary = Targets.analyze(modifier.preview(card), {"player":actor,"enemy":enemy,"shields_disabled":mode == 3,"nebula_miss_rate":30 if mode == 4 else 0})
					var simulated: Dictionary = actor.duplicate(true)
					var simulated_enemy: Dictionary = enemy.duplicate(true)
					Effects.play(card, simulated, simulated_enemy, null, true)
					var ai = AI.new()
					ai.rng.seed = seed_value
					var choice: Dictionary = ai.choose([card], actor, enemy)
					assert(before == [actor, enemy, card.effects], "Analysis mutated live inputs")
					assert(random_state == Effects.combat_rng.state, "Analysis consumed combat RNG")
					var direct_actor: Dictionary = actor.duplicate(true)
					var direct_enemy: Dictionary = enemy.duplicate(true)
					var generator = RandomNumberGenerator.new()
					generator.seed = seed_value
					var resolved = Execution.resolve(card, false, direct_actor, direct_enemy, null, generator)
					assert(resolved != null, "Every fixture can afford its card")
					var notice: String = modifier.play(card, actor, enemy)
					var record: Array = [actor,enemy,baseline_report(modifier.last_hull_damage),modifier.rng.state,notice,simulated,simulated_enemy,preview,choice,ai.rng.state,card.describe_effects(card.effects),Text.comparison(card,base),card.play_again,direct_actor,direct_enemy,baseline_report(resolved.hull_damage),resolved.extra_action,generator.state]
					hashes.append(JSON.stringify(record).sha256_text())
					modifier.free()
					ai.free()
	if "--write-baseline" in OS.get_cmdline_user_args():
		var file = FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify({"revision":"30a7a9bdc308f9919316d8c3c6e3e1c53f23d7d5","hashes":hashes},"\t") + "\n")
	else:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
		assert(hashes.size() == expected.hashes.size(), "Parity fixture size")
		for index in range(hashes.size()):
			assert(hashes[index] == expected.hashes[index], "Card effect parity mismatch at %d" % index)
	print("Card effect parity: %d exact baseline checkpoints; live state and RNG unchanged by analysis" % hashes.size())
	quit()
