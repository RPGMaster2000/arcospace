extends SceneTree
const Mod = preload("res://scripts/combat_modifier.gd")
const Data = preload("res://scripts/card_data.gd")
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
		check(due - 1 >= 6 and due - 1 <= 10, "Initial countdown must be 6–10 full rounds")
		check(mod.begin_round(due - 1).is_empty(), "Event cannot arrive early")
		check(not mod.begin_round(due).is_empty(), "Event must activate exactly when countdown reaches zero")
		if kind == 1:
			check(not mod.active and mod.next_round >= due + 6 and mod.next_round <= due + 10, "Asteroid is instant and reschedules")
		else:
			check(mod.active, "Ion/solar must stay active for both ships")
			mod.begin_round(due + 1)
			check(not mod.active and mod.next_round >= due + 7 and mod.next_round <= due + 11, "Event expires after one round and reschedules")
	var a = state()
	var b = state()
	a.shields = 2
	mod.asteroid_strike(a,b,[0.0,0.2])
	check(a.shields == 0 and a.hull == 27 and b == state(), "Asteroids independently hit/miss; shields block first")
	a = state()
	b = state()
	mod.asteroid_strike(a,b,[0.0,0.0])
	check(a.shields == 5 and b.shields == 5 and a.hull == 30 and b.hull == 30, "Both ships can be hit without shield bypass")
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
		a = state()
		b = state()
		mod.play(blue,a,b,roll)
		check(a.hull == (36 if roll == 0 else 31), "Ion must scale repair and round halves down")
		check(a.energy == (26 if roll == 0 else 20), "Ion must scale resource gain without scaling cost")
		check(b.crew == (14 if roll == 0 else 19), "Ion must scale nested drain amounts")
		check(b.shields == (0 if roll == 0 else 7) and b.hull == (28 if roll == 0 else 30), "Ion must scale damage")
	check(blue.effects.damage == 6, "Modifiers must not mutate card resources")
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
	mod.miss_rate = 70
	a = state()
	b = state()
	mod.play(card({"damage":6}),a,b,0.0)
	check(a.energy == 18 and b == state(), "Nebula miss spends cost but has no effect")
	mod.play(card({"hull":3}),a,b,0.0)
	check(a.hull == 33, "Non-combat cards never miss")
	for round_number in range(2,300):
		var old: int = mod.miss_rate
		mod.begin_round(round_number)
		check(mod.miss_rate >= 0 and mod.miss_rate <= 70 and absi(mod.miss_rate-old) <= 5, "Nebula must drift within bounds")
	mod.queue_free()
	# Exercise real setup controls, board initialization and round flow.
	var setup = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(setup)
	setup.get_node("Panel/player_materials").value = 7
	setup.get_node("Panel/player_synthesizer").value = 3
	setup.get_node("Panel/enemy_energy").value = 9
	setup.get_node("Panel/FTL").value = 20
	setup.get_node("Panel/Modifier").select(3)
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = setup.read_settings()
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardMotion").settings.enabled = false
	root.add_child(board)
	check(board.player_materials == 10 and board.enemy_energy == 9 and board.ftl.charge_target == 20, "Setup resources and production applied before first income")
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
	check(old_player_shields - board.player_shields in [0,5] and old_enemy_shields - board.enemy_shields in [0,5], "Shower applies one normal hit or miss per ship")
	var shields_after: int = board.player_shields
	board._discard_card(0)
	board.enemy_timer.stop()
	check(board.player_shields == shields_after, "Shower cannot repeat on the enemy half of the round")
	board.winner = "player"
	board._return_to_setup()
	await process_frame
	var returned = current_scene
	check(returned.get_node("Panel/player_materials").value == 7 and returned.get_node("Panel/FTL").value == 20, "Return to setup preserves configuration")
	returned.get_node("Panel/Start").pressed.emit()
	await process_frame
	var restarted = current_scene
	check(restarted.setup_settings.player_materials == 7 and restarted.modifier.kind == 3, "Begin Battle uses the configured controls")
	restarted.queue_free()
	setup.queue_free()
	await process_frame
	print("Combat modifier checks: %d failures" % failures)
	quit(1 if failures else 0)
