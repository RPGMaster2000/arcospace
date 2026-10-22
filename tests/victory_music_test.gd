extends SceneTree
var failures: int = 0
var checks: int = 0
var music: Node
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func make_board() -> Node:
	var board = load("res://scenes/board_3d.tscn").instantiate()
	board.setup_settings = {"player_ship":0,"enemy_ship":0,"modifier":0}
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
	board.get_node("CardMotion").settings.enabled = false
	board.get_node("ModifierDisplay").cinematic_enabled = false
	root.add_child(board)
	return board
func run() -> void:
	await process_frame
	music = root.get_node("Music")
	var was_enabled: bool = music.enabled
	music.set_enabled(true)
	for method in ["destruction","systems"]:
		var board = make_board()
		check(music.current_track in ["battle1","battle2"], "Battle music starts normally")
		board.resolving_card = true
		board.battle_effects.busy = true
		if method == "destruction": board.enemy_hull = 0
		else:
			board.enemy_quarters = 0
			board.enemy_reactor = 0
			board._sync_systems_failure()
			board.systems_failure.remaining.enemy = 0
		check(board._check_winner(), "Real win detected")
		board.refresh_display()
		check(board.result_recorded and not board.get_node("MatchResult").visible, "Rewards record while final animation is running")
		check(not board.result_music_started and music.current_track in ["battle1","battle2"], "Intro does not run behind hidden result screen")
		await create_timer(0.15).timeout
		board.battle_effects.busy = false
		board.refresh_display()
		check(not board.result_music_started, "Card animation still holds result music")
		board.resolving_card = false
		board.refresh_display()
		check(board.get_node("MatchResult").visible and board.result_music_started and music.current_track == "victory", "Victory starts on result reveal")
		check(music.player.stream is AudioStreamMP3 and music.player.playing, "Actual MP3 loaded and playing")
		check(not music.player.stream.loop and music.player.stream.loop_offset == 0, "Victory is a one-shot with no imported loop offset")
		check(music.player.get_playback_position() < 0.1, "Victory begins at zero")
		await create_timer(0.25).timeout
		var position: float = music.player.get_playback_position()
		check(position > 0.1, "Playback advances with the audio mixer")
		for n in range(5): board.refresh_display()
		music.play_result(true)
		check(music.player.get_playback_position() >= position - 0.05, "Repeated refresh/result request does not restart the intro")
		board.queue_free()
		await process_frame
	var escape = make_board()
	escape.ftl.charge = escape.ftl.charge_target
	escape._warp_out()
	check(escape.escaped_by_ftl and escape.result_music_started and music.current_track == "victory" and music.player.playing, "EMP success plays victory music too")
	escape.queue_free()
	await process_frame
	for outcome in ["enemy","draw"]:
		var board = make_board()
		board.winner = outcome
		board.refresh_display()
		check(board.result_music_started and music.current_track.is_empty() and not music.player.playing, "Loss/draw stop battle music without victory")
		board.queue_free()
		await process_frame
	music.set_enabled(false)
	var muted = make_board()
	muted.enemy_hull = 0
	muted._check_winner()
	muted.refresh_display()
	check(music.current_track == "victory" and music.player.stream_paused, "Muted wins respect the shared setting")
	await create_timer(0.15).timeout
	music.set_enabled(true)
	check(music.player.get_playback_position() < 0.1 and not music.player.stream_paused, "Unmuting retains the unplayed intro")
	muted.queue_free()
	await process_frame
	music.play_starmap()
	check(music.current_track == "starmap" and music.player.playing, "Returning to map resumes exploration music")
	music.set_enabled(was_enabled)
	print("Victory music: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
