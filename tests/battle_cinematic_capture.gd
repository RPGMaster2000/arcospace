extends SceneTree
## Optional production-scene motion evidence, not an additional gameplay test suite.
## Run rendered with --script res://tests/battle_cinematic_capture.gd.
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
var host: Node
var records: Array = []
var recording := false
var capturing := false
var last_capture := 0
var started := 0
var directory := "res://.godot/testlogs/battle-camera/motion"
var original_skip := false


func _initialize() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
	original_skip = Preferences.skip_cinematics()
	Preferences.set_skip_cinematics(false)
	call_deferred("run")


func sample() -> void:
	if not recording or capturing or Time.get_ticks_msec() - last_capture < 100:
		return
	capturing = true
	last_capture = Time.get_ticks_msec()
	await RenderingServer.frame_post_draw
	var source = host.battle
	var stage: String = (
		source.cinematic_director.stage
		if is_instance_valid(source) and source.cinematic_director.active
		else "gameplay"
	)
	if is_instance_valid(source) and source.get_node("MatchResult").visible:
		stage = "victory_result"
	elif stage == "destruction_hold" and not source.cinematic_director.enemy.get_node("Body").visible:
		stage = "fragments"
	elif not is_instance_valid(source):
		stage = "upgrades" if host.card_management.shade.visible else "star_system"
	var path := "%s/%04d.webp" % [directory, records.size()]
	root.get_texture().get_image().save_webp(path)
	records.append(
		{
			"file": path.get_file(),
			"seconds": float(Time.get_ticks_msec() - started) / 1000.0,
			"stage": stage
		}
	)
	capturing = false


func wait_for(condition: Callable) -> void:
	while not condition.call():
		await process_frame


func run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	directory += "-" + RenderingServer.get_current_rendering_method()
	DirAccess.make_dir_recursive_absolute(directory)
	host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.game_mode = "defense"
	host.rules.debug_seed = 717
	root.add_child(host)
	host.state.defense.contact = 0
	started = Time.get_ticks_msec()
	recording = true
	process_frame.connect(sample)
	host.start_battle(0, 707)
	var board: Node = host.battle
	board.enemy_timer.stop()
	await wait_for(
		func():
			return (
				not board._presentation_locked()
				and not board.resolving_card
				and not board.battle_effects.busy
			)
	)
	board.enemy_timer.stop()
	# Controlled lethal hit for reproducible capture; real card/beam/resolution/VFX.
	board.hand.cards[0] = load("res://cards/27_missile_barrage.tres")
	board.player_crew = 99
	board.enemy_shields = 0
	board.enemy_hull = 3
	board._act("player", 0, false)
	await wait_for(
		func():
			return (
				board.result_recorded
				and not board.resolving_card
				and not board.destruction_pending
				and not board._presentation_locked()
				and not board.battle_effects.busy
			)
	)
	await create_timer(1.6).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(directory+"/victory-complete.webp")
	board._continue_encounter()
	while host.state.pending_choice == "upgrade" and not host.state.upgrade_candidates().is_empty():
		host._upgrade(host.state.upgrade_candidates()[0].identity_key())
	host.show_system()
	await wait_for(func(): return not is_instance_valid(host.battle))
	await create_timer(.35).timeout
	recording = false
	while capturing:
		await process_frame
	var file := FileAccess.open(directory + "/frames.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	Preferences.set_skip_cinematics(original_skip)
	host.free()
	await process_frame
	print("Captured %d production battle frames" % records.size())
	quit()
