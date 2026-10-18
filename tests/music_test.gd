extends SceneTree
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	await process_frame
	var music = root.get_node("Music")
	var original: bool = music.enabled
	music.play_starmap()
	check(music.current_track == "starmap", "Exploration track selected without audio assets")
	var first_player = music.player
	music.play_starmap()
	check(music.player == first_player, "One persistent audio player")
	music.play_battle()
	check(music.current_track in ["battle1", "battle2"], "Battle selects one of two tracks")
	music.play_result(true)
	check(music.current_track == "victory", "Victory replaces battle music")
	music.play_result(false)
	check(music.current_track.is_empty() and not music.player.playing, "Escape/defeat stop battle music")
	var script = load("res://scripts/ui/music_button.gd")
	var first = script.new()
	var second = script.new()
	root.add_child(first)
	root.add_child(second)
	music.set_enabled(false)
	check(not first.button_pressed and not second.button_pressed, "Both controls reflect mute")
	first.pressed.emit()
	check(music.enabled and first.button_pressed and second.button_pressed, "Toggle synchronizes both controls")
	music.play_starmap()
	check(music.enabled and music.current_track == "starmap", "Music returns to exploration")
	music.set_enabled(original)
	first.queue_free()
	second.queue_free()
	print("Music: %d failures" % failures)
	quit(1 if failures else 0)
