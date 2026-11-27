extends SceneTree

const BoardScene = preload("res://scenes/board_3d.tscn")
const Preferences = preload("res://scripts/ui/menu_preferences.gd")
const Checkpoint = preload("res://scripts/combat/progression_checkpoint.gd")
const Layout = preload("res://scripts/ui/battle_layout.gd")
const Surge = preload("res://cards/14_energy_surge.tres")
const TierTwo = preload("res://cards/89_industrial_conversion.tres")
const TierThree = preload("res://cards/108_bastion_foundry.tres")
var checks := 0
var failures := 0
var capture_dir := ""


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, detail: String) -> void:
	checks += 1
	if condition: return
	failures += 1
	push_error(detail)


func until(condition: Callable, detail: String, timeout_ms: int = 30000) -> void:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(condition.call(), detail)


func capture(name: String) -> void:
	if capture_dir.is_empty(): return
	if OS.has_environment("ARCOSPACE_DECK_CAPTURES") and name not in ["01-deck", "02-dealing", "06-replacement"]: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_webp(capture_dir.path_join(name + ".webp"), false, 0.86)


func fresh(resume := {}, fast_camera := false, card_motion_enabled := true) -> Node:
	var board = BoardScene.instantiate()
	board.setup_settings = {"player_ship": 0, "enemy_ship": 0, "player_energy": 0,
		"enemy_data": preload("res://ships/enemy/siege_monitor.tres")}
	board.get_node("BattleEffects").enabled = false
	board.get_node("CardMotion").settings = board.get_node("CardMotion").settings.duplicate()
	board.get_node("CardMotion").settings.enabled = card_motion_enabled
	board.battle_setup = preload("res://scripts/combat/battle_setup.gd").new()
	board.battle_setup.battle_seed = 1147
	board.progression_actions.rng.seed = 7195
	board.normal_battlefield = preload("res://scenes/battlefield_3d.tscn")
	board.get_node("CardHand").starting_hand.assign([null, Surge])
	board.resume_combat = resume
	if fast_camera:
		board.cinematic_settings = board.cinematic_settings.duplicate()
		board.cinematic_settings.introduction_seconds = Vector3(0.1, 0.1, 0.4)
	root.add_child(board)
	return board


func visible_packets(motion: Control) -> int:
	return motion.flights.values().filter(func(entry): return entry.packet.visible).size()


func click_skip(touch: bool) -> void:
	for down in [true, false]:
		var event: InputEvent
		if touch:
			event = InputEventScreenTouch.new()
			event.index = 0
		else:
			event = InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = Vector2(150, 540)
		root.push_input(event, true)


