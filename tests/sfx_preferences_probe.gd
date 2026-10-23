extends SceneTree
# Fresh process companion for sfx_test.gd; not a separately discovered test.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await process_frame
	var sfx: Node = root.get_node("Sfx")
	var music: Node = root.get_node("Music")
	var valid: bool = is_equal_approx(sfx.volume, 0.37) and is_equal_approx(music.volume, 0.42)
	valid = valid and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX")), linear_to_db(0.37) - 8.0)
	valid = valid and is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), linear_to_db(0.42))
	quit(0 if valid else 1)
