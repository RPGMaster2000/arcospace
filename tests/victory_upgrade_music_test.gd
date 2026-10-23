extends SceneTree
var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	root.add_child(host)
	current_scene = host
	host._remove_battle()
	host.state.active_battle = -1
	var music = root.get_node("Music")
	for rank in [0, 1, 2]:
		var expected: String = "victory_normal" if rank == 0 else "victory_special"
		host.state.start_upgrade_event(2)
		music.play_result(true, rank)
		var original_stream = music.player.stream
		host.show_system()
		check(host.view_kind == "outcome" and music.current_track == expected and music.player.stream == original_stream, "Victory survives entering upgrades")
		var candidate: Resource = host.state.upgrade_candidates()[0]
		host._upgrade(candidate.identity_key())
		check(music.current_track == expected and music.player.stream == original_stream, "Victory survives card upgrade without restarting")
		while host.state.pending_choice == "upgrade":
			host._upgrade(host.state.upgrade_candidates()[0].identity_key())
		check(music.current_track == expected, "Victory continues through reward confirmation")
		host.show_system()
		check(music.current_track == "starsystem", "Map music starts only on returning after upgrades")
	host.queue_free()
	await process_frame
	print("Victory upgrade music: %d failures" % failures)
	quit(1 if failures else 0)
