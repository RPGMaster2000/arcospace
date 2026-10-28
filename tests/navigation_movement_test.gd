extends SceneTree
const Navigation = preload("res://scripts/expedition/navigation_state.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var navigation = Navigation.new()
	var distances: Array[float] = []
	navigation.movement_advanced.connect(func(distance): distances.append(distance))
	check(navigation.checkpoint_position([0,0,0]) and distances.is_empty(), "Checkpoint establishes origin without advancing")
	navigation.begin([30,0,40])
	check(is_equal_approx(navigation.report_movement([3,0,4]),5.0) and distances==[5.0], "Only actual positive world displacement is reported")
	check(navigation.report_movement([3,0,4])==0 and distances.size()==1, "Repeated sample cannot advance twice")
	var valid_position: Array = navigation.position.duplicate()
	for invalid in [[],[1,2],[1,2,3,4],[NAN,0,0],[INF,0,0],["3",0,4],[10001,0,0]]:
		check(navigation.report_movement(invalid)==0 and navigation.position==valid_position and distances.size()==1, "Malformed or nonfinite movement is rejected without mutation")
	check(not navigation.checkpoint_position([0,NAN,0]) and navigation.position==valid_position, "Invalid checkpoint cannot corrupt the save position")
	navigation.rebase_movement()
	check(navigation.position==valid_position, "Clearing the transient baseline preserves the authoritative save position")
	check(navigation.report_movement([1000,0,0])==0 and distances.size()==1, "First sample after discontinuity never catches up hidden displacement")
	check(navigation.report_movement([1003,0,4])==5 and distances.size()==2, "Subsequent continuous motion resumes reporting")
	var data: Dictionary = navigation.snapshot()
	check(not data.has("_movement_position") and not data.has("distance"), "Sampling baseline and cumulative effects are not duplicate serialized state")
	var restored = Navigation.new()
	restored.checkpoint_position([-1000,0,0])
	check(restored.restore(data), "Navigation position and target roundtrip")
	var restored_distances: Array[float] = []
	restored.movement_advanced.connect(func(distance): restored_distances.append(distance))
	check(restored.report_movement([9000,0,0])==0 and restored_distances.is_empty(), "Restore clears even a previously primed baseline")
	navigation.stop()
	valid_position = navigation.position.duplicate()
	check(navigation.report_movement([2000,0,0])==0 and navigation.position==valid_position, "Idle movement cannot advance or rewrite authoritative position")

	# Real coordinator gating, without live tween/frame timing obscuring sample boundaries.
	var host = preload("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.chasedown_chance = 0.0
	host.rules.pressure_chasedown_increment = 0.0
	root.add_child(host)
	await process_frame
	await process_frame
	host.set_process(false)
	var map = host.star_map
	map.set_process(false)
	map.camera.cancel()
	host.phase = host.Phase.TRAVELING
	map.focused = false
	map.traveling = true
	host.state.navigation.begin([3000,0,0])
	host.state.update_navigation_position([0,0,0])
	var reported: Array[float] = []
	host.state.navigation.movement_advanced.connect(func(distance): reported.append(distance))
	map.ship.position = Vector3(3,0,4)
	host._sample_navigation_position()
	check(reported==[5.0], "Travel phase, moving map and eligible UI report actual movement")
	map.camera.position += Vector3(10,5,10)
	host._sample_navigation_position()
	check(reported==[5.0], "Camera movement alone never advances navigation consumers")
	valid_position = host.state.navigation.position.duplicate()
	map.traveling = false
	map.ship.position = Vector3(50,0,0)
	host._sample_navigation_position()
	check(reported.size()==1 and host.state.navigation.position==valid_position, "Stopped map cannot advance despite a stale active leg")
	map.traveling = true
	map.ship.position = Vector3(100,0,0)
	host._sample_navigation_position()
	check(reported.size()==1, "Returning to movement rebases without catchup")
	map.ship.position.x += 1
	host._sample_navigation_position()
	check(reported.back()==1.0 and reported.size()==2, "Continuous movement resumes after rebasing")
	for blocked_phase in [host.Phase.OVERVIEW,host.Phase.DESTINATION,host.Phase.CHASEDOWN,host.Phase.BATTLE_ENTRY,host.Phase.BATTLE,host.Phase.FTL,host.Phase.INTRO,host.Phase.REWARD]:
		var previous_count: int = reported.size()
		valid_position = host.state.navigation.position.duplicate()
		host.phase = blocked_phase
		map.ship.position.x += 100
		host._sample_navigation_position()
		check(reported.size()==previous_count and host.state.navigation.position==valid_position, "Non-travel phases cannot accrue distance or save cinematic transforms")
		host.phase = host.Phase.TRAVELING
		map.ship.position.x += 100
		host._sample_navigation_position()
		check(reported.size()==previous_count, "Phase restoration never catches up blocked motion")
	var previous_count: int = reported.size()
	host.settings_button.menu.shade.show()
	map.ship.position.x += 100
	host._sample_navigation_position()
	host.settings_button.menu.shade.hide()
	map.ship.position.x += 100
	host._sample_navigation_position()
	check(reported.size()==previous_count, "Modal open and close cannot accrue or catch up distance")
	paused = true
	map.ship.position.x += 100
	host._sample_navigation_position()
	paused = false
	map.ship.position.x += 100
	host._sample_navigation_position()
	check(reported.size()==previous_count, "Pause and resume cannot accrue or catch up distance")
	map.focused = true
	map.ship.position.x += 100
	host._sample_navigation_position()
	map.focused = false
	host._sample_navigation_position()
	check(reported.size()==previous_count, "Focused cinematic transforms are excluded")
	map.ship.position.x += 5
	var checkpoint: Vector3 = map.ship.position
	check(host._save_progress() and reported.size()==previous_count and host.state.navigation.position==[checkpoint.x,checkpoint.y,checkpoint.z], "Saving checkpoints actual travel position without advancing movement")
	map.ship.position.x += 1
	host._sample_navigation_position()
	check(reported.size()==previous_count+1 and reported.back()==1.0, "Post-save sampling counts only displacement after checkpoint")
	previous_count = reported.size()
	map.ship.position.x += 2
	host._begin_free_travel(Vector3(3500,0,0))
	check(reported.size()==previous_count+1 and reported.back()==2.0, "Redirect reports only the outstanding actual segment before changing target")
	host._sample_navigation_position()
	check(reported.size()==previous_count+1, "Changing destination does not itself add distance")
	map.traveling = false
	map.ship.position.x += 3
	var final_point: Vector3 = map.ship.position
	var pressure: int = host.state.pressure
	host._free_arrived()
	check(reported.size()==previous_count+2 and reported.back()==3.0, "Validated arrival includes the final small actual movement segment")
	check(not host.state.navigation.leg_active and host.state.navigation.position==[final_point.x,final_point.y,final_point.z] and host.state.pressure==pressure, "Arrival checkpoints final position without new gameplay effects")
	host.free()
	print("Navigation movement: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
