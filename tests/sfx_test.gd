extends SceneTree
# Catalog, bounded playback, bus independence, persistence and presentation regression.
const Definition = preload("res://scripts/audio/sound_event.gd")
const Catalog = preload("res://scripts/audio/sound_catalog.gd")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const EXPECTED = [
	"card_select", "card_play", "card_discard", "materials_gain", "energy_gain", "crew_gain",
	"resource_drain", "production_gain", "production_loss", "shield_hit", "shield_break",
	"hull_hit", "hull_repair", "ship_destroyed", "systems_failure_warning",
	"systems_failure_defeat", "emp_charge", "emp_ready", "emp_fire", "ship_departure",
	"ui_select", "ui_confirm", "upgrade_acquired", "result_reveal"
]
var checks: int = 0
var failures: int = 0
var sfx: Node
var music: Node


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func reset_audio() -> void:
	sfx.stop_all()
	sfx._last_played.clear()
	sfx._ui_confirm_frame = -10


func heard(event: StringName) -> bool:
	return sfx._last_played.has(event)


func active(event: StringName = &"") -> int:
	var count: int = 0
	for player in sfx.players:
		if player.playing and (event == &"" or player.get_meta(&"event", &"") == event):
			count += 1
	return count


func make_board() -> Node:
	var board = load("res://scenes/board.tscn").instantiate()
	board.setup_settings = {"player_ship": 0, "enemy_ship": 0, "modifier": 0}
	root.add_child(board)
	board.enemy_timer.stop()
	board.get_node("ModifierDisplay").cinematic_enabled = false
	return board


