extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Cards = preload("res://scripts/cards/card_library.gd")
var failures: int = 0
var checks: int = 0
class Result extends Node:
	var player_hull: int = 30
	var salvage: int = 0
	var battles_won: int = 1
	var winner: String = "player"
	var escaped_by_ftl: bool = false
	var enemy_hull: int = 0
	var earned_tactical: bool = false
	var earned_strategic: bool = false
	const TACTICAL_RESOURCES = 5
	const STRATEGIC_SHIELDS = 10
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for n in range(5): await process_frame
func screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/testlogs/reward-" + label + ".png")
func run() -> void:
	for profile in Rules.enemy_ships:
		for mode in ["destruction","systems","escape","loss"]:
			for tactical in [false,true]:
				var state = State.new()
				state.start(0, Rules, 9001)
				state.encounters[0] = {"kind":"battle","enemy":0,"enemy_data":profile,"completed":false}
				state.active_battle = 0
				var result = Result.new()
				result.escaped_by_ftl = mode == "escape"
				result.enemy_hull = 0 if mode == "destruction" else 15
				result.winner = "enemy" if mode == "loss" else "player"
				result.earned_tactical = tactical
				var defeated_elite: bool = profile.enemy_rank == 1 and mode in ["destruction","systems"]
				var expected: int = profile.destruction_salvage_reward
				if defeated_elite: expected *= 2
				if mode in ["escape","loss"]: expected = 0
				if mode != "loss": result.salvage = state.victory_salvage(result)
				check(result.salvage == expected, "Correct Salvage: " + profile.ship_name + " / " + mode)
				check(state.elite_resource_reward(result) == (3 if defeated_elite else 0), "Only defeated Elites offer resource reward")
				state.record_battle(result)
				var bonuses: Dictionary = state.pending_bonuses.duplicate()
				state.record_battle(result)
				check(state.pending_bonuses == bonuses, "No repeated bonus")
				var resource_bonus: int = (3 if defeated_elite else 0) + (5 if tactical and mode != "loss" else 0)
				for key in State.RESOURCES: check(state.modifier_value(key) == resource_bonus, "Elite stacks with tactical bonus for " + key)
				check(state.ftl_charge == (0 if mode == "loss" else profile.interstellar_ftl_reward), "FTL reward unchanged")
				result.free()
	var tuned = State.new()
	tuned.start(0, Rules.duplicate(), 9002)
	tuned.rules.elite_resource_bonus = 0
	tuned.rules.elite_salvage_multiplier = 3
	tuned.encounters[0] = {"kind":"battle","enemy":0,"enemy_data":load("res://ships/enemy/marauder_vanguard.tres"),"completed":false}
	tuned.active_battle = 0
	var result = Result.new()
	check(tuned.victory_salvage(result) == 60, "Inspector multiplier independent of resource bonus")
	result.free()
	var next_battle = State.new()
	next_battle.start(0, Rules, 9003)
	next_battle.encounters[0] = {"kind":"battle","enemy":0,"enemy_data":load("res://ships/enemy/marauder_vanguard.tres"),"completed":false}
	next_battle.active_battle = 0
	result = Result.new()
	next_battle.record_battle(result)
	result.free()
	for battle_index in range(2):
		var board = load("res://scenes/board_3d.tscn").instantiate()
		board.expedition = next_battle
		board.get_node("BattleEffects").enabled = false
		root.add_child(board)
		for key in State.RESOURCES:
			var production: String = {"materials":"synthesizer","energy":"reactor","crew":"quarters"}[key]
			check(board.get("player_" + key) == next_battle.ship().get(key) + next_battle.production(production) + (3 if battle_index == 0 else 0), "Elite resource bonus applies only to next battle: " + key)
		check(next_battle.pending_bonuses.is_empty(), "Elite bonuses consumed at battle start")
		board.free()
	root.size = Vector2i(1280,720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	root.add_child(host)
	current_scene = host
	host.state.start(0, Rules, 9004)
	host.state.pending_choice = "card"
	host.state.card_offers = host.state.random_card_offers()
	host.show_outcome()
	check(not host.card_gallery.filters.visible, "Entire acquisition toolbar hidden")
	host.state.choose_card(0)
	var acquired: Resource = host.state.acquired_cards[0]
	host.state.pending_choice = "upgrade"
	host.state.choose_upgrade(acquired.identity_key())
	host.state.pending_choice = "upgrade"
	host.show_outcome()
	check(host.card_gallery.filters.visible, "Upgrade gallery keeps useful filters")
	host.state.pending_choice = ""
	host.show_system()
	check(host.deck_button.get_parent() == host.legend.get_parent() and host.deck_button.get_index() + 1 == host.legend.get_index(), "Deck next to Legend")
	var rng_before: int = host.state.rng.state
	host.deck_button.pressed.emit()
	await settle()
	var viewer = host.current_deck_viewer
	check(viewer.gallery.cards == host.state.player_pool() and viewer.gallery.cards.size() == 29, "Current deck includes acquisition")
	var found: bool = false
	for card in viewer.gallery.cards:
		if card.identity_key() == acquired.identity_key(): found = card.upgrade_level == 1
	check(found, "Current deck shows upgrades")
	await screenshot("current-deck")
	viewer.inspector.present(viewer.gallery.cards[0], null, true)
	viewer.inspector._confirm()
	check(host.state.rng.state == rng_before and host.state.acquired_cards.size() == 1, "Current deck is read only")
	viewer.dismiss()
	for good in [true,false]:
		var poi = preload("res://scripts/expedition/poi_data.gd").new()
		poi.title = "Controlled mission"
		var approach = preload("res://scripts/expedition/encounter_approach.gd").new()
		approach.title = "Run mission"
		approach.success_chance = 1.0 if good else 0.0
		approach.success = preload("res://scripts/expedition/encounter_outcome.gd").new()
		approach.success.salvage = 7
		approach.success.card_reward = true
		approach.failure = preload("res://scripts/expedition/encounter_outcome.gd").new()
		approach.failure.salvage = 2
		approach.failure.card_reward = true
		poi.approaches.append(approach)
		host.state.encounters[0] = {"kind":"poi","poi":poi,"title":poi.title,"completed":false}
		host.show_poi(0)
		var salvage_before: int = host.state.salvage
		host._approach(0,0)
		check(host.presenting_outcome and host.view_kind == "poi", "Flash precedes reward screen")
		check(host.outcome_flash.active and host.outcome_flash.success == good, "Flash matches resolved branch")
		check((host.outcome_flash.shade.color.g > host.outcome_flash.shade.color.r) == good, "Green success/red worse outcome")
		await screenshot("green-flash" if good else "red-flash")
		var state_after_roll: int = host.state.rng.state
		host._approach(0,0)
		check(host.state.rng.state == state_after_roll and host.state.salvage == salvage_before + (7 if good else 2), "No duplicate roll/reward during flash")
		while host.presenting_outcome: await process_frame
		check(host.outcome_flash.tween.get_total_elapsed_time() + 0.001 >= host.visual_settings.poi_reveal_duration, "Flash respects configured duration")
		check(host.view_kind == "outcome" and host.mission_header.text == ("Mission Successful" if good else "Mission Compromised"), "Matching mission reward header")
		check(not host.card_gallery.filters.visible, "PoI reward toolbar hidden")
		await settle()
		await screenshot("success" if good else "compromised")
		host.state.choose_card(0)
	host.state.last_poi_success = -1
	host.show_outcome()
	check(host.mission_header == null, "Station/unrolled outcomes have no stale mission header")
	host.free()
	await process_frame
	print("Reward feedback: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
