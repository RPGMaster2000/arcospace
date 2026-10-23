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
	check(music.current_track == "starsystem", "Star system track selected")
	check(is_equal_approx(db_to_linear(music.player.volume_db - music.BASE_VOLUME_DB), 1.5), "Star system music is fifty percent louder")
	var first_player = music.player
	music.play_starmap()
	check(music.player == first_player, "One persistent audio player")
	music.play_battle()
	check(music.current_track in ["battle1", "battle2", "battle3"], "Battle selects one of three tracks")
	music.play_result(true)
	check(music.current_track == "victory_normal", "Victory replaces battle music")
	music.play_result(false)
	check(music.current_track.is_empty() and not music.player.playing, "Defeat stops battle music")
	for rank in range(3):
		music.play_battle()
		music.play_result(true, rank)
		check(music.current_track == ("victory_normal" if rank == 0 else "victory_special"), "Victory follows enemy tier")
		check(music.player.playing and not music.player.stream.loop, "Victory plays once")
	var seen: Dictionary = {}
	for n in range(100):
		music.play_battle()
		seen[music.current_track] = true
	check(seen.size() == 3, "All three battle tracks are selectable")
	for track in music.TRACKS:
		music.play_track(track)
		check(music.player.stream is AudioStreamMP3 and music.player.playing, "MP3 loads: " + track)
		check(music.player.stream.loop == not track.begins_with("victory_"), "Only victory cues are one-shots: " + track)
	music.play_title()
	music.fade_title(0.05)
	await music.fade_tween.finished
	check(music.current_track.is_empty() and not music.player.playing, "Title fade stops at silence")
	music.play_title()
	music.fade_title(0.05)
	music.play_ship_selection()
	await create_timer(0.15).timeout
	check(music.current_track == "shipselect" and music.player.playing and music.player.volume_db == music.BASE_VOLUME_DB, "Old title fade cannot stop the next track")
	var script = load("res://scripts/ui/settings_button.gd")
	var first = script.new()
	var second = script.new()
	root.add_child(first)
	root.add_child(second)
	music.set_enabled(false)
	check(not first.menu.music_toggle.button_pressed and not second.menu.music_toggle.button_pressed, "Both controls reflect mute")
	first.menu.music_toggle.button_pressed = true
	check(music.enabled and first.menu.music_toggle.button_pressed and second.menu.music_toggle.button_pressed, "Toggle synchronizes both controls")
	music.play_starmap()
	check(music.enabled and music.current_track == "starsystem", "Music returns to exploration")
	music.set_enabled(original)
	first.queue_free()
	second.queue_free()
	print("Music: %d failures" % failures)
	quit(1 if failures else 0)