func run() -> void:
	await process_frame
	sfx = root.get_node("Sfx")
	music = root.get_node("Music")
	var original_catalog: Resource = sfx.catalog
	var original_sfx: float = sfx.volume
	var original_music: float = music.volume
	var original_enabled: bool = music.enabled
	var saved := ConfigFile.new()
	var had_settings: bool = saved.load(Preferences.PATH) == OK
	sfx.catalog = original_catalog.duplicate(true)
	sfx.set_volume(1.0, false)
	music.set_volume(1.0, false)
	music.set_enabled(true)
	reset_audio()
	check(sfx.catalog.events.size() == EXPECTED.size(), "Exactly 24 stable events")
	var ids: Dictionary = {}
	var files: int = 0
	for id in EXPECTED:
		var event: Resource = sfx.catalog.find_event(id)
		check(event != null and not ids.has(id), "Unique event maps: " + id)
		ids[id] = true
		if event == null: continue
		check(event.enabled and not event.streams.is_empty(), "Enabled catalog mapping: " + id)
		for stream in event.streams:
			check(stream is AudioStreamWAV and stream.get_length() > 0.0 and ResourceLoader.exists(stream.resource_path), "Imported WAV: " + id)
			check(stream.resource_path.get_file().begins_with(id + "_"), "Correct authored mapping: " + id)
			files += 1
	check(files == 38, "38 authored files including seven triplets")
	check(sfx.players.size() == 12, "Fixed twelve-player pool")
	var sfx_bus: int = AudioServer.get_bus_index(&"SFX")
	check(AudioServer.get_bus_effect_count(sfx_bus) == 1 and AudioServer.get_bus_effect(sfx_bus, 0) is AudioEffectLimiter and AudioServer.is_bus_effect_enabled(sfx_bus, 0), "SFX safety limiter enabled")
	for id in [&"emp_ready", &"emp_fire", &"systems_failure_warning", &"systems_failure_defeat", &"result_reveal"]:
		check(sfx.catalog.find_event(id).pitch_variation == 0.0, "Recognizable cue has stable pitch: " + str(id))
	check(not sfx.play_event(&"missing_event", root), "Unknown mapping is silent")
	var event: Resource = sfx.catalog.find_event(&"card_play")
	var originals: Array[AudioStream] = event.streams.duplicate()
	event.streams.assign([null])
	check(not sfx.play_event(&"card_play", root), "Missing/null replacement is silent")
	event.streams.clear()
	check(not sfx.play_event(&"card_play", root), "Unassigned stream is silent")
	event.streams = originals.duplicate()
	event.enabled = false
	check(not sfx.play_event(&"card_play", root), "Disabled event does not play")
	event.enabled = true
	var replacement := AudioStreamWAV.new()
	replacement.mix_rate = 48000
	replacement.format = AudioStreamWAV.FORMAT_16_BITS
	replacement.data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	event.streams.assign([replacement])
	check(sfx.play_event(&"card_play", root), "Replacing only AudioStream still plays")
	var found: bool = false
	for player in sfx.players:
		found = found or (player.stream is AudioStreamWAV and player.stream.data == replacement.data)
	check(found, "Player uses replacement audio data")
	event.streams = originals.duplicate()
	reset_audio()
	seed(314159)
	var expected_rng: Array = [randi(), randi(), randi()]
	seed(314159)
	var first: int = randi()
	sfx.play_event(&"card_play", root)
	check([first, randi(), randi()] == expected_rng, "Audio selection/pitch leaves global combat RNG untouched")
	check(not sfx.play_event(&"card_play", root), "Replay interval rejects spam")
	event.replay_interval = 0.0
	check(sfx.play_event(&"card_play", root), "Second allowed concurrent voice")
	check(not sfx.play_event(&"card_play", root) and active(&"card_play") == 2, "Event concurrency limit enforced")
	var variants_seen: Dictionary = {}
	for trial in range(60):
		reset_audio()
		sfx.play_event(&"card_play", root)
		for player in sfx.players:
			if player.playing:
				variants_seen[hash(player.stream.data)] = true
				check(player.pitch_scale >= 0.975 and player.pitch_scale <= 1.025, "Pitch stays inside configured limits")
	check(variants_seen.size() == 3, "All three authored variants used")
	reset_audio()
	# Six event definitions fill the pool; alerts must preempt a lower-priority voice.
	for id in [&"card_play", &"shield_hit", &"hull_repair", &"production_gain", &"production_loss", &"shield_break"]:
		var definition: Resource = sfx.catalog.find_event(id)
		definition.replay_interval = 0.0
		check(sfx.play_event(id, root) and sfx.play_event(id, root), "Fill two voices: " + str(id))
	check(active() == 12, "Global pool bound reached")
	check(sfx.play_event(&"emp_fire", root) and active() == 12 and active(&"emp_fire") == 1, "High priority preempts without growing pool")
	check(not sfx.play_event(&"ui_select", root), "Low priority cannot displace critical audio")
	reset_audio()
	check(sfx.play_event(&"materials_gain", root), "Resource income sound")
	check(not sfx.play_event(&"energy_gain", root) and not sfx.play_event(&"crew_gain", root), "Simultaneous income is grouped")
	reset_audio()
	var scope := Node.new()
	root.add_child(scope)
	sfx.play_event(&"ship_departure", scope)
	check(active() == 1, "Scoped voice starts")
	scope.free()
	check(active() == 0, "Scene owner exit stops voices immediately")
	var screen := Node.new()
	root.add_child(screen)
	current_scene = screen
	var button := Button.new()
	screen.add_child(button)
	sfx.bind_button(button)
	button.pressed.emit()
	button.free()
	await process_frame
	check(active(&"ui_confirm") == 1, "Rebuilding a panel preserves its UI confirmation tail")
	screen.free()
	check(active() == 0, "Leaving UI screen stops confirmation tails")
	music.play_ship_selection()
	sfx.set_volume(0.0)
	check(not sfx.play_event(&"card_play", root) and music.player.playing and not music.player.stream_paused, "SFX mute leaves Music playing")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"SFX")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "SFX bus independent")
	sfx.set_volume(0.37)
	music.set_volume(0.42)
	music.set_enabled(false)
	check(sfx.play_event(&"card_play", root) and music.player.stream_paused, "Music toggle leaves SFX audible")
	reset_audio()
	music.set_enabled(true)
	music.set_volume(0.0)
	check(sfx.play_event(&"card_play", root) and AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Music")), "Music slider mute leaves SFX")
	music.set_volume(0.42)
	var probe := ConfigFile.new()
	probe.load(Preferences.PATH)
	check(is_equal_approx(float(probe.get_value("sfx", "volume")), 0.37) and is_equal_approx(float(probe.get_value("music", "volume")), 0.42), "Both volume values persisted")
	# Fresh process proves autoload startup reads persisted gains, not just in-memory values.
	var output: Array = []
	var arguments: PackedStringArray = ["--headless", "--audio-driver", "Dummy"]
	var launch_arguments: PackedStringArray = OS.get_cmdline_user_args()
	var pack_index: int = launch_arguments.find("--probe-pack")
	if pack_index >= 0:
		arguments.append_array(["--main-pack", launch_arguments[pack_index + 1]])
	else:
		arguments.append_array(["--path", ProjectSettings.globalize_path("res://")])
	arguments.append_array(["--script", "res://tests/sfx_preferences_probe.gd"])
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	check(exit_code == 0, "Volumes restored across process restart: " + str(output))
	music.set_volume(1.0, false)
	sfx.set_volume(1.0, false)
	reset_audio()
	var board = make_board()
	reset_audio()
	# Same committed presentation boundary used by normal cards and battlefield hazards.
	var before: Dictionary = board._both_states()
	var after: Dictionary = before.duplicate(true)
	after.enemy.shields -= 2
	board.battle_effects.play_changes(before, after, "", "", 0, true)
	check(heard(&"shield_hit"), "Shield hit delta")
	reset_audio()
	after.enemy.shields = 0
	board.battle_effects.play_changes(before, after)
	check(heard(&"shield_break"), "Shield collapse delta")
	reset_audio()
	after = before.duplicate(true)
	after.player.hull -= 2
	board.battle_effects.play_changes(before, after)
	check(heard(&"hull_hit"), "Hull damage delta")
	reset_audio()
	after = before.duplicate(true)
	after.player.hull += 2
	board.battle_effects.play_changes(before, after)
	check(heard(&"hull_repair"), "Hull repair delta")
	reset_audio()
	after = before.duplicate(true)
	after.enemy.reactor -= 1
	board.battle_effects.play_changes(before, after)
	check(heard(&"production_loss"), "Sabotage production delta")
	reset_audio()
	after = before.duplicate(true)
	after.enemy.hull = 0
	board.battle_effects.play_changes(before, after)
	check(heard(&"ship_destroyed"), "Ship destruction delta")
	reset_audio()
	var failure = board.get_node("SystemsFailureDisplay")
	var status = {"player": {"remaining": 3, "offline": ["reactor", "quarters"]}, "enemy": {"remaining": -1, "offline": []}}
	failure.refresh(status)
	check(heard(&"systems_failure_warning"), "Failure activation edge")
	reset_audio()
	for n in range(5): failure.refresh(status)
	check(active() == 0, "Repeated failure refresh is silent")
	status.player.remaining = 2
	failure.refresh(status)
	check(active() == 0, "Ordinary countdown update is silent")
	status.player = {"remaining": -1, "offline": []}
	failure.refresh(status)
	check(heard(&"production_gain"), "Failure recovery feedback")
	reset_audio()
	board.ftl.charge += 1
	board.refresh_display()
	check(heard(&"emp_charge"), "EMP charging increment")
	reset_audio()
	board.ftl.charge = board.ftl.charge_target
	board.refresh_display()
	check(heard(&"emp_ready"), "EMP reaches readiness")
	reset_audio()
	for n in range(5): board.refresh_display()
	check(active() == 0, "Repeated ready HUD refresh is silent")
	# Release presentation jobs before the guarded action.
	if board.battle_effects.busy: await board.battle_effects.finished
	board.resolving_card = false
	board._warp_out()
	check(heard(&"emp_fire"), "EMP activation presentation")
	reset_audio()
	for n in range(5): board.refresh_display()
	check(active() == 0, "Repeated escaped HUD refresh is silent")
	board.free()
	board = make_board()
	reset_audio()
	var motion = board.get_node("CardMotion")
	motion.settings = motion.settings.duplicate()
	motion.settings.travel_seconds = 0.01
	motion.settings.hold_seconds = 0.01
	motion.settings.exit_seconds = 0.01
	motion.settings.refill_seconds = 0.01
	motion.settings.discard_seconds = 0.01
	var card = preload("res://scripts/cards/card_library.gd").CARDS[0]
	var card_view = board.get_node(board.card_slots[0])
	card_view.set_playable(true)
	card_view.set_interaction_emphasis(true, true)
	check(heard(&"card_select"), "Card selected edge")
	reset_audio()
	card_view.set_interaction_emphasis(true, true)
	check(not heard(&"card_select"), "Repeated card emphasis is silent")
	card_view.set_interaction_emphasis(false, false)
	var resolved: Array = []
	motion.animate_action(card, null, "player", false, func(): resolved.append(true))
	check(not heard(&"card_play"), "Card play waits for arrival")
	await motion.step_finished
	await process_frame
	check(heard(&"card_play") and resolved.size() == 1, "Card play cue resolves once at arrival")
	await create_timer(0.15).timeout
	reset_audio()
	await motion.animate_action(card, null, "player", true, func(): resolved.append(true))
	check(heard(&"card_discard") and resolved.size() == 2, "Card scanner discard cue")
	reset_audio()
	if board.battle_effects.busy: await board.battle_effects.finished
	board.resolving_card = false
	board.winner = "player"
	board.refresh_display()
	check(heard(&"result_reveal"), "Result reveal accent")
	reset_audio()
	for n in range(5): board.refresh_display()
	check(active() == 0, "Repeated result HUD is silent")
	board.free()
	board = make_board()
	reset_audio()
	board.winner = "enemy"
	board.result_cause = "systems_failure"
	board.battle_effects.busy = false
	board.resolving_card = false
	board.refresh_display()
	check(heard(&"systems_failure_defeat"), "Critical shutdown on failure result")
	board.free()
	reset_audio()
	var menu = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	menu.showcase._stop_tween()
	menu.showcase.phase = menu.showcase.Phase.SHIP_SELECTION
	menu._selection_ready()
	reset_audio()
	menu._navigate(1)
	check(heard(&"ui_select"), "Ship navigation cue")
	reset_audio()
	menu.start_button.pressed.emit()
	await process_frame
	check(heard(&"ui_confirm"), "Ship selection confirmation")
	# Starting may create a save; isolated regression userdata is disposable.
	menu.free()
	await process_frame
	check(active() == 0, "Menu transition releases all owned voices")
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	root.add_child(host)
	current_scene = host
	host._remove_battle()
	host.state.active_battle = -1
	host.state.start_upgrade_event(2)
	host.show_system()
	reset_audio()
	var candidate: Resource = host.state.upgrade_candidates()[0]
	host._upgrade(candidate.identity_key())
	check(heard(&"upgrade_acquired"), "Accepted upgrade plays progression cue")
	host.free()
	reset_audio()
	# Test departure timing directly without advancing expedition state.
	var cinematic = load("res://scenes/main_menu_3d.tscn").instantiate()
	root.add_child(cinematic)
	cinematic._stop_tween()
	cinematic.phase = cinematic.Phase.SHIP_SELECTION
	cinematic.skip_cinematics = false
	cinematic.populate([preload("res://scripts/ships/ship_library.gd").PLAYERS[0]])
	cinematic.select_ship(0, true)
	cinematic.orientation_duration = 0.01
	cinematic.departure_pause_duration = 0.01
	reset_audio()
	cinematic.depart()
	await create_timer(0.3).timeout
	check(heard(&"ship_departure"), "Departure spool follows alignment")
	cinematic.free()
	reset_audio()
	sfx.catalog = original_catalog
	sfx.set_volume(original_sfx, false)
	music.set_volume(original_music, false)
	music.set_enabled(original_enabled)
	if had_settings: saved.save(Preferences.PATH)
	else: DirAccess.remove_absolute(Preferences.PATH)
	print("SFX: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
