extends SceneTree
# Exercise the shipped entry scene and its real Start transition, including packed exports.
const Ships = preload("res://scripts/ships/ship_library.gd")
var failures: int = 0
var checks: int = 0


func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func settle() -> void:
	for frame in range(8):
		await process_frame


func preview_has_ship(viewport: SubViewport) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return false
	var bright: int = 0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var color: Color = image.get_pixel(x, y)
			if maxf(color.r, maxf(color.g, color.b)) > 0.25:
				bright += 1
	return bright >= 20


func run() -> void:
	root.size = Vector2i(1280, 720)
	for index in range(Ships.PLAYERS.size()):
		var store = preload("res://scripts/persistence/expedition_save.gd").new()
		store.path = "user://test_startup_run.json"
		store.clear_run()
		var menu = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate()
		menu.save_store = store
		root.add_child(menu)
		current_scene = menu
		await settle()
		menu._select(index)
		await settle()
		menu.showcase._stop_tween()
		menu.showcase.phase = menu.showcase.Phase.SHIP_SELECTION
		menu._selection_ready()
		var viewport: SubViewport = menu.get_node("World/Viewport")
		check(menu.showcase.models.size() == 6, "Preview contains camera, lighting and model")
		check(await preview_has_ship(viewport), "Preview has visible ship pixels: " + Ships.PLAYERS[index].ship_name)
		menu.start_button.pressed.emit()
		await settle()
		var expedition = current_scene
		check(expedition != menu and expedition.state != null, "Start reaches the expedition")
		if expedition == menu or expedition.state == null:
			quit(1)
			return
		check(expedition.state.player_ship == index, "Selection survives the real Start transition")
		check(expedition.state.hull == Ships.PLAYERS[index].hull_capacity, "Fresh expedition has full Hull")
		check(expedition.state.hull > 0 and expedition.view_kind != "defeat", "Fresh expedition is alive")
		var encounter: int = -1
		for slot in range(expedition.state.encounters.size()):
			if expedition.state.encounters[slot].kind == "battle":
				encounter = slot
				break
		check(encounter >= 0, "A battle is available in the generated system")
		if encounter >= 0:
			expedition.start_battle(encounter)
			var board = expedition.battle
			check(is_instance_valid(board), "Actual expedition battle is instantiated")
			if is_instance_valid(board):
				board.enemy_timer.stop()
				check(board.player_hull > 0 and board.winner.is_empty(), "Battle starts alive with no terminal result")
				check(board.player_ship_data == Ships.PLAYERS[index], "Battle retains the selected profile")
				check(board.hand.cards.size() == 6, "Battle deals six cards")
				var model = board.get_node("BattleView/Viewport/Battlefield/PlayerShip")
				check(model.get_node("Body/Hull").mesh != null, "Battle player mesh exists")
		expedition.queue_free()
		await settle()
	print("Startup flow: %d checks, %d failures; packed=%s" % [checks, failures, ProjectSettings.globalize_path("res://").ends_with(".pck")])
	quit(1 if failures else 0)
