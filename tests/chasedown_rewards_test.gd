extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Ships = preload("res://scripts/ship_library.gd")
var failures: int = 0
var checks: int = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		if failures < 25: push_error(message)
func _initialize() -> void: call_deferred("run")
func fresh() -> Resource:
	var state = State.new()
	var config = Rules.duplicate(true)
	config.progression = Rules.progression.duplicate()
	config.log_rolls = false
	state.start(0, config, 1042)
	# Two fixed ordinary PoIs, not completed by an interception.
	for index in range(2): state.encounters[index] = {"kind":"poi","poi":Rules.pois[index],"title":Rules.pois[index].title,"completed":false,"charge_awarded":false}
	return state
func board_for(state: Resource, index: int) -> Node:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.expedition = state
	board.expedition_encounter = index
	board.setup_settings = {"player_ship":state.player_ship,"enemy_ship":0,"enemy_data":state.enemy_profile(state.encounters[index]),"modifier":0}
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
	board.get_node("CardMotion").settings.enabled = false
	board.get_node("ModifierDisplay").cinematic_enabled = false
	root.add_child(board)
	return board
func run() -> void:
	var state = fresh()
	check(is_equal_approx(state.rules.chasedown_chance, 0.05) and state.rules.chasedown_limit == 1, "Shipping probability and limit")
	check(not state.try_chasedown(1,0), "No interception on initial system entry")
	state.arrive_destination(state.SERVICE_INDEX)
	check(not state.try_chasedown(1,0), "No interception leaving a service station")
	state.encounters[2] = {"kind":"battle","enemy":0,"completed":false}
	state.arrive_destination(2)
	check(not state.try_chasedown(1,0), "No interception leaving a battle")
	state.arrive_destination(0)
	state.active_battle = 2
	check(not state.try_chasedown(1,0), "Cannot intercept during combat")
	state.active_battle = -1
	state.rules.chasedown_limit = 0
	check(not state.try_chasedown(1,0), "Zero limit disables interceptions")
	state.rules.chasedown_limit = 1
	var rng_before: int = state.chasedown_rng.state
	for invalid in [-4,-2,0,99]: check(not state.try_chasedown(invalid,0), "Invalid/same destination rejected")
	state.encounters[1].completed = true
	check(not state.try_chasedown(1,0), "Completed destination rejected")
	state.encounters[1].completed = false
	state.pending_choice = "card"
	check(not state.try_chasedown(1,0), "Menus/reward selection cannot trigger")
	state.pending_choice = ""
	check(state.chasedown_rng.state == rng_before, "Invalid transitions consume no interception RNG")
	state.rules.chasedown_chance = 0
	check(not state.try_chasedown(1,0), "Zero probability never triggers")
	state.rules.chasedown_chance = 0.05
	check(not state.try_chasedown(1,0.05) and state.try_chasedown(1,0.049), "Exact chance boundary")
	check(state.pending_destination == 1 and state.encounters.size() == 7 and not state.encounters[1].completed and state.ftl_charge == 0, "Destination untouched and no immediate charge")
	check(state.encounter_charge(state.chasedown_index) == 1 and state.enemy_profile(state.encounters[state.chasedown_index]).enemy_rank == 0, "Ordinary enemy and one-unit FTL reward")
	check(not state.can_jump() and not state.can_visit(0) and not state.try_chasedown(1,0), "Pending interception cannot be bypassed or rerolled")
	check(not state.can_visit(state.chasedown_index), "Cannot start before choosing response")
	check(state.choose_chasedown_response(3) and not state.choose_chasedown_response(2), "Response commits once")
	var required: int = state.required_ftl_charge
	var board = board_for(state,state.chasedown_index)
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	var charge: int = state.ftl_charge
	var salvage: int = state.salvage
	var remaining: int = state.upgrades_remaining
	board.salvage += 999
	state.record_battle(board)
	board.salvage = salvage
	board.refresh_display()
	check(charge == 1 and state.ftl_charge == charge and state.salvage == salvage and state.upgrades_remaining == remaining and remaining == 1, "Exactly one charge and one upgrade reward, duplicate result rejected")
	check(state.required_ftl_charge == required and not state.encounters[1].completed and state.pending_destination == 1, "Requirement/destination intact")
	state.active_battle = -1
	state.finish_upgrades()
	state.arrive_destination(1)
	check(state.pending_destination == -1 and not state.try_chasedown(0,0), "Resumed arrival clears destination; once-per-system cap")
	board.queue_free()
	await process_frame
	# Every response uses the ordinary begin_battle path; modifiers consume only once.
	for response in range(4):
		state = fresh()
		state.arrive_destination(0)
		check(state.try_chasedown(1,0), "Forced interception")
		if response == 2: state.hull = 1
		check(state.choose_chasedown_response(response), "Response selected")
		var profile = state.ship()
		board = board_for(state,state.chasedown_index)
		if response == 0:
			check(board.player_shields == profile.shields+4 and board.player_energy == profile.energy-3+profile.reactor, "Red Alert bonuses/penalty")
		elif response == 1:
			check(board.player_shields == maxi(0,profile.shields-4) and board.ftl.charge == 4 and not board.ftl.can_warp(), "Evasive +3 plus first tick; no instant escape")
		elif response == 2:
			check(board.player_hull == 1 and board.player_energy == profile.energy+5+profile.reactor, "Overcharge Hull minimum")
		else: check(board.player_shields == profile.shields and board.player_energy == profile.energy+profile.reactor, "Hold Course unchanged")
		check(state.pending_bonuses.is_empty() and state.pending_penalties.is_empty(), "Temporary modifiers consumed")
		board.ftl.charge = board.ftl.charge_target
		board._warp_out()
		check(state.ftl_charge == 1 and state.upgrades_remaining == 0 and state.pending_choice.is_empty() and state.salvage == 0, "Escape resolves once without upgrades or Salvage")
		state.record_battle(board)
		check(state.ftl_charge == 1, "Escape duplicate guard")
		board.queue_free()
		await process_frame
	# Extreme Inspector charge tuning cannot make Evasive an automatic escape.
	state = fresh()
	state.rules.chasedown_responses = state.rules.chasedown_responses.duplicate(true)
	state.rules.chasedown_responses[1].modifiers.emp_pulse_charge = 999
	state.arrive_destination(0)
	state.try_chasedown(1,0)
	state.choose_chasedown_response(1)
	board = board_for(state,state.chasedown_index)
	check(board.ftl.charge == board.ftl.charge_target-1 and not board.ftl.can_warp(), "Extreme bonus capped below ready")
	board.queue_free()
	await process_frame
	# Rank rewards, uniqueness per event, and later-event eligibility.
	for rank in range(3):
		state = fresh()
		var enemy: Resource
		for candidate in Rules.enemy_ships:
			if candidate.enemy_rank == rank: enemy = candidate
		state.encounters[0] = {"kind":"battle","enemy":0,"enemy_data":enemy,"completed":false,"charge_awarded":false}
		board = board_for(state,0)
		board.enemy_hull = 0
		board._check_winner()
		board.refresh_display()
		var expected: int = [2,3,3][rank]
		check(state.upgrades_remaining == expected, "Configured upgrades by rank")
		var picked: Array = []
		for n in range(expected):
			var card = state.upgrade_candidates()[0]
			var key: String = card.identity_key()
			check(not key in picked and state.choose_upgrade(key), "Separate identity for each upgrade")
			picked.append(key)
			check(not state.choose_upgrade(key), "Same identity cannot be upgraded twice in one event")
		check(state.pending_choice.is_empty() and state.upgrades_remaining == 0, "Sequential reward ends cleanly")
		state.start_upgrade_event(1)
		check(state.choose_upgrade(picked[0]) and state.upgraded_cards[picked[0]].upgrade_level == 2, "Later event can upgrade same identity")
		board.queue_free()
		await process_frame
	state = fresh()
	var eligible = state.player_pool()[0]
	for card in state.player_pool(): state.upgraded_cards[card.identity_key()] = card.with_upgrade(2)
	state.upgraded_cards[eligible.identity_key()] = eligible.with_upgrade(1)
	state.start_upgrade_event(3)
	check(state.upgrades_remaining == 1 and state.choose_upgrade(eligible.identity_key()) and state.pending_choice.is_empty(), "Fewer eligible identities truncate reward")
	var old_salvage: int = state.salvage
	state.start_upgrade_event(3)
	check(state.upgrades_remaining == 0 and state.pending_choice.is_empty() and state.salvage == old_salvage, "Exhaustion grants no extra combat Salvage")
	# New systems discard surplus and reset interception state without changing requirements.
	state = fresh()
	state.arrive_destination(0)
	state.try_chasedown(1,0)
	state.encounters[state.chasedown_index].completed = true
	state.pending_destination = -1
	state.ftl_charge = state.required_ftl_charge+100
	check(state.generate_system() and state.ftl_charge == 0 and state.chasedowns_this_system == 0 and state.navigation_origin == -1, "Zero carryover and per-system reset")
	var wormhole = load("res://encounters/unstable_wormhole.tres")
	for index in range(4):
		var approach = wormhole.approaches[index]
		check(is_equal_approx(approach.success_chance,[1.0,0.4,0.5,0.45][index]) and approach.success.extra_ftl_charge <= 1 and approach.failure.extra_ftl_charge == 0, "Wormhole chance and bonus bounds")
	check(wormhole.approaches[1].failure.next_battle.shields == -8 and wormhole.approaches[2].failure.next_battle.emp_pulse_offline == 3 and wormhole.approaches[3].failure.next_battle.energy == -8, "Wormhole failure penalties")
	check(wormhole.approaches[2].minimum_production == 4 and wormhole.approaches[3].minimum_production == 3 and wormhole.approaches[0].requirement.is_empty(), "Wormhole gates retained")
	print("Chasedown/rewards: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
