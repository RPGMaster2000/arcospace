extends SceneTree
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Card = preload("res://scripts/cards/card_data.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func make_board(side: String, effects: Dictionary, shields: int = 20) -> Node:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.get_node("BattleEffects").enabled = false
	root.add_child(board)
	board.enemy_timer.stop()
	root.get_node("Music").player.stop()
	root.get_node("Music").player.stream = null
	board.modifier.configure(0)
	board.battle_effects.enabled = true
	board.current_actor = side
	board.player_shields = shields
	board.enemy_shields = shields
	board.player_hull = 30
	board.enemy_hull = 30
	var card = Card.new()
	card.card_name = "Timing probe"
	card.family = "materials"
	card.cost = 2
	card.effects = effects
	board.hand.cards[0] = card
	board.enemy_hand.cards[0] = card
	var motion = board.get_node("CardMotion")
	motion.settings = motion.settings.duplicate(true)
	motion.settings.travel_seconds = 0.06
	motion.settings.hold_seconds = 0.12
	motion.settings.exit_seconds = 0.08
	motion.settings.refill_seconds = 0.02
	board.refresh_display()
	return board

func cleanup(board: Node) -> void:
	board.enemy_timer.stop()
	board.queue_free()
	await process_frame

func run() -> void:
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		check(RenderingServer.get_current_rendering_method() == OS.get_cmdline_user_args()[0], "Requested renderer active")
	var saved: bool = Preferences.battle_vfx()
	Preferences.set_battle_vfx(true)
	for side in ["player", "enemy"]:
		for shields in [20, 0, 2]:
			var board = make_board(side, {"damage": 6}, shields)
			var other: String = "enemy" if side == "player" else "player"
			var motion = board.get_node("CardMotion")
			board._act(side, 0, false)
			await motion.step_finished # Fully raised: beam and dissolve now begin together.
			await process_frame
			check(board.get(other + "_shields") == shields and board.get(other + "_hull") == 30, "No damage before weapon contact")
			check(is_instance_valid(board.battle_effects.active_beam), "Beam begins when raised card starts dissolving")
			check(board.current_actor == side and board.resolving_card, "Turn stays locked")
			await board.action_finished
			check(board.get(other + "_shields") == maxi(0, shields - 6), "Shields resolve at contact exactly once")
			check(board.get(other + "_hull") == (30 if shields == 20 else (24 if shields == 0 else 26)), "Hull resolves at contact exactly once")
			check(board.battle_effects.imported_nodes.is_empty(), "VFX cleaned up")
			await cleanup(board)
	# Non-damage, discard and disabled VFX never create beam instances.
	for entry in [[{"shields": 3}, false, true], [{"damage": 6}, true, true], [{"damage": 6}, false, false]]:
		Preferences.set_battle_vfx(entry[2])
		var board = make_board("player", entry[0])
		var motion = board.get_node("CardMotion")
		board._act("player", 0, entry[1])
		await motion.step_finished
		check(board.current_actor == "player" and board.resolving_card, "Turn stays locked during non-beam activation")
		await board.action_finished
		check(board.battle_effects.imported_nodes.is_empty(), "No lingering imported VFX")
		await cleanup(board)
	Preferences.set_battle_vfx(true)
	var closing = make_board("player", {"damage": 6}, 2)
	closing._act("player", 0, false)
	await closing.get_node("CardMotion").step_finished
	closing.queue_free()
	await process_frame
	await process_frame
	Preferences.set_battle_vfx(saved)
	root.get_node("Sfx").stop_all()
	await create_timer(0.1).timeout
	print("Card VFX timing: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
