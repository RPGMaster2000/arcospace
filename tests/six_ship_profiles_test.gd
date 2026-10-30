extends SceneTree
const Ships = preload("res://scripts/ships/ship_library.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Hand = preload("res://scripts/cards/card_hand.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const FIELDS = ["hull_capacity","shields","materials","energy","crew","synthesizer","reactor","quarters","ftl_turns","ftl_resistance"]
const EXPECTED = [
	[35,12,10,10,10,2,2,2,14,0.0], [28,17,14,10,8,1,3,2,11,0.35],
	[40,6,16,17,16,3,2,3,17,-0.1], [35,12,8,12,10,3,1,2,14,0.0],
	[35,12,10,8,12,2,3,1,14,0.0], [35,12,8,12,10,1,2,3,14,0.0]]
const COUNTS = [[10,10,9],[5,15,9],[13,6,10],[14,7,8],[8,15,6],[7,9,13]]
const PREMIUM = ["Deploy boarding teams","Deep-core mining","Advanced fabrication","Reinforce EMP Pulse systems","Deep atmospheric dive","Board pirate flagship","Evacuate scientists","Shielded expedition","Stabilize corridor"]
var failures: int = 0
var checks: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func settle() -> void:
	for n in range(6): await process_frame
func run() -> void:
	check(Ships.PLAYERS.size() == 6, "Six player profiles")
	var signatures: Array = []
	for index in range(Ships.PLAYERS.size()):
		var profile = Ships.PLAYERS[index]
		for field in range(FIELDS.size()):
			check(is_equal_approx(float(profile.get(FIELDS[field])), float(EXPECTED[index][field])), profile.ship_name + " " + FIELDS[field])
		var identities: Dictionary = {}
		var counts: Dictionary = {"materials":0,"energy":0,"crew":0}
		var affordable: Dictionary = counts.duplicate()
		for card in profile.starting_cards:
			check(card in Cards.CARDS and (card.tier == 1 or (Cards.CARDS.find(card) >= 68 and Cards.CARDS.find(card) < 74)) and ResourceLoader.exists(card.resource_path), "Valid original or added sabotage resource")
			check(not identities.has(card.identity_key()), "Distinct pool identities")
			if card.signature_ship >= 0: check(card == profile.signature_card and card.signature_ship == index, "Signature belongs only to this ship")
			identities[card.identity_key()] = true
			counts[card.family] += 1
			if card.cost <= profile.get(card.family): affordable[card.family] += 1
		check(identities.size() == 29 and counts.values() == COUNTS[index], "Exact 29-card family distribution")
		for count in affordable.values(): check(count >= 2, "At least two immediately affordable cards per family")
		var signature: Array = identities.keys()
		signature.sort()
		check(not signature in signatures, "Each pool differs from all other ships")
		signatures.append(signature)
		check(profile.card_family_weights.is_empty() and profile.card_effect_weights.is_empty(), "No new color draw weights")
		if index >= 3:
			check(profile.model_scene != null and profile.model_scene != Ships.PLAYERS[0].model_scene, "Independent player visual assigned")
		var hand = Hand.new()
		hand.card_pool.assign(profile.starting_cards)
		hand.configure_player_allocation(2.0)
		hand.signature_card = profile.signature_card
		for seed_value in range(100):
			hand.rng.seed = seed_value + 1
			hand.deal_player_opening()
			var opening: Dictionary = {"materials":0,"energy":0,"crew":0}
			for card in hand.cards: opening[card.family] += 1
			check(profile.signature_card in hand.cards, "Signature is guaranteed in ordinary opening")
			check(opening.values() == [2,2,2], "Seeded 2/2/2 opening")
		var snapshot: Array = hand.cards.duplicate()
		var rng_before: int = hand.rng.state
		check(hand.select_allocation("offense") and hand.cards == snapshot and hand.rng.state == rng_before, "Allocation affects future draws only")
		hand.free()
		var state = State.new()
		state.start(index, Rules, 2468)
		check(state.ship() == profile and state.hull == profile.hull_capacity, "Expedition profile selected")
		state.system_number = 29
		state.generate_system()
		for key in State.PRODUCTION: check(state.production(key) == profile.get(key), "Difficulty does not scale player production")
		for poi in Rules.pois:
			state.encounters[0] = {"kind":"poi","poi":poi,"completed":false}
			state.hull = 1
			state.salvage = 0
			state.production_upgrades.clear()
			var free_approaches: int = 0
			var safe: bool = false
			for approach in poi.approaches:
				if approach.requirement.is_empty(): free_approaches += 1
				else:
					var gate: int = 4 if approach.title in PREMIUM else 3
					check(approach.minimum_production == gate, "Authored 3/4 production threshold")
					state.hull = 1
					state.production_upgrades[approach.requirement] = gate - 1 - int(profile.get(approach.requirement))
					check(state.locked_reason(approach).begins_with("Requires"), "Gate closed one below threshold")
					state.production_upgrades[approach.requirement] += 1
					check(state.locked_reason(approach).is_empty(), "Gate opens at threshold")
					state.production_upgrades.clear()
				var worst: int = mini(approach.success.hull, approach.failure.hull) if approach.success_chance < 1 else approach.success.hull
				if state.locked_reason(approach).is_empty() and state.hull + worst > 0: safe = true
			check(free_approaches >= 1, "Every PoI has ungated approach")
			check(safe or state.can_survey(0), "One-Hull zero-Salvage player can still complete PoI")
	check(Rules.progression.DEFAULT_BOSS.resource_path == "res://ships/enemy/sentinel_dreadnought.tres", "Boss path corrected")
	for enemy in Rules.enemy_ships: check(enemy.resource_path.begins_with("res://ships/enemy/"), "Enemy resource loads from relocated path")
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	menu.initial_settings = {"player_ship":5}
	root.add_child(menu)
	await settle()
	check(menu.selected_ship == 5, "High-index selection restored")
	menu.showcase._stop_tween()
	menu.showcase._finish_intro()
	menu.showcase.logo.modulate.a = 0.0
	menu.showcase.phase = menu.showcase.Phase.SHIP_SELECTION
	menu._selection_ready()
	for dimensions in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(800,450),Vector2i(686,384)]:
		root.size = dimensions
		for index in range(6):
			menu._select(index)
			await settle()
			check(menu.get_node("Selection/Information/Margin/Scroll/Column/Identity/Name").text == Ships.PLAYERS[index].ship_name.to_upper(), "All six names displayed")
			for control in [menu.previous_ship, menu.next_ship, menu.deck_button, menu.start_button,menu.settings_button]:
				check(root.get_visible_rect().encloses(control.get_global_rect()), "Navigation stays inside viewport")
			check(not menu.previous_ship.get_global_rect().intersects(menu.deck_button.get_global_rect()) and not menu.next_ship.get_global_rect().intersects(menu.start_button.get_global_rect()), "Navigation does not overlap actions")
			menu.deck_button.pressed.emit()
			check(menu.deck_viewer.gallery.cards == Ships.PLAYERS[index].starting_cards, "Deck follows all six ships")
			menu.deck_viewer.dismiss()
	menu._select(-1)
	check(menu.selected_ship == 0 and menu.previous_ship.disabled, "Low boundary")
	menu._select(999)
	check(menu.selected_ship == 5 and menu.next_ship.disabled, "High boundary")
	menu.free()
	print("Six ship profiles: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
