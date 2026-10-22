extends SceneTree
const Ships = preload("res://scripts/ships/ship_library.gd")
const Config = preload("res://encounters/expedition_rules.tres")
const State = preload("res://scripts/expedition_state.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
var failures: int = 0
var checks: int = 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	check(Ships.PLAYERS.size() == 6 and Ships.ENEMIES.size() == 6, "Six players and six regular enemies")
	var seen: Dictionary = {}
	for seed_value in range(1, 301):
		var expedition = State.new()
		expedition.start(0, Config, seed_value)
		for encounter in expedition.encounters:
			if encounter.kind == "battle" and expedition.enemy_profile(encounter).enemy_rank == 0: seen[expedition.enemy_profile(encounter).ship_name] = true
	check(seen.size() == 6, "All regular profiles occur in generated first-system encounters")
	var expected: Array = [[32,4,14,8,10,3,1,2],[29,16,8,14,10,1,3,2],[42,4,12,8,12,2,1,3]]
	for index in range(3,6):
		var profile = Ships.ENEMIES[index]
		check(profile in Config.enemy_ships and profile.encounter_weight == 1 and profile.enemy_rank == 0, "Standard equal encounter weight")
		for key in ["hull_capacity","shields","materials","energy","crew","synthesizer","reactor","quarters"]:
			check(profile.get(key) == expected[index-3].pop_front(), "Exact stats: " + profile.ship_name + " " + key)
		var identities: Dictionary = {}
		var families: Dictionary = {}
		for card in profile.starting_cards:
			check(card in Cards.CARDS and card.upgrade_level == 0, "Existing base card resource")
			identities[card.identity_key()] = true
			families[card.family] = true
		check(identities.size() == 20 and families.size() == 3, "Distinct 20-card deck covers all three families")
	# Real board integration for every player/enemy pairing, including ordinary victory bookkeeping.
	for player in range(6):
		for enemy in range(6):
			var expedition = State.new()
			expedition.start(player, Config, 17)
			expedition.encounters.assign([{"kind":"battle","enemy_data":Ships.ENEMIES[enemy],"system_number":1,"completed":false}])
			var board = load("res://scenes/board_3d.tscn").instantiate()
			board.setup_settings = {"player_ship":player,"enemy_data":expedition.enemy_profile(expedition.encounters[0])}
			board.expedition = expedition
			board.expedition_encounter = 0
			board.get_node("BattleEffects").enabled = false
			board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
			board.get_node("CardMotion").settings.enabled = false
			root.add_child(board)
			check(board.enemy_hull == Ships.ENEMIES[enemy].hull_capacity and board.enemy_shields == Ships.ENEMIES[enemy].shields, "Enemy stats loaded")
			check(board.hand.card_pool.size() == 28 and board.hand.cards.size() == 6, "Player pool and hand unchanged")
			var pool: Array = Ships.ENEMIES[enemy].starting_cards if enemy >= 3 else Cards.CARDS
			check(board.enemy_hand.card_pool == pool, "Expedition respects optional enemy deck and full-library fallback")
			check(board.enemy_ai.tactical_weights == Ships.ENEMIES[enemy].tactical_weights, "AI preferences loaded")
			for card in board.enemy_hand.cards: check(card in pool, "Opening enemy hand uses profile pool")
			var model = board.get_node("BattleView/Viewport/Battlefield/EnemyShip")
			check(model.has_node("Body/Hull") and model.has_node("Body/Engine") and model.has_node("Shield"), "Animation node contract")
			model.set_hull_strength(3)
			model.set_shield_strength(0)
			check(not model.shield.visible, "Shield depletion")
			if enemy >= 3 and player == 0:
				check(model.scene_file_path == Ships.ENEMIES[enemy].model_scene.resource_path, "Independent model installed")
				var tween = model.create_tween()
				model.animate_hit(tween, true, 0.01)
				model.animate_repair(tween, 0.01)
				model.animate_explosions(tween, 0.01)
				model.animate_shield(tween, 0.01, true)
				await tween.finished
				await process_frame
				check(model.get_node("Body/Hull").get_child_count() == 0, "Destruction flash cleanup")
			board.enemy_hull = 0
			check(board._check_winner() and board.winner == "player", "Battle completion")
			board._record_result()
			expedition.record_battle(board.battle_result())
			check(expedition.encounters[0].completed and expedition.ftl_charge == 1 and expedition.salvage >= 10, "Standard progression and rewards")
			board.queue_free()
			await process_frame
	print("Enemy roster: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
