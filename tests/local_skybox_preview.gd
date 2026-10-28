extends SceneTree
# Local visual preview; -- --capture saves all five views.
const VARIANTS = [
	["Galaxy / Standard", "battlefield_3d", 0],
	["Nebula", "battlefield_nebula", 4],
	["Ion Storm", "battlefield_ion_storm", 2],
	["Black Hole / Temporal Rift", "battlefield_temporal_rift", 5],
	["Ringed Giant / Planetary Orbit", "battlefield_planetary_orbit", 0]
]
var index := 0
var board: Node
var label: Label
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(400, 4)
	layer.add_child(panel)
	var row := HBoxContainer.new()
	panel.add_child(row)
	var previous := Button.new()
	previous.text = "<"
	previous.pressed.connect(func(): show_variant(posmod(index - 1, VARIANTS.size())))
	row.add_child(previous)
	label = Label.new()
	label.custom_minimum_size.x = 380
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(label)
	var next := Button.new()
	next.text = ">"
	next.pressed.connect(func(): show_variant((index + 1) % VARIANTS.size()))
	row.add_child(next)
	show_variant(0)
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://.local-skybox-test/captures")
		for i in VARIANTS.size():
			show_variant(i)
			await create_timer(2.0).timeout
			await RenderingServer.frame_post_draw
			var path := "res://.local-skybox-test/captures/%s.png" % VARIANTS[i][1]
			var result := root.get_texture().get_image().save_png(path)
			print("Skybox capture: ", path, " result=", result)
		quit()
func show_variant(next_index: int) -> void:
	index = next_index
	if is_instance_valid(board):
		root.remove_child(board)
		board.queue_free()
	board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {"player_ship": 0, "enemy_ship": 0, "modifier": VARIANTS[index][2]}
	board.normal_battlefield = load("res://scenes/%s.tscn" % VARIANTS[index][1])
	root.add_child(board)
	label.text = "%d/5  %s" % [index + 1, VARIANTS[index][0]]
func _process(_delta: float) -> bool:
	if Input.is_physical_key_pressed(KEY_ESCAPE):
		quit()
	return false
