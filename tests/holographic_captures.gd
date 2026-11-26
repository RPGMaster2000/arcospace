extends SceneTree

const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Adapter = preload("res://scripts/combat/battle_adapter.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")

func _initialize() -> void: call_deferred("run")

func capture(label: String) -> Image:
	for frame in 5: await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("ARCOSPACE_CAPTURE_DIR")
	if output.is_empty(): output = "res://.godot/testlogs/holographic"
	DirAccess.make_dir_recursive_absolute(output)
	var image := root.get_texture().get_image()
	image.resize(800, roundi(800.0 * image.get_height() / image.get_width()), Image.INTERPOLATE_LANCZOS)
	image.save_webp("%s/%s.webp" % [output, label], true, 0.78)
	print("Captured ", label)
	return image

func run() -> void:
	root.size = Vector2i(960,540)
	var vfx_before := Preferences.battle_vfx()
	Preferences.set_battle_vfx(false)
	var menu = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
	root.add_child(menu)
	menu._select(0)
	menu.showcase._stop_tween()
	menu.showcase._finish_intro()
	menu.showcase.logo.modulate.a = 0.0
	menu.showcase.phase = menu.showcase.Phase.SHIP_SELECTION
	menu._selection_ready()
	await capture("ship-selection")
	menu.free()
	await process_frame
	var state := State.new()
	state.start(0, Rules, 39, {"mode":"defense","stage":5,"rank":-1})
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state":state,"battle":{}}
	root.add_child(host)
	await capture("strategic")
	host._inspect_marker(state.defense.convoy.pursuers.front())
	await create_timer(0.4).timeout
	await capture("inspection")
	host.free()
	await process_frame
	var index: int = state.defense.convoy.pursuers.front()
	state.defense.contact = index
	var board = preload("res://scenes/board_3d.tscn").instantiate()
	board.expedition = state
	Adapter.configure(board,state.prepare_battle(index))
	root.add_child(board)
	board.enemy_timer.stop()
	if board.battle_effects.busy: await board.battle_effects.finished
	var battle_image := await capture("battle")
	var output := OS.get_environment("ARCOSPACE_CAPTURE_DIR")
	if output.is_empty(): output = "res://.godot/testlogs/holographic"
	battle_image.get_region(Rect2i(0, 254, 800, 196)).save_webp(output + "/hand.webp", true, 0.81)
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	var result: Control = board.get_node("MatchResult")
	while not result.started: await process_frame
	result.skip()
	await capture("result")
	board.queue_free()
	await create_timer(0.3).timeout
	var showcase_path := "res://scenes/tools/holographic_showcase.tscn"
	if ResourceLoader.exists(showcase_path):
		root.size = Vector2i(960, 810)
		var showcase: Control = load(showcase_path).instantiate()
		root.add_child(showcase)
		await capture("showcase")
		showcase.free()
	Preferences.set_battle_vfx(vfx_before)
	quit()