func run() -> void:
	OS.set_environment("ARCOSPACE_BATTLE_HUD_BOOT", "1")
	OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "0")
	var saved_profile := Preferences.ui_motion()
	Preferences.set_ui_motion(1)
	capture_dir = OS.get_environment("ARCOSPACE_UI_CAPTURE")
	if not capture_dir.is_empty(): DirAccess.make_dir_recursive_absolute(capture_dir)
	var capture_width := OS.get_environment("ARCOSPACE_UI_CAPTURE_WIDTH").to_int()
	if capture_width > 0:
		root.size = Vector2i(capture_width, 1080 if capture_width == 2560 else 384)
	else:
		root.size = Vector2i(1280, 720)
	var board = fresh()
	var motion: Control = board.interface_motion
	var before: Dictionary = Checkpoint.capture(board)
	var hand: Array = board.hand.cards.duplicate()
	check(motion.booting and motion.flights.size() == 6 and not motion.deck.visible, "The committed six-card hand starts behind the boot reveal")
	check(motion.boot_duration == 1.65 and board.enemy_timer.is_stopped(), "Standard boot duration and AI timer")
	check(not await board._act("player", 0, true), "Cards are locked until the opening presentation settles")
	await capture("00-boot")
	# Vulkan software rendering may compile the first real battlefield frame
	# before the opening-stage tweens receive their next process step.
	await until(func(): return motion.deck.visible and motion.deck.assembly > 0.25,
		"Deck materializes before boot finishes", 90000)
	check(Checkpoint.capture(board) == before, "Deck materialization leaves both hands, both ships, rounds, and RNG untouched")
	check(is_equal_approx(motion.deck.get_rect().get_center().x, motion.deck_origin(true).x), "Opening deck uses the centered origin")
	check(motion.deck.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The temporary deck ignores input")
	await capture("01-deck")
	await until(func(): return visible_packets(motion) >= 2, "Staggered opening draws overlap")
	check(visible_packets(motion) < 6, "Opening cards have staggered departures")
	for info in motion.flights.values():
		if info.packet.visible:
			check(info.packet.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Moving cards ignore input")
	await capture("02-dealing")
	if motion.booting: await motion.boot_finished
	check(hand == board.hand.cards and before.hands.player.rng == str(board.hand.rng.state),
		"The finished deal preserves card order, identities, and the RNG stream")
	check(motion.flights.is_empty() and not motion.deck.visible and motion.deck.assembly == 0, "Boot removes all projected cards and deck")
	for card in board.hud.cards: check(card.visible, "Every committed card is visible and at its authored slot")
	await capture("03-production")
	check(board.get_node("PlayerResource2").has_meta(&"battle_signal"), "Committed turn income emits a family production pulse")
	var after_opening: Dictionary = Checkpoint.capture(board)
	var comparison = fresh()
	click_skip(false)
	check(not comparison.interface_motion.booting and not comparison.interface_motion.deck.visible, "Mouse skip immediately restores the HUD")
	check(Checkpoint.capture(comparison) == after_opening, "Skip has the same authoritative state as waiting for the deal")
	comparison.queue_free()
	await process_frame

	# A settled checkpoint restores its cards and RNG directly.
	var resumed = fresh(after_opening)
	check(not resumed.interface_motion.boot_started and not resumed.interface_motion.deck.visible,
		"Resuming a settled battle does not replay boot")
	var resumed_state := Checkpoint.capture(resumed)
	for key in after_opening.keys():
		check(resumed_state[key] == after_opening[key], "Resume preserves " + key)
	resumed.queue_free()
	await process_frame

	var reserve: Control = board.get_node("PlayerResource2")
	await create_timer(0.44).timeout
	var surge_slot: int = board.hand.cards.find(Surge)
	check(surge_slot >= 0, "Fixture includes a real Play Again card")
	var unchanged: Array = board.hand.cards.duplicate()
	var round_before: int = board.turn_number
	var energy_before: int = board.player_energy
	check(await board._act("player", surge_slot, false), "Play Again resolves through the gameplay entry point")
	check(board.current_actor == "player" and board.turn_number == round_before
		and board.player_energy == energy_before + 3, "Play Again preserves round and grants exactly the effect")
	check(board.hud.header.turn.text == "PLAY AGAIN", "Same-turn confirmation uses the existing header")
	check(not reserve.has_meta(&"battle_signal") or not is_instance_valid(reserve.get_meta(&"battle_signal").get_ref()),
		"A card resource gain does not issue a production pulse")
	check(board.hand.cards.slice(surge_slot + 1) == unchanged.slice(surge_slot + 1)
		and board.interface_motion.flights.has(surge_slot), "Only the already-replaced slot launches a draw")
	await capture("05-play-again")
	# A second action can begin while the first replacement is on its way.
	var another := 2 if surge_slot != 2 else 3
	check(await board._act("player", another, true), "Another action may commit without waiting for decorative draws")
	board.enemy_timer.stop()
	check(board.current_actor == "enemy" and motion.flights.has(another), "Discard replacement uses the same projected deck")
	check(board.get_node("EnemyResource2").has_meta(&"battle_signal"), "Enemy turn income emits the same production feedback")
	await until(func(): return visible_packets(motion) > 0 or motion.flights.is_empty(), "Ordinary replacement leaves the deck")
	check(motion.deck.get_rect().get_center().x < motion.deck_origin(true).x, "Replacement rematerializes at its left origin")
	await capture("06-replacement")
	await until(func(): return not motion.deck.visible, "Projector retracts after the replacement")
	check(motion.flights.is_empty() and board.hud.cards[another].visible, "Ordinary draw leaves no active animation nodes")

	# Display fixture commits higher-tier cards before calling the draw presenter.
	# Rarity eligibility is covered by card draws elsewhere; the presentation consumes no RNG.
	for entry in [[0, TierTwo], [5, TierThree]]:
		board.hand.cards[entry[0]] = entry[1]
		board._present_replacement(entry[0])
	board.refresh_display()
	check(motion.flights.size() == 2 and motion.get_children().count(motion.deck) == 1, "Simultaneous rarity reveals share one deck")
	for slot in [0, 5]:
		var packet: Control = motion.flights[slot].packet
		var face: Control = packet.get_child(1)
		check(face.card_data == board.hand.cards[slot], "Higher-tier packet carries the committed card resource")
	if not capture_dir.is_empty():
		await until(func():
			return motion.flights.is_empty() or (motion.flights.has(0) and motion.flights.has(5)
				and motion.flights[0].packet.get_child(1).visible), "Higher-tier faces turn up")
		await capture("07-rares")
	var deck_rng: int = board.hand.rng.state
	Preferences.set_ui_motion(0)
	check(not motion.deck.visible and motion.flights.is_empty() and deck_rng == board.hand.rng.state, "Reduced motion interrupts and settles draws without rerolling")

	Preferences.set_ui_motion(1)
	var test_card: Control = board.hud.cards[5]
	var family: String = test_card.card_data.family
	board.set("player_" + family, 0)
	board.refresh_display()
	await create_timer(0.18).timeout
	board.set("player_" + family, 200)
	board.refresh_display()
	check(test_card.affordable and test_card.has_meta(&"holo_affordability"), "A real affordability change animates the existing slot")
	var affordability: Tween = test_card.get_meta(&"holo_affordability")
	board.refresh_display()
	check(test_card.get_meta(&"holo_affordability") == affordability, "Idle refresh does not restart affordability feedback")
	await affordability.finished
	check(test_card._affordability_ink == 1.0, "Affordability settles to the final border treatment")

	board.enemy_hull -= 8
	board.enemy_shields = 2
	board.refresh_display()
	check(board.get_node("EnemyHullBar")._damage_fade > 0.0 and board.hud.shield_stack("enemy")._surge > 0.0,
		"Hull damage trails and absorbed Shield points animate from committed changes")
	board.hud.emp_interference()
	check(board.enemy_shields_label.has_meta(&"battle_signal") and not board.player_shields_label.has_meta(&"battle_signal"),
		"EMP interference is local to the affected shield systems")
	await capture("08-impact-emp")

	# Check real geometry across landscape viewports and asymmetric safe areas.
	for viewport in [Vector2i(686, 384), Vector2i(2560, 1080), Vector2i(1280, 720)]:
		if capture_width > 0: break
		root.size = viewport
		for frame in 3: await process_frame
		var bounds := Layout.safe_bounds(board.size, Vector4(24, 14, 42, 38))
		board.hud.fit_combat_controls(bounds)
		Layout.fit(board, board.settings_button, board.allocation_button, bounds)
		board.hud.fit_side_panels(board)
		motion.fit_deck(bounds)
		var opening: Vector2 = motion.deck_origin(true)
		var replacement: Vector2 = motion.deck_origin(false)
		check(is_equal_approx(opening.x, bounds.get_center().x) and replacement.x < opening.x,
			"Opening origin is centered and replacement origin is on the player side")
		board._present_replacement(0)
		var projected: Rect2 = (motion.deck.get_transform() * Rect2(Vector2.ZERO, motion.deck.size)).grow(8)
		check(bounds.encloses(projected), "Deck stays inside simulated asymmetric safe bounds")
		var obstacles := ["PlayerHullLabel", "PlayerShieldsLabel", "EnemyHullLabel", "EnemyShieldsLabel",
			"PlayerResource3", "EnemyResource1", "PowerAllocation", "FTLPanel", "PlayerTacticalPanel/ResourceHandle"]
		for path in obstacles:
			check(not projected.intersects(board.get_node(path).get_rect()), "Deck is clear of %s at %s" % [path, viewport])
		for slot in board.hud.cards.size():
			board._present_replacement(slot)
			var packet: Control = motion.flights[slot].packet
			var face: Control = packet.get_child(1)
			for opening_draw in [true, false]:
				var blocked := false
				for step in range(21):
					motion._pose(step / 20.0, slot, packet, face, packet.get_child(0), opening_draw)
					var bounds_card: Rect2 = packet.get_transform() * Rect2(face.position, face.size)
					for path in obstacles:
						blocked = blocked or bounds_card.intersects(board.get_node(path).get_rect())
					if step == 0:
						check(bounds_card.get_center().is_equal_approx(motion.deck_origin(opening_draw)),
							"The animated card starts on its projector")
				check(not blocked, "Draw path clears telemetry at %s in slot %d (opening %s)" % [viewport, slot, opening_draw])
			motion.complete_slot(slot)
	board.queue_free()
	await process_frame

	var touch = fresh()
	click_skip(true)
	check(not touch.interface_motion.booting and touch.hud.cards[0].visible, "Touch skip restores the hand without activating a card")
	touch.queue_free()
	await process_frame
	Preferences.set_ui_motion(0)
	var minimal = fresh()
	check(minimal.interface_motion.boot_duration == 0.20 and minimal.interface_motion.flights.is_empty(),
		"Minimal has a short reveal and no moving opening cards")
	await minimal.interface_motion.boot_finished
	check(not minimal.interface_motion.deck.visible and minimal.hud.cards[0].modulate.a == 1.0, "Minimal settles to the same layout")
	minimal.queue_free()
	await process_frame
	if DisplayServer.get_name() == "headless":
		Preferences.set_ui_motion(1)
		var motion_disabled = fresh({}, false, false)
		check(motion_disabled.interface_motion.boot_duration == 0.20
			and motion_disabled.interface_motion.flights.is_empty(), "Authored Card Motion opt-out uses the short HUD reveal")
		await motion_disabled.interface_motion.boot_finished
		var slot: int = motion_disabled.hand.cards.find(Surge)
		check(await motion_disabled._act("player", slot, false), "Card Motion opt-out preserves Play Again")
		check(motion_disabled.interface_motion.flights.is_empty() and motion_disabled.hud.cards[slot].visible,
			"Card Motion opt-out restores replacement input immediately")
		motion_disabled.queue_free()
		await process_frame

		OS.set_environment("ARCOSPACE_BATTLE_CINEMATICS", "1")
		var saved_skip := Preferences.skip_cinematics()
		Preferences.set_skip_cinematics(false)
		Preferences.set_ui_motion(1)
		var cinematic = fresh({}, true)
		check(cinematic.cinematic_director.active and not cinematic.interface_motion.boot_started,
			"Flight presentation retains its establishing shot before the HUD boot")
		await until(func(): return cinematic.interface_motion.booting, "Camera reaches the HUD pullback")
		check(cinematic.interface_motion.visible and cinematic.cinematic_director.active,
			"The HUD starts animating during the original camera pullback")
		cinematic.cinematic_director.skip()
		await until(func(): return not cinematic._presentation_locked(), "Cinematic skip releases action input")
		check(not cinematic.interface_motion.deck.visible and cinematic.ftl.charge == 1,
			"One cinematic skip also settles the hand and starts first-turn income once")
		cinematic.queue_free()
		await process_frame
		Preferences.set_skip_cinematics(saved_skip)
	Preferences.set_ui_motion(saved_profile)
	print("Battle interface motion: %d checks, %d failures" % [checks, failures])
	quit(int(failures > 0))
