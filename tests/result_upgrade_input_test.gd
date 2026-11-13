extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	root.push_input(move,true)
	await process_frame
	var hovered := root.gui_get_hovered_control()
	print("Result input target: ",hovered.get_path() if hovered != null else "none")
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
func run() -> void:
	root.size = Vector2i(960,540)
	var vfx_before := Preferences.battle_vfx()
	Preferences.set_battle_vfx(false)
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	var state := State.new()
	state.start(0,rules,31025)
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state":state,"battle":{}}
	root.add_child(host)
	for frame in range(12): await process_frame
	state.defense.contact = 0
	host.start_battle(0,777)
	var board: Node = host.battle
	board.enemy_timer.stop()
	if board.battle_effects.busy: await board.battle_effects.finished
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	var result: Control = board.get_node("MatchResult")
	var deadline := Time.get_ticks_msec()+6000
	while (not result.started or result.running) and Time.get_ticks_msec() < deadline: await process_frame
	var button: Button = result.get_node("Panel/Continue")
	check(state.pending_choice == "upgrade" and state.upgrades_remaining > 0,"Real victory commits pending upgrade event")
	check(button.visible and not button.disabled and button.text == "Upgrade Cards","Upgrade Cards is visible and enabled")
	var calls := [0]
	button.pressed.connect(func(): calls[0] += 1)
	print("Result action rect: ",button.get_global_rect())
	for node in result.find_children("*","Control",true,false):
		if node.is_visible_in_tree() and node.get_global_rect().has_point(button.get_global_rect().get_center()):
			print("Over action: ",node.get_path()," filter=",node.mouse_filter," rect=",node.get_global_rect())
	await click(button.get_global_rect().get_center())
	for frame in range(12): await process_frame
	check(calls[0] == 1,"Real mouse input reaches existing button handler once")
	check(host.card_management.shade.visible and state.pending_choice == "upgrade","Expedition opens existing upgrade interface")
	host.queue_free()
	for frame in range(4): await process_frame
	Preferences.set_battle_vfx(vfx_before)
	print("Result upgrade input: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
