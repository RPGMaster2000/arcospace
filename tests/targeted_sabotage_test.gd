extends SceneTree
# Specification-level coverage for the six targeted sabotage identities.
const Library = preload("res://scripts/cards/card_library.gd")
const Effects = preload("res://scripts/cards/card_effects.gd")
const Ships = preload("res://scripts/ships/ship_library.gd")
const Hand = preload("res://scripts/cards/card_hand.gd")
const AI = preload("res://scripts/enemy_ai.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Failure = preload("res://scripts/combat/systems_failure.gd")
const DISTRIBUTION = [
	[68, 70, 72], [68, 71, 73], [69, 70, 72], [69, 71, 72], [68, 71, 73], [69, 70, 73]
]
const NAMES = [
	"Industrial Interference",
	"Fabrication Strike",
	"Reactor Interference",
	"Core Destabilization",
	"Personnel Disruption",
	"Command Infiltration"
]
const SYSTEMS = ["synthesizer", "synthesizer", "reactor", "reactor", "quarters", "quarters"]
const FAMILIES = ["materials", "materials", "energy", "energy", "crew", "crew"]
var checks: int = 0
var failures: int = 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func snapshot() -> Dictionary:
	return {
		"hull": 40,
		"hull_capacity": 40,
		"shields": 2,
		"materials": 50,
		"energy": 50,
		"crew": 50,
		"synthesizer": 3,
		"reactor": 3,
		"quarters": 3
	}


func run() -> void:
	check(Library.CARDS.size() == 74, "74 registered identities")
	var occurrences: Dictionary = {}
	for index in range(6):
		var base: Resource = Library.CARDS[68 + index]
		var tier: int = 1 + index % 2
		check(
			base.card_name == NAMES[index] and base.family == FAMILIES[index],
			"Name and resource family"
		)
		check(
			(
				base.cost == (9 if tier == 1 else 17)
				and base.tier == tier
				and base.allocation_category == "offense"
			),
			"Cost, rarity and Offense"
		)
		check(
			base.upgrade_effects.size() == 2 and not base.play_again,
			"Two upgrades; normal turn consumption"
		)
		occurrences[base.identity_key()] = 0
		for level in range(3):
			var card: Resource = base.with_upgrade(level)
			check(
				(
					card.identity_key() == base.identity_key()
					and card.cost == base.cost
					and card.tier == tier
				),
				"Stable upgraded identity and cost"
			)
			check(
				card.effects.enemy_production == {SYSTEMS[index]: -tier},
				"Fixed targeted reduction at every level"
			)
			check(
				card.description.to_lower().contains(SYSTEMS[index]), "Inspection names the target"
			)
			for production in [0, 1, 2, 4]:
				for reserve in [0, 2, 50]:
					var actor: Dictionary = snapshot()
					var enemy: Dictionary = snapshot()
					enemy[SYSTEMS[index]] = production
					enemy.energy = reserve
					enemy.crew = reserve
					var expected_actor: Dictionary = actor.duplicate(true)
					var expected_enemy: Dictionary = enemy.duplicate(true)
					expected_actor[base.family] -= base.cost
					expected_enemy[SYSTEMS[index]] = maxi(0, production - tier)
					if tier == 1:
						expected_actor[base.family] += level * 3
					elif index == 1:
						expected_enemy.shields = 0
						expected_enemy.hull -= 1 + 2 * level
					elif index == 3:
						expected_enemy.energy = maxi(0, reserve - (4 + 2 * level))
					elif index == 5:
						expected_enemy.crew = maxi(0, reserve - (4 + 2 * level))
						expected_actor.crew += mini(reserve, 4 + 2 * level)
					if tier == 2 and level == 2:
						expected_actor.shields += 3
					var original: Dictionary = card.effects.duplicate(true)
					check(Effects.play(card, actor, enemy), "Playable authored level")
					check(
						actor == expected_actor and enemy == expected_enemy,
						"Exact outcome, no unrelated system changes: " + card.card_name
					)
					check(card.effects == original, "Shared resource remains immutable")
					var failure = Failure.new()
					failure.sync({"player": actor, "enemy": enemy}, "player", 3)
					check(
						failure.remaining.enemy == -1,
						"One targeted shutdown alone does not activate Systems Failure"
					)
			var hand = Hand.new()
			hand.configure_player_allocation(2.0)
			hand.select_allocation("offense")
			check(hand._draw_weight(card) == 2.0, "Offense doubles new card weight")
			hand.identity_weights[card.identity_key()] = 3.0
			check(hand._draw_weight(card) == 6.0, "Acquired and allocation weights compose")
			hand.select_allocation("systems")
			check(
				hand._draw_weight(card) == 3.0, "Systems allocation does not misclassify sabotage"
			)
			for round_number in [1, 2, 3]:
				hand.current_round = round_number
				check(
					hand._eligible(card, -1) == (tier == 1 or round_number == 3),
					"Tier 2 unlock remains round 3"
				)
			hand.cards.assign([card, card])
			check(not hand._eligible(card, -1), "Duplicate / Tier 2 hand cap preserved")
			if tier == 2:
				hand.cards.assign([Library.CARDS[69 if index != 1 else 71]])
				check(
					not hand._eligible(card, -1), "Different Tier 2 identity also blocks a second"
				)
			hand.free()
			var ai = AI.new()
			ai.tactical_variation = 0
			var actor: Dictionary = snapshot()
			var enemy: Dictionary = snapshot()
			enemy[SYSTEMS[index]] = tier
			enemy["reactor" if SYSTEMS[index] != "reactor" else "quarters"] = 0
			var before: Dictionary = enemy.duplicate(true)
			check(
				ai.choose([Library.CARDS[0], card], actor, enemy).slot == 1,
				"AI values triggering Systems Failure"
			)
			check(enemy == before and actor == snapshot(), "AI previews do not mutate state")
			actor[card.family] = 0
			check(ai.choose([card], actor, enemy).discard, "AI obeys cost")
			ai.free()
	for ship_index in range(6):
		var pool: Array = Ships.PLAYERS[ship_index].starting_cards
		check(pool.size() == 28, "28 starting identities")
		var found: Array = []
		var families: Dictionary = {}
		var identities: Dictionary = {}
		for slot in range(pool.size()):
			var card: Resource = pool[slot]
			check(not identities.has(card.identity_key()), "Unique starting identity")
			identities[card.identity_key()] = true
			if slot < 25:
				check(
					Library.CARDS.find(card) < 44 and card.tier == 1,
					"Original 25 identities remain first"
				)
			if Library.CARDS.find(card) >= 68:
				found.append(Library.CARDS.find(card))
				families[card.family] = true
				occurrences[card.identity_key()] += 1
		check(
			found == DISTRIBUTION[ship_index] and families.size() == 3,
			"Exact requested distribution, one per family"
		)
		var hand = Hand.new()
		hand.card_pool.assign(pool)
		for seed_value in range(100):
			hand.rng.seed = seed_value
			hand.deal_player_opening()
			var count: Dictionary = {"materials": 0, "energy": 0, "crew": 0}
			for card in hand.cards:
				count[card.family] += 1
				check(card.tier == 1, "Opening excludes Tier 2")
			check(
				count.values() == [2, 2, 2] and hand.cards.size() == 6,
				"Six-card 2/2/2 opening unchanged"
			)
		hand.free()
		var run_state = State.new()
		run_state.start(ship_index, Rules, 8123)
		check(
			(
				run_state.deck_limit() == 36
				and run_state.deck_limit() - run_state.player_pool().size() == 8
			),
			"Eight acquisition slots"
		)
		# Each identity is either owned or available for acquisition; both paths support two upgrades.
		for card in Library.CARDS.slice(68):
			if card not in pool:
				check(
					card in run_state.available_reward_cards(),
					"New unowned card available as reward"
				)
				run_state.pending_choice = "card"
				run_state.card_offers.assign([card])
				check(run_state.choose_card(0), "New card acquisition")
			for level in [1, 2]:
				run_state.start_upgrade_event(1)
				check(run_state.choose_upgrade(card.identity_key()), "New owned card upgrades")
				var found_level: int = -1
				for owned in run_state.player_pool():
					if owned.identity_key() == card.identity_key():
						found_level = owned.upgrade_level
				check(found_level == level, "Upgraded definition reaches owned pool")
	for count in occurrences.values():
		check(count == 3, "Each new identity appears in three ships")
	await test_presentation()
	print("Targeted sabotage: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func settle() -> void:
	for frame in range(5):
		await process_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	root.get_texture().get_image().save_png("res://.godot/testlogs/sabotage-" + label + ".png")


func test_presentation() -> void:
	var gallery = preload("res://scripts/ui/card_gallery.gd").new()
	root.add_child(gallery)
	var inspector = preload("res://scripts/ui/card_inspector.gd").new()
	root.add_child(inspector)
	gallery.set_cards(Library.CARDS.slice(68))
	for dimensions in [Vector2i(1280, 720), Vector2i(1560, 720), Vector2i(1680, 720)]:
		root.size = dimensions
		gallery.position = Vector2(24, 24)
		gallery.size = Vector2(dimensions) - Vector2(48, 48)
		gallery.set_category("Production")
		await settle()
		check(gallery.visible_cards.size() == 6, "All targeted cards appear in Production gallery")
		check(
			root.get_visible_rect().encloses(gallery.get_global_rect()),
			"Gallery fits landscape viewport"
		)
		await capture("gallery-%d" % dimensions.x)
		for base in Library.CARDS.slice(68):
			for level in [1, 2]:
				inspector.present(base.with_upgrade(level - 1), base.with_upgrade(level))
				await settle()
				check(
					inspector.comparison_text.text.to_lower().contains(
						SYSTEMS[Library.CARDS.find(base) - 68]
					),
					"Upgrade comparison names targeted system"
				)
				for control in [inspector.cancel_button, inspector.confirm_button]:
					check(
						root.get_visible_rect().encloses(control.get_global_rect()),
						"Inspection actions stay visible"
					)
				for portrait in inspector.portraits:
					check(
						root.get_visible_rect().encloses(portrait.get_global_rect()),
						"New card portrait fits viewport"
					)
				if base == Library.CARDS[73] and level == 2:
					await capture("upgrade-%d" % dimensions.x)
				inspector.dismiss()
	inspector.free()
	gallery.free()
	await process_frame
