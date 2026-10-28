extends SceneTree
const Rules = preload("res://encounters/expedition_rules.tres")
var failures: int = 0
var checks: int = 0
var host: Control
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	# This regression exercises the retained exploration mode.
	var regression_rules: Resource = preload("res://encounters/expedition_rules.tres")
	regression_rules.game_mode = "exploration"
	call_deferred("run")
func settle() -> void:
	for n in range(12): await process_frame
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot/testlogs/chasedown-" + label + ".png")
func make_host(grid: bool = false) -> void:
	host = load("res://scenes/expedition.tscn").instantiate()
	host.use_3d_star_map = false
	host.persistence_enabled = false
	host.rules = Rules.duplicate(true)
	host.rules.log_rolls = false
	host.rules.debug_seed = 1042
	host.rules.chasedown_chance = 1
	host.rules.maximum_chasedown_chance = 1
	host.star_map_travel_duration = 0.05
	host.use_star_map = not grid
	root.add_child(host)
	host.state.system_profile = "industrial"
	current_scene = host
	for index in range(2): host.state.encounters[index] = {"kind":"poi","poi":Rules.pois[index],"title":Rules.pois[index].title,"completed":false}
	host.show_system()
func run() -> void:
	for grid in [false,true]:
		for escape in [false,true]:
			make_host(grid)
			await settle()
			# First arrival is never intercepted, then real movement to a different PoI is.
			if grid: host._grid_travel(0)
			else: host.star_map.travel(0)
			await create_timer(0.12).timeout
			check(host.selected_encounter == 0 and host.state.chasedown_index == -1, "Initial arrival bypasses roll")
			host.show_system()
			await settle()
			if grid: host._grid_travel(1)
			else: host.star_map.travel(1)
			if not grid:
				var map: Control = host.star_map
				var origin: Vector2 = map.ship_position
				check(map.traveling and host.view_kind == "system", "Interception permits movement before prompt")
				map.travel(2)
				await create_timer(0.2).timeout
				check(host.view_kind == "system" and map.ship_position != origin, "Ship moves before interception delay")
				check(host.map_destination == 0 and host.state.navigation_origin == 0 and host.state.pending_destination == 1, "Delayed interception locks destination and prevents early arrival")
				await create_timer(0.4).timeout
				check(map.impact_active and host.view_kind == "system", "Impact starts after movement stops, before prompt")
				map._update_impact(0.06)
				check(map.impact_flash.color.a > 0.3, "First red flash peaks")
				map._update_impact(0.15)
				check(is_zero_approx(map.impact_flash.color.a), "Red fades between flashes")
				map._update_impact(0.24)
				check(map.impact_flash.color.a > 0.3, "Second red flash peaks")
				var stopped: Vector2 = map.ship_position
				await create_timer(0.25).timeout
				check(map.ship_position == stopped and host.map_destination == 0, "Impact keeps ship stopped and prevents arrival")
				await create_timer(0.8).timeout
				check(root.canvas_transform == Transform2D.IDENTITY, "Impact restores screen position")
			check(host.view_kind == "chasedown" and host.state.pending_destination == 1 and host.map_destination == 0, "Actual movement interrupted before consuming destination")
			var index: int = host.state.chasedown_index
			for size in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(800,450),Vector2i(686,384)]:
				root.size = size
				await settle()
				check(host.grid.get_child_count() == 4, "Four response choices")
				for button in host.grid.get_children():
					check(button.size.y >= 48 and button.size.x >= 120, "Touch-friendly responses")
					check(button.details.get_global_rect().end.y <= button.get_global_rect().end.y+1, "Modifier text contained")
				check(host.view_kind == "chasedown" and not host.state.encounters[1].completed, "Resize does not resolve interception or destination")
				if not grid and not escape: await capture("choices-%d" % size.x)
			host.show_system()
			check(host.view_kind == "chasedown" and host.state.chasedown_index == index, "Reopening system restores same pending encounter")
			if not grid and not escape:
				check(host.state.choose_chasedown_response(0), "Response can be retained before scene restoration")
				host.show_system()
				check(host.view_kind == "battle" and not host.state.choose_chasedown_response(0), "Chosen response restores existing battle without reapplying modifiers")
			else: host._chasedown_response(3)
			var battle = host.battle
			battle.battle_effects.enabled = false
			battle.get_node("ModifierDisplay").cinematic_enabled = false
			if battle.battle_effects.busy: await battle.battle_effects.finished
			await process_frame
			check(host.view_kind == "battle" and battle.expedition_encounter == index, "Existing battle scene reused")
			if escape:
				battle.ftl.charge = battle.ftl.charge_target
				battle._warp_out()
			else:
				battle.enemy_hull = 0
				battle._check_winner()
				battle.refresh_display()
			battle._continue_encounter()
			if not escape:
				check(host.view_kind == "outcome" and host.state.upgrades_remaining == 1, "Interception victory offers one upgrade")
				host._upgrade(host.state.upgrade_candidates()[0].identity_key())
				host.show_system()
			for attempt in range(120):
				if host.view_kind == "system": break
				await process_frame
			check(host.map_destination == 0 and host.view_kind == "system", "Victory/escape returns stationary without visiting former destination")
			check(host.state.travel_destination == -1 and host.state.pressure == 0 and not host.state.ftl_access and host.state.chasedowns_this_system == 1 and not host.state.encounters[1].completed, "Cancelled travel grants no second reward or destination completion")
			if not grid:
				host.show_system()
				check(is_instance_valid(host.star_map) and host.star_map.markers.size() == host.rules.encounters_per_system + int(not host.state.service.is_empty()), "No extra map marker for interception")
			host.free()
			await process_frame
	# Removing a map during its delay must cancel the old callback.
	make_host()
	host.state.navigation_origin = 0
	host.star_map.travel(1)
	host.start_expedition()
	await create_timer(0.65).timeout
	check(host.view_kind == "system" and host.state.chasedown_index == -1, "New expedition cancels stale interception prompt")
	host.free()
	await process_frame
	# Removing the map during the shake restores the screen and cancels the prompt.
	make_host()
	host.state.navigation_origin = 0
	host.star_map.travel(1)
	await create_timer(0.65).timeout
	check(host.star_map.impact_active, "Impact active before cancellation")
	host.start_expedition()
	check(root.canvas_transform == Transform2D.IDENTITY, "Cancelling impact restores screen immediately")
	await create_timer(1.1).timeout
	check(host.view_kind == "system", "Cancelled impact cannot open a stale prompt")
	host.free()
	await process_frame
	# A lost interception must show the normal expedition-ended screen, never reopen it.
	make_host()
	host.state.navigation_origin = 0
	check(host.state.begin_travel(1), "Pending interception prepared for loss restoration")
	host.state.choose_chasedown_response(3)
	host.state.hull = 0
	host.show_system()
	check(host.view_kind == "system" and host.ui.visible and not is_instance_valid(host.battle), "Lost interception exposes normal expedition-ended screen")
	host.free()
	await process_frame
	# Normal multi-upgrade UI filters chosen identities and allows finishing early.
	make_host()
	host.state.start_upgrade_event(3)
	host.show_outcome()
	var card = host.state.upgrade_candidates()[0]
	host._preview_card(card)
	host.card_management.confirm_button.pressed.emit()
	check(host.state.upgrades_remaining == 2 and host.state.upgraded_cards[card.identity_key()].upgrade_level == 1, "First UI confirmation applies one upgrade")
	for candidate in host.card_gallery.cards: check(candidate.identity_key() != card.identity_key(), "Already chosen identity removed from this event")
	check(not host.state.choose_upgrade(card.identity_key()), "Stale duplicate rejected by state")
	for size in [Vector2i(1280,720),Vector2i(960,540),Vector2i(686,384)]:
		root.size = size
		await settle()
		check(host.card_gallery.cards.size() == host.state.upgrade_candidates().size(), "Gallery tracks remaining distinct candidates")
		await capture("upgrades-%d" % size.x)
	while host.state.pending_choice == "upgrade":
		host._upgrade(host.state.upgrade_candidates()[0].identity_key())
	check(host.state.pending_choice.is_empty() and host.state.upgrades_remaining == 0, "Finish releases navigation")
	host.free()
	await process_frame
	print("Chasedown UI: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
