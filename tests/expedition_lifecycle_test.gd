extends SceneTree
const Scene = preload("res://scenes/expedition.tscn")
const Save = preload("res://scripts/persistence/expedition_save.gd")
var failures: int = 0
var checks: int = 0
var results: Array[bool] = []
var activations: int = 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func host(map_3d: bool = true, map_enabled: bool = true) -> Node:
	var node = Scene.instantiate()
	node.persistence_enabled = false
	node.use_3d_star_map = map_3d
	node.use_star_map = map_enabled
	node.rules = node.rules.duplicate(true)
	node.rules.debug_seed = 1042
	node.rules.log_rolls = false
	node.star_system_settings = node.star_system_settings.duplicate()
	node.star_system_settings.camera_duration = 0.04
	node.star_system_settings.battle_zoom_duration = 0.12
	node.star_system_settings.white_fade_duration = 0.02
	node.star_system_settings.departure_duration = 0.08
	node.star_system_settings.departure_turn_duration = 0.04
	node.star_system_settings.result_suspense_duration = 0.12
	root.add_child(node)
	return node

func fade(layer: CanvasLayer, alpha: float, duration: float) -> void:
	results.append(await layer.fade(alpha, duration))

func enemy_index(node: Node) -> int:
	for index in range(node.state.encounters.size()):
		if node.state.encounters[index].kind == "battle": return index
	return -1

func poi(node: Node, index: int) -> void:
	var data = preload("res://encounters/mining_operation.tres")
	node.state.encounters[index] = {"kind":"poi", "poi":data, "title":data.title, "completed":false, "charge_awarded":false}

