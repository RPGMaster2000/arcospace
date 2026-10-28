extends RefCounted
# Scene-side transfer only. ExpeditionState never receives Board or hand nodes.
const Setup = preload("res://scripts/combat/battle_setup.gd")
const Result = preload("res://scripts/combat/battle_result.gd")

static func configure(board: Node, setup: Setup) -> void:
	board.battle_setup = setup
	board.expedition_encounter = setup.encounter_index
	board.setup_settings = {"player_ship": setup.player_ship, "enemy_ship": setup.enemy_ship,
		"player_data": setup.player_profile, "enemy_data": setup.enemy_profile, "modifier": setup.modifier}


static func apply_setup(board: Node, setup: Setup) -> void:
	if board.get_meta("battle_setup_id", 0) == setup.get_instance_id():
		return
	board.set_meta("battle_setup_id", setup.get_instance_id())
	board.apply_ship_snapshot("player", setup.player_state.snapshot())
	if setup.enemy_state != null:
		board.apply_ship_snapshot("enemy", setup.enemy_state.snapshot())
	board.salvage = setup.salvage
	board.battles_won = setup.battles_won
	board.ftl.charge_target += setup.emp_requirement_bonus
	board.ftl.charge = clampi(setup.emp_charge, 0, board.ftl.charge_target)
	board.ftl.disabled_turns = setup.emp_offline
	if setup.chasedown_charge_cap:
		board.ftl.charge = mini(board.ftl.charge, maxi(0, board.ftl.charge_target - 2))
	board.hand.card_pool.assign(setup.player_cards)
	board.hand.identity_weights = setup.identity_weights.duplicate()
	board.enemy_hand.card_pool.assign(setup.enemy_cards)


static func result(board: Node) -> Result:
	var data = Result.new()
	data.result_id = board.get_instance_id()
	data.encounter_index = board.expedition_encounter
	data.system_number = board.battle_setup.system_number if board.battle_setup != null else 0
	data.winner = board.winner
	data.result_cause = "emp_escape" if board.escaped_by_ftl else board.result_cause
	data.escaped_by_ftl = board.escaped_by_ftl
	data.player_hull = board.player_hull
	data.salvage = board.salvage
	data.battles_won = board.battles_won
	data.earned_tactical = board.earned_tactical
	data.earned_strategic = board.earned_strategic
	data.tactical_resources = board.TACTICAL_RESOURCES
	data.strategic_shields = board.STRATEGIC_SHIELDS
	return data


static func sync_hand(hand: Node, pool: Array[Resource], weights: Dictionary, upgrades: Dictionary) -> void:
	hand.card_pool.assign(pool)
	hand.identity_weights = weights.duplicate()
	hand.apply_upgrades(upgrades)
	var owned: Dictionary = {}
	for card in pool:
		owned[card.identity_key()] = true
	for index in range(hand.cards.size()):
		var card: Resource = hand.cards[index]
		if card != null and not owned.has(card.identity_key()):
			hand.replace_card(index)
