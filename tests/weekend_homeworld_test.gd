extends SceneTree
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Sequence = preload("res://scripts/presentation/star_system/homeworld_sequence.gd")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _initialize() -> void: call_deferred("run")
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/weekend")
	root.get_texture().get_image().save_png("res://.godot/testlogs/weekend/"+label+"-"+RenderingServer.get_current_rendering_method()+".png")
func run() -> void:
	root.size = Vector2i(1280,720)
	var rules: Resource = Rules.duplicate(true)
	rules.game_mode = "defense"
	rules.log_rolls = false
	var state := State.new()
	state.start(0,rules,1042)
	var observed: Dictionary = {}
	state.defense_advanced.connect(func(event): observed.merge(event,true))
	# One imminent non-mothership arrival, with all other strategic events distant.
	var unit: Dictionary = state.defense.units[0]
	unit.position = state.defense.home+Vector3(0.01,0,0)
	state._commit_activity_time(1)
	check(observed.get("homeworld_damage",0) > 0,"Damage event originates from committed simulation")
	check(observed.get("integrity_after",-1) == state.defense.integrity,"Damage is immediate before any presentation")
	var sequence := Sequence.new()
	sequence.record(state,observed)
	sequence.record(state,{"homeworld_damage":12,"integrity_before":state.defense.integrity,"integrity_after":state.defense.integrity-12})
	check(sequence.pending.damage == observed.homeworld_damage+12 and sequence.pending.before == observed.integrity_before,"Deferred impacts consolidate before/after without calculating gameplay damage")
	sequence.free()
	var committed := Save.encode(state)
	check(Save.new().decode(committed,rules).defense.integrity == state.defense.integrity,"Restore keeps damage with no presentation reapplication")
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.resume_data = {"state":state,"battle":{}}
	root.add_child(host)
	for frame in range(12): await process_frame
	var deadline := Time.get_ticks_msec()+3000
	while host.star_map.camera.motion and host.star_map.camera.motion.is_running() and Time.get_ticks_msec() < deadline: await process_frame
	var map: Control = host.star_map
	await capture("system-overview")
	var pan_before: Vector2 = map.camera.pan_offset
	map.camera.pan_offset += Vector2(75,0)
	for frame in range(4): await process_frame
	await capture("player-offscreen")
	map.camera.pan_offset = pan_before
	for frame in range(4): await process_frame
	var before: Transform3D = map.camera.transform
	var ship_before: Vector3 = map.ship.position
	var clock: float = state.defense.pressure
	var rng_before: int = state.rng.state
	# A live journey is paused, retaining the original tween and destination.
	state.begin_free_travel(State.Defense.wire(ship_before+Vector3(4,0,0)))
	host.phase = host.Phase.TRAVELING
	map.traveling = true
	map.motion = map.create_tween()
	map.motion.tween_property(map.ship,"position",ship_before+Vector3(4,0,0),2)
	var journey: Tween = map.motion
	host.homeworld_sequence.record(state,observed)
	host.phase = host.Phase.BATTLE
	host._present_homeworld_damage()
	check(not host.homeworld_sequence.active and not host.homeworld_sequence.pending.is_empty(),"Battle phase defers impacts without consuming the queue")
	host.phase = host.Phase.TRAVELING
	host._present_homeworld_damage()
	check(host.homeworld_sequence.active and not journey.is_running(),"Damage presentation pauses original travel tween")
	check(host.phase == host.Phase.INTRO and not host._map_input_allowed(),"Cinematic blocks strategic sampling and duplicate navigation")
	await create_timer(0.6).timeout
	check(state.defense.pressure == clock and map.ship.position == ship_before,"Camera impacts do not advance strategic time or move ship")
	await capture("homeworld-damage")
	var deadline2 := Time.get_ticks_msec()+5000
	while host.homeworld_sequence.active and Time.get_ticks_msec() < deadline2: await process_frame
	check(not host.homeworld_sequence.active and map.motion == journey and journey.is_running(),"Travel resumes same tween without reroll or restart")
	check(map.camera.transform.is_equal_approx(before),"Original camera framing restored exactly")
	check(state.rng.state == rng_before,"Damage cinematic never consumes gameplay RNG")
	check(host.homeworld_sequence.pending.is_empty(),"Presented events consumed once")
	journey.pause()
	host.phase = host.Phase.OVERVIEW
	var persistence = preload("res://scripts/expedition/expedition_persistence.gd").new()
	persistence.store.path = "user://weekend-terminal-test.json"
	check(persistence.store.save_run(state),"Pre-terminal checkpoint is valid")
	state.defense.integrity = 0
	state.run_ended = true
	check(Sequence.defeat_subtitle(state) == "Homeworld defenses have collapsed.","Integrity depletion has distinct cause")
	var mother: Dictionary = state.defense.unit_for(state.defense.mothership_index())
	mother.status = "arrived"
	state.defense.integrity = 50
	check(Sequence.defeat_subtitle(state) == "Enemy forces have captured the homeworld.","Conquest does not require zero integrity")
	check(persistence.save_progress(state,null) and persistence.store.load_run().is_empty(),"Terminal state clears Continue slot independently of cinematic")
	host.show_system()
	await create_timer(0.6).timeout
	check(host.homeworld_sequence.terminal and host.homeworld_sequence.active,"Terminal defeat takes presentation priority")
	check(map.visible and not host._map_input_allowed(),"Defeat retains rendered map and cannot resume navigation")
	await capture("homebase-lost")
	host.queue_free()
	for frame in range(4): await process_frame
	print("Weekend homeworld: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