func run() -> void:
	var node = host()
	await process_frame
	fade(node.transition, 1.0, 0.3)
	await create_timer(0.02).timeout
	fade(node.transition, 0.0, 0.02)
	await create_timer(0.08).timeout
	check(results == [false, true] and not node.transition.curtain.visible, "Superseded fade wakes obsolete waiter without hiding its successor")
	poi(node, 0)
	node.show_system()
	node.star_map.travel_duration = 0.2
	node.star_map.travel(0)
	check(node.phase == node.Phase.TRAVELING, "Map intent changes presentation phase only")
	var committed: Dictionary = Save.encode(node.state)
	node._clear("outcome")
	await create_timer(0.3).timeout
	check(node.state.navigation_origin == -1 and node.view_kind == "outcome", "Cancelled travel never emits arrival over replacement view")
	check(Save.encode(node.state) == committed, "Cancelling presentation cannot alter committed travel state")
	node.start_expedition()
	poi(node, 0)
	poi(node, 1)
	node.show_poi(0)
	var salvage: int = node.state.salvage
	node._approach(0, 0, true)
	node._approach(0, 0, true)
	check(node.presenting_outcome and node.state.salvage == salvage + 3, "Suspense commits once, before delay")
	node.show_system()
	check(node.view_kind == "poi", "Ordinary return stays blocked during suspense")
	node.show_poi(1)
	var revision: int = node.screen.view_revision
	await create_timer(0.5).timeout
	check(node.view_kind == "poi" and node.selected_encounter == 1 and node.screen.view_revision == revision, "Same-run view replacement cancels stale suspense reveal")
	check(not node.return_button.disabled and not node.outcome_flash.active, "Replacement view releases input and flash")
	var stale: Button = node._button("old action", func(): activations += 1)
	node.show_system()
	stale.pressed.emit()
	check(activations == 0, "Detached old control cannot route a new view")
	poi(node, 0)
	node.show_poi(0)
	node._approach(0, 0, true)
	node.start_expedition()
	var fresh: Resource = node.state
	await create_timer(0.5).timeout
	check(node.state == fresh and node.view_kind == "system" and node.state.salvage == 0, "New run invalidates old result continuation")
	var before: int = node.state.system_number
	node.state.ftl_access = true
	node._jump()
	node._jump()
	check(node.transitioning and node.state.system_number == before, "Duplicate FTL requests share one owner")
	node.transition.cancel()
	await process_frame
	check(not node.transitioning and node.state.system_number == before and not node.transition.curtain.visible, "Cancelled FTL unlocks without progression")
	node._jump()
	await create_timer(0.35 + node.star_system_settings.introduction_duration*1.1).timeout
	check(node.state.system_number == before + 1 and node.phase == node.Phase.OVERVIEW, "FTL commits once and reveals overview")
	var index: int = enemy_index(node)
	node._enter_battle(index)
	node._enter_battle(index)
	node.start_expedition()
	await create_timer(0.35).timeout
	check(node.battle == null and node.state.active_battle == -1 and node._battle_marker.is_empty(), "New run cancels delayed battle initialization and checkpoint")
	index = enemy_index(node)
	node.start_battle(index, 998877)
	var board: Node = node.battle
	board.enemy_timer.stop()
	var checkpoint: Dictionary = node._battle_checkpoint.duplicate(true)
	node.start_battle(index, 998877)
	check(node.battle == board and node._battle_checkpoint == checkpoint and node.phase == node.Phase.BATTLE, "Duplicate start cannot replace a live battle or checkpoint")
	var stranger := Node.new()
	node._battle_finished(stranger)
	stranger.free()
	check(node.battle == board, "Completion from another source is ignored")
	board.battle_effects.enabled = false
	if board.battle_effects.busy: await board.battle_effects.finished
	board.enemy_hull = 0
	board._check_winner()
	board.refresh_display()
	board._continue_encounter()
	var earned: int = node.state.salvage
	var remaining: int = node.state.upgrades_remaining
	board.expedition_continue.emit()
	check(node.battle == null and node.state.salvage == earned and node.state.upgrades_remaining == remaining, "Duplicate completion cannot repeat result or reward")
	check(node.view_kind == "outcome" and remaining > 0, "Battle return retains mandatory upgrades")
	node.show_system()
	check(node.view_kind == "outcome", "Pending upgrades cannot be bypassed")
	node.queue_free()
	await process_frame
	for options in [[false, true], [false, false]]:
		var fallback = host(options[0], options[1])
		await process_frame
		poi(fallback, 0)
		fallback.show_system()
		if options[1]:
			fallback.star_map.travel_duration = 0.03
			fallback.star_map.travel(0)
			await create_timer(0.12).timeout
		else:
			fallback._grid_travel(0)
		check(fallback.view_kind == "poi" and fallback.state.navigation_origin == 0, "2D/grid navigation keeps authoritative arrival")
		fallback.queue_free()
		await process_frame
	# A deferred grid resume must not run after another same-run view is selected.
	node = host(false, false)
	await process_frame
	poi(node, 0)
	poi(node, 1)
	node.state.travel_destination = 0
	node.show_system()
	node.show_poi(1)
	await process_frame
	check(node.state.navigation_origin == -1 and node.selected_encounter == 1, "Obsolete deferred grid resume cannot open another destination")
	node.queue_free()
	await process_frame
	# Cancel an interception during its impact, not only the initial movement tween.
	node = host()
	await process_frame
	poi(node, 0)
	poi(node, 1)
	node.state.rules.chasedown_chance = 1.0
	node.state.rules.maximum_chasedown_chance = 1.0
	node.state.system_profile = "industrial"
	node.state.arrive_destination(0)
	node.show_system()
	node.star_map.travel_duration = 1.0
	node.star_map.travel(1)
	await create_timer(0.65).timeout
	var interrupted: Resource = node.state
	check(interrupted.chasedown_unresolved() and is_instance_valid(node.star_map.impact_layer), "Interception retains its committed state during impact")
	node._clear("outcome")
	var view_revision: int = node.screen.view_revision
	await create_timer(1.0).timeout
	check(node.view_kind == "outcome" and node.screen.view_revision == view_revision and not interrupted.encounters[1].completed, "Cancelled impact cannot deliver interruption/arrival to a replacement view")
	check(node.star_map.camera.h_offset == 0 and node.star_map.camera.v_offset == 0 and node.star_map.impact_layer == null, "Cancellation releases impact tween, shake and overlay")
	node.queue_free()
	await process_frame
	# Exit while awaiting white must not create a battle or apply a reward afterward.
	node = host()
	await process_frame
	var retained: Resource = node.state
	index = enemy_index(node)
	node._enter_battle(index)
	node.queue_free()
	await process_frame
	await create_timer(0.3).timeout
	check(retained.active_battle == -1 and retained.salvage == 0, "Scene exit invalidates pending cinematic callbacks")
	print("Expedition lifecycle: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
