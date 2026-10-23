extends SceneTree
const Mod = preload("res://scripts/combat_modifier.gd")
const Data = preload("res://scripts/cards/card_data.gd")
var failures: int = 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func state() -> Dictionary:
	return {"hull":30,"shields":10,"materials":20,"energy":20,"crew":20,"synthesizer":2,"reactor":2,"quarters":2}
func card(effects: Dictionary) -> Resource:
	var result = Data.new()
	result.family = "energy"
	result.cost = 2
	result.effects = effects
	return result
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var mod = Mod.new()
	root.add_child(mod)
	for kind in [1,2,3]:
		mod.configure(kind)
		var due: int = mod.next_round
		check(due - 1 >= Mod.MIN_INTERVAL and due - 1 <= Mod.MAX_INTERVAL, "Initial countdown must match configured interval")
		check(mod.begin_round(due - 1).is_empty(), "Event cannot arrive early")
		check(not mod.begin_round(due).is_empty(), "Event must activate exactly when countdown reaches zero")
		if kind == 1:
			check(not mod.active and mod.next_round >= due + Mod.MIN_INTERVAL and mod.next_round <= due + Mod.MAX_INTERVAL, "Asteroid is instant and reschedules")
		else:
			check(mod.active, "Ion/solar must stay active for both ships")
			mod.begin_round(due + 2)
			check(mod.active, "Event remains active for three consecutive rounds")
			mod.begin_round(due + Mod.ACTIVE_ROUNDS)
			check(not mod.active and mod.next_round >= due + Mod.ACTIVE_ROUNDS + Mod.MIN_INTERVAL and mod.next_round <= due + Mod.ACTIVE_ROUNDS + Mod.MAX_INTERVAL, "Event expires after three rounds and reschedules")
	var polaron = load("res://cards/29_polaron_burst.tres")
	var attacker = state()
	var defender = state()
	mod.configure(0)
	mod.play(polaron, attacker, defender)
	check(defender.energy == 16 and defender.shields == 2, "Polaron removes four enemy energy and eight shields")
	mod.configure(2)
	mod.begin_round(mod.next_round)
	var preview = mod.preview(polaron)
	attacker = state()
	defender = state()
	mod.play(polaron, attacker, defender, 0.99)
	check(defender.energy == 20 - int(preview.effects.drain.energy), "Preview equals actual ion drain regardless of roll")
	check(polaron.effects.drain.energy == 4, "Preview never mutates original card")
	var a = state()
	var b = state()
	a.shields = 2
	mod.asteroid_strike(a,b,[0.0,Mod.ASTEROID_CHANCE])
	check(a.shields == 0 and a.hull == 22 and b == state(), "Asteroids independently hit/miss; shields block first")
	a = state()
	b = state()
	mod.asteroid_strike(a,b,[0.0,0.0])
	check(a.shields == 0 and b.shields == 0 and a.hull == 30 and b.hull == 30, "Both ships can be hit without shield bypass")
	mod.configure(1)
	mod.active = true
	a = state()
	b = state()
	mod.play(card({"damage":6}),a,b,0.0)
	check(a.shields == 10 and b.shields == 4, "Asteroids must not alter card attacks")
	mod.configure(2)
	mod.active = true
	var blue = card({"damage":6,"hull":3,"energy":4,"drain":{"crew":3}})
	for roll in [0.0,0.9]:
		mod.ion_factor = 2.0 if roll == 0 else 0.5
		a = state()
		b = state()
		mod.play(blue,a,b,roll)
		check(a.hull == (36 if roll == 0 else 31), "Ion must scale repair and round halves down")
		check(a.energy == (26 if roll == 0 else 20), "Ion must scale resource gain without scaling cost")
		check(b.crew == (14 if roll == 0 else 19), "Ion must scale nested drain amounts")
		check(b.shields == (0 if roll == 0 else 7) and b.hull == (28 if roll == 0 else 30), "Ion must scale damage")
	check(blue.effects.damage == 6, "Modifiers must not mutate card resources")
	# All economic effects scale for either acting side; original resources stay intact.
	for roll in [0.0, 0.9]:
		mod.ion_factor = 2.0 if roll == 0 else 0.5
		a = state()
		b = state()
		b.reactor = 5
		mod.play(card({"materials":4,"steal":{"crew":4},"reactor":2,"sabotage":true}),a,b,roll)
		check(a.materials == (28 if roll == 0 else 22), "Ion scales resource gains")
		check(a.crew == (28 if roll == 0 else 22) and b.crew == (12 if roll == 0 else 18), "Ion scales both sides of theft")
		check(a.reactor == (6 if roll == 0 else 3) and b.reactor == (3 if roll == 0 else 5), "Ion scales production gains and sabotage")
	mod.active = false
	a = state()
	b = state()
	mod.play(card({"reactor":2,"sabotage":true}),a,b,0.0)
	check(a.reactor == 4 and b.reactor == 1, "Economic effects return to normal after ion ends")
	mod.configure(3)
	mod.active = true
	a = state()
	b = state()
	mod.play(card({"shields":9,"damage":6}),a,b,0.0)
	check(a.shields == 10 and b.shields == 10 and b.hull == 24, "Solar blocks shield gain, ignores shield absorption and reserves strength")
	mod.active = false
	mod.play(card({"damage":6}),a,b,0.0)
	check(b.shields == 4 and b.hull == 24, "Shields resume normal absorption after flare")
	mod.configure(4)
	check(mod.status_text(1).contains("70%") and mod.meter_value(1) == 70, "Nebula starts at 70 percent hit rate")
	mod.miss_rate = 70
	check(mod.meter_value(1) == 30, "Maximum interference shows 30 percent efficiency")
	a = state()
	b = state()
	mod.play(card({"damage":6}),a,b,0.0)
	check(a.energy == 18 and b == state(), "Nebula miss spends cost but has no effect")
	mod.play(card({"hull":3}),a,b,0.0)
	check(a.hull == 33, "Non-combat cards never miss")
	for round_number in range(2,300):
		var old: int = mod.miss_rate
		mod.begin_round(round_number)
		check(mod.miss_rate >= 0 and mod.miss_rate <= Mod.NEBULA_MAX and absi(mod.miss_rate-old) <= Mod.NEBULA_STEP, "Nebula must drift within configured bounds")
	mod.queue_free()
	for selection in range(5):
		var scene_board = load("res://scenes/board_3d.tscn").instantiate()
		scene_board.setup_settings = {"modifier":selection}
		scene_board.get_node("ModifierDisplay").cinematic_enabled = false
		root.add_child(scene_board)
		check(scene_board.get_node("BattleView/Viewport/Battlefield").scene_file_path == scene_board.BATTLEFIELDS[selection].resource_path, "Setup selects correct editable battlefield")
		scene_board.queue_free()
		await process_frame
	# Exercise real setup controls, board initialization and round flow.
	var setup = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(setup)
	setup._select(2)
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = setup.read_settings()
	board.setup_settings.modifier = 3
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardMotion").settings.enabled = false
	board.get_node("ModifierDisplay").cinematic_enabled = false
	root.add_child(board)
	check(board.player_materials == board.player_ship_data.materials + board.player_ship_data.synthesizer and board.enemy_energy == board.enemy_ship_data.energy and board.ftl.charge_target == 17, "Setup resources and production applied before first income")
	check(board.modifier.kind == 3 and board.turn_number == 1, "Setup modifier and first round")
	board.modifier.next_round = 2
	board._discard_card(0)
	board.enemy_timer.stop()
	check(board.turn_number == 1 and board.current_actor == "enemy", "Player action cannot advance full turn")
	board._act("enemy",0,true)
	check(board.turn_number == 2 and board.modifier.shields_disabled(), "Enemy action advances round and activates flare")
	check(not board.get_node("BattleView/Viewport/Battlefield/PlayerShip/Shield").visible, "Flare hides shields")
	board._discard_card(0)
	board.enemy_timer.stop()
	check(board.modifier.active, "Flare covers enemy action too")
	board.modifier.ends_round = 3 # Expiry path; three-round duration checked above.
	board._act("enemy",0,true)
	check(board.turn_number == 3 and not board.modifier.active, "Flare ends after full round")
	board.modifier.configure(1)
	board.modifier.next_round = 4
	var old_player_shields: int = board.player_shields
	var old_enemy_shields: int = board.enemy_shields
	board._discard_card(0)
	board.enemy_timer.stop()
	board._act("enemy",0,true)
	check(board.turn_number == 4 and board.get_node("ModifierDisplay/Flash").text.begins_with("ASTEROID SHOWER"), "Battlefield itself must trigger the shower at its scheduled round")
	check(old_player_shields - board.player_shields in [0,mini(old_player_shields,Mod.ASTEROID_DAMAGE)] and old_enemy_shields - board.enemy_shields in [0,mini(old_enemy_shields,Mod.ASTEROID_DAMAGE)], "Shower applies one normal hit or miss per ship")
	var shields_after: int = board.player_shields
	board._discard_card(0)
	board.enemy_timer.stop()
	check(board.player_shields == shields_after, "Shower cannot repeat on the enemy half of the round")
	board.winner = "player"
	board._return_to_setup()
	await process_frame
	var returned = current_scene
	check(returned.selected_ship == 2, "Return to setup preserves ship selection")
	returned.showcase.skip_cinematics = true
	returned.showcase._stop_tween()
	returned.showcase.phase = returned.showcase.Phase.SHIP_SELECTION
	returned._selection_ready()
	returned.white_fade_duration = 0.001
	returned.map_reveal_duration = 0.001
	returned.start_button.pressed.emit()
	for frame in range(8): await process_frame
	var restarted = current_scene
	check(restarted.state.player_ship == 2 and restarted.state.ship() == preload("res://scripts/ships/ship_library.gd").PLAYERS[2], "Begin expedition uses selected ship Resource")
	restarted.queue_free()
	setup.queue_free()
	await process_frame
	print("Combat modifier checks: %d failures" % failures)
	quit(1 if failures else 0)
