extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for frame in range(4): await process_frame
func activate(button: Button, input: String) -> void:
	var at := button.get_global_rect().get_center()
	if input == "keyboard":
		button.grab_focus()
		for pressed in [true,false]:
			var event := InputEventAction.new()
			event.action = "ui_accept"
			event.pressed = pressed
			root.push_input(event,true)
			await process_frame
	elif input == "touch":
		for pressed in [true,false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.window_id = root.get_window_id()
			event.position = root.get_final_transform()*at
			event.pressed = pressed
			# Enter through Input so Godot performs the production touch-to-pointer
			# emulation; Viewport.push_input alone bypasses that native stage.
			Input.parse_input_event(event)
			await process_frame
	else:
		var move := InputEventMouseMotion.new()
		move.position = at
		root.push_input(move,true)
		await process_frame
		check(root.gui_get_hovered_control() == button,"Pointer hits intended action, not decorative containers")
		for pressed in [true,false]:
			var event := InputEventMouseButton.new()
			event.position = at
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = pressed
			root.push_input(event,true)
			await process_frame
func run() -> void:
	var vfx_before := Preferences.battle_vfx()
	var skip_before := Preferences.skip_cinematics()
	var emulate_before: bool = Input.emulate_mouse_from_touch
	Input.emulate_mouse_from_touch = true
	Preferences.set_battle_vfx(false)
	for input in ["mouse","touch","keyboard"]:
		Preferences.set_skip_cinematics(input == "keyboard")
		root.size = Vector2i(960,540) if input == "touch" else Vector2i(1280,720)
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
		await settle()
		state.defense.contact = 0
		host.start_battle(0,777)
		var board: Node = host.battle
		board.enemy_timer.stop()
		if board.battle_effects.busy: await board.battle_effects.finished
		for frame in range(3): await process_frame
		board.enemy_hull = 0
		board._check_winner()
		board.refresh_display()
		var result: Control = board.get_node("MatchResult")
		var deadline := Time.get_ticks_msec()+10000
		while not result.started and Time.get_ticks_msec() < deadline: await process_frame
		check(result.started,"Production result reveal initializes before input")
		if not result.started:
			host.queue_free()
			await settle()
			continue
		deadline = Time.get_ticks_msec()+6000
		if input == "touch":
			var skips := [0]
			result.skip_button.pressed.connect(func(): skips[0] += 1)
			await activate(result.skip_button,input)
			check(skips[0] == 1,"Native touch reaches Skip exactly once")
		while result.running and Time.get_ticks_msec() < deadline: await process_frame
		var button: Button = result.get_node("Panel/Continue")
		check(state.pending_choice == "upgrade" and state.upgrades_remaining > 0,"Real victory commits pending upgrade event")
		var remaining: int = state.upgrades_remaining
		var committed: Dictionary = Save.encode(state)
		var calls := [0]
		button.pressed.connect(func(): calls[0] += 1)
		check(button.visible and not button.disabled and button.text == "Upgrade Cards","Upgrade Cards is visible and enabled after "+input)
		for dimensions in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(960,540),Vector2i(900,600)]:
			root.size = dimensions
			await settle()
			check(result.get_global_rect().encloses(button.get_global_rect()),"Primary action remains inside viewport after resize")
			check(not button.get_global_rect().intersects(result.details_button.get_global_rect()),"Details cannot overlap primary action")
			for node in result.animated:
				if not node is BaseButton: check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE,"Decoration never owns pointer input")
		await activate(button,input)
		await settle()
		check(calls[0] == 1,"Real "+input+" reaches existing button handler exactly once")
		check(host.card_management.shade.visible and state.pending_choice == "upgrade" and state.upgrades_remaining == remaining,"Existing upgrade interface preserves authoritative event")
		check(state.salvage == committed.salvage,"Continuation does not grant rewards again")
		var modal = host.card_management
		check(modal.heading.text.contains(str(remaining)+" upgrades remaining"),"UI count matches expedition state")
		var attempts := 0
		while state.pending_choice == "upgrade" and attempts < 10:
			attempts += 1
			await settle()
			var before: int = state.upgrades_remaining
			await activate(modal.gallery.grid.get_child(0),input)
			check(modal.selected_card != null and not modal.confirm_button.disabled,"Real input selects eligible card")
			await activate(modal.confirm_button,input)
			check(state.upgrades_remaining == before-1,"Each real confirmation consumes exactly one upgrade")
		check(state.pending_choice.is_empty() and state.upgrades_remaining == 0,"All pending upgrades complete normally")
		await create_timer(0.3).timeout
		await settle()
		var next: Button
		for action in host.view.find_children("*","Button",true,false):
			if action.text == "Continue" and action.is_visible_in_tree(): next = action
		check(next != null,"Existing reward workflow exposes return action")
		if next != null: await activate(next,input)
		await settle()
		check(host.phase == host.Phase.OVERVIEW and host.star_map.visible,"Upgrade completion returns to normal system progression")
		check(state.salvage == committed.salvage,"Full upgrade flow preserves committed reward balance")
		host.queue_free()
		await settle()
	Preferences.set_battle_vfx(vfx_before)
	Preferences.set_skip_cinematics(skip_before)
	Input.emulate_mouse_from_touch = emulate_before
	print("Result upgrade input: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
