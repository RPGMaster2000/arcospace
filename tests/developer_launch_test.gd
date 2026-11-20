extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Launch = preload("res://scripts/expedition/developer_launch.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const MENU = preload("res://scenes/battle_setup.tscn")

var checks := 0
var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func launch(mode: String, stage: int, rank: int) -> State:
	var state := State.new()
	state.start(0, Rules, 17891, Launch.configuration(mode, stage, rank))
	check(state.game_mode == mode and state.system_number == stage, "Launches %s at System %d" % [mode, stage])
	check(not state.can_jump() and state.hull == state.ship().hull_capacity, "Normal objectives and starting hull")
	return state


func ranks(state: State) -> Array:
	return state.encounters.filter(func(entry): return entry.kind == "battle").map(
		func(entry): return state.enemy_profile(entry).enemy_rank)


func verify_generation() -> void:
	check(Launch.configuration("warzone", 11, 2).is_empty(), "Stage range is bounded")
	check(Launch.configuration("warzone", 1, 3).is_empty(), "Tier range is bounded")
	var warzone := launch("warzone", 1, 0)
	check(warzone.warzone.is_lattice() and warzone.warzone.fleets.size() > 3, "Warzone uses the live lattice and fleets")
	check(warzone.homeworld_outcome.is_empty() and warzone.warzone_support_package().tier == "standard",
		"Skipped Homeworld uses standard support without invented history")
	check(warzone.service.kind == "service" and not warzone.warzone.objectives.is_empty(), "Warzone retains its shop and objectives")
	check(ranks(warzone).all(func(rank): return rank == 0), "Warzone System 1 supports Tier 1")
	check(ranks(launch("warzone", 1, -1)).all(func(rank): return rank == 0), "System 1 Automatic uses standard enemies")
	check(ranks(launch("warzone", 2, 1)).all(func(rank): return rank == 1), "Warzone System 2 supports Tier 2")
	check(ranks(launch("warzone", 2, 2)).all(func(rank): return rank == 2), "Warzone System 2 supports Tier 3")
	var normal := State.new()
	normal.start(0, Rules, 17891)
	check(normal.game_mode == "defense" and normal.next_campaign_operation() == "warzone", "Normal expedition starts with Homeworld")
	normal.defense.complete = true
	check(normal.generate_system(), "Normal campaign still enters Warzone")
	check(ranks(launch("warzone", 2, -1)) == ranks(normal), "System 2 Automatic follows normal Warzone tier policy")

	var defense := launch("defense", 2, 2)
	check(ranks(defense).all(func(rank): return rank == 2), "All Defense encounters, including reserves, use Tier 3")
	check(defense.defense.units.any(func(unit): return unit.status == "reserve") and defense.encounters.any(func(entry): return entry.kind == "poi"),
		"Defense retains reserves and points of interest")
	var original := launch("defense", 2, -1)
	check(defense.rng.state == original.rng.state and defense.faction_id == original.faction_id,
		"Override does not disturb the generation stream or faction selection")
	defense.defense.complete = true
	check(defense.generate_system() and defense.system_number == 3 and defense.developer_enemy_rank() == -1,
		"Jumping restores automatic difficulty while keeping the test session")

	var exploration := launch("exploration", 6, 0)
	check(ranks(exploration).all(func(rank): return rank == 0), "Exploration encounters use the selected tier")
	check(exploration.encounters.any(func(entry): return entry.get("mandatory_boss", false)),
		"Exploration retains the stage's mandatory encounter")
	check(exploration.salvage > 0 and not exploration.production_upgrades.is_empty(),
		"Skipped stages start with a modest progression budget")
	var late := launch("exploration", 10, 2)
	late.navigation_origin = State.FREE_DESTINATION
	late.begin_free_travel([10.0, 0.0, 10.0], 0.0)
	check(late.chasedown_unresolved(), "Exploration still generates chasedowns during travel")
	if late.chasedown_unresolved():
		var pursuit: Dictionary = late.encounters[late.chasedown_index]
		var enemy := late.enemy_profile(pursuit)
		check(enemy.enemy_rank == 2 and enemy.hull_capacity > pursuit.enemy_data.hull_capacity,
			"Dynamic enemies use the overridden tier and the selected stage scaling")


func click(control: Control, touch: bool = false) -> void:
	for down in [true, false]:
		if touch:
			var event := InputEventScreenTouch.new()
			event.position = root.get_screen_transform() * control.get_global_rect().get_center()
			event.pressed = down
			Input.parse_input_event(event)
			Input.flush_buffered_events()
		else:
			var event := InputEventMouseButton.new()
			event.position = control.get_global_rect().get_center()
			event.button_index = MOUSE_BUTTON_LEFT
			event.pressed = down
			root.push_input(event, true)
		await process_frame


func keyboard(key: Key) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = down
		root.push_input(event, true)
		await process_frame


func verify_menu() -> void:
	root.size = Vector2i(960, 540)
	var store := Save.new()
	store.path = "user://developer-launch-normal.json"
	store.clear_run()
	var normal := State.new()
	normal.start(2, Rules, 1723)
	if not store.save_run(normal):
		check(false, "Writes a normal save fixture: " + store.error)
		return
	var saved := FileAccess.get_file_as_bytes(store.path)
	var menu = MENU.instantiate()
	menu.save_store = store
	root.add_child(menu)
	current_scene = menu
	menu.showcase.skip_cinematics = true
	for attempt in 3:
		if menu.settings_button.visible:
			break
		menu.showcase.advance()
		await process_frame
	if not menu.settings_button.visible:
		check(false, "Settings are available at the title menu")
		return
	menu.continue_fade_duration = 0.02
	menu.map_reveal_duration = 0.02
	await click(menu.settings_button)
	await click(menu.settings_button.menu.main_menu_button)
	var dialog = menu.developer_menu
	if not is_instance_valid(dialog):
		check(false, "Mouse input opens Developer Testing from Settings")
		return
	check(paused and root.gui_get_focus_owner() == dialog.mode, "Opening the menu pauses the title and focuses Game Mode")
	for dimensions in [Vector2i(1280, 720), Vector2i(1680, 720), Vector2i(686, 384), Vector2i(960, 540)]:
		root.size = dimensions
		for frame in 4:
			await process_frame
		for control in [dialog.mode, dialog.stage, dialog.difficulty, dialog.back_button, dialog.launch_button]:
			check(root.get_visible_rect().encloses(control.get_global_rect()), "Test controls fit at %s" % dimensions)
	await keyboard(KEY_TAB)
	check(root.gui_get_focus_owner() == dialog.stage, "Keyboard advances between selectors")
	await keyboard(KEY_TAB)
	check(root.gui_get_focus_owner() == dialog.difficulty, "Keyboard reaches Enemy Difficulty")
	await click(dialog.difficulty, true)
	var tiers: PopupMenu = dialog.difficulty.get_popup()
	check(tiers.visible, "Touch opens the difficulty dropdown")
	tiers.hide()
	dialog.difficulty.select(1)
	await click(dialog.launch_button, true)
	await create_timer(0.25, true).timeout
	if current_scene == menu:
		check(false, "Simulated touch activates Launch Test")
		return
	var test = current_scene
	check(test.state.is_warzone() and test.state.system_number == 1 and test.state.developer_enemy_rank() == 0,
		"Launch Test enters Warzone directly at the chosen settings")
	check(not test.persistence_enabled and not paused, "The unsaved test map is interactive")
	check(test.screen.overview_hud.system_name.begins_with("Test ·"), "The map identifies the session as a test")
	var fight: int = -1
	for index in test.state.encounters.size():
		if test.state.encounters[index].kind != "battle":
			continue
		var fleet: Dictionary = test.state.warzone_fleet(index)
		if not fleet.is_empty() and test.state.warzone.active(fleet):
			test.state.navigation.checkpoint_position(State.Defense.wire(fleet.position))
			if test.state.can_engage(index):
				fight = index
				break
	check(fight >= 0, "Warzone presents a playable encounter")
	if fight >= 0:
		test.start_battle(fight, 701)
		check(is_instance_valid(test.battle), "The existing combat scene starts")
		if is_instance_valid(test.battle):
			var settings = test.battle.settings_button.menu
			check(settings.main_menu_button.text == "Exit Developer Test", "Battle settings offer test exit")
			test.state.salvage += 50
			test._save_progress()
			var director = test.battle.cinematic_director
			if director.skip_button.is_visible_in_tree():
				await click(director.skip_button, true)
			await process_frame
			await click(test.battle.settings_button)
			await click(test.battle.settings_button.settings_option)
			await process_frame
			check(settings.shade.visible, "Battle settings open after the intro")
			await click(settings.main_menu_button)
	check(current_scene != test and current_scene.saved_run.state.seed_used == 1723,
		"Exit restores the original Continue Expedition")
	check(FileAccess.get_file_as_bytes(store.path) == saved, "The normal save remains byte-for-byte identical")
	if current_scene != test:
		menu = current_scene
		menu._open_developer_testing()
		check(menu.developer_menu.difficulty.selected == 1, "The chosen configuration is remembered in this session")
		await keyboard(KEY_ESCAPE)
		check(not paused, "Backing out restores title interaction")
	current_scene.queue_free()
	await process_frame
	store.clear_run()


func run() -> void:
	verify_generation()
	await verify_menu()
	print("Developer launch: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
