extends SceneTree
const Ships = preload("res://scripts/ships/ship_library.gd")
const Cards = preload("res://scripts/cards/card_library.gd")
const Text = preload("res://scripts/ui/card_effect_text.gd")
const Gallery = preload("res://scripts/ui/card_gallery.gd")
var failures: int = 0
var assertions: int = 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func settle() -> void:
	for n in range(10): await process_frame
func click(control: Control) -> void:
	var motion = InputEventMouseMotion.new()
	motion.position = control.get_global_rect().get_center()
	root.push_input(motion, true)
	var event = InputEventMouseButton.new()
	event.position = motion.position
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(event, true)
	await process_frame
	event.pressed = false
	event.button_mask = 0
	root.push_input(event, true)
func screenshot(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/overhaul-" + label + ".png")
func definition_snapshot() -> String:
	var values: Array = []
	for card in Cards.CARDS: values.append([card.card_name,card.cost,card.effects,card.upgrade_effects,card.tier,card.upgrade_level])
	return JSON.stringify(values)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs")
	var original: String = definition_snapshot()
	for base in Cards.CARDS:
		for level in [1,2]:
			var portrait = preload("res://scripts/ui/card_portrait.gd").new()
			portrait.card_data = base.with_upgrade(level)
			portrait.comparison_base = base if level == 1 else base.with_upgrade(1)
			root.add_child(portrait)
			await process_frame
			await process_frame
			check(portrait.rendering.get_node("ArtPlaceholder").get_rect()==Rect2(12,101,174,74), "Comparison portrait keeps fixed artwork: " + portrait.card_data.card_name)
			check(portrait.rendering.get_node("DescriptionLabel").get_rect().end.y <= portrait.badge.position.y, "Compact comparison portrait clears upgrade badge")
			check(portrait.rendering.get_node("CostLabel").text == str(base.cost), "Comparison preserves actual cost")
			portrait.free()
	root.size = Vector2i(1280,720)
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	root.add_child(host)
	current_scene = host
	host.state.pending_choice = "card"
	host.state.card_offers = host.state.random_card_offers()
	host.show_outcome()
	await settle()
	check(host.card_gallery.cards == host.state.card_offers, "Actual reward gallery")
	var first = host.card_gallery.grid.get_child(0)
	check(first.rendering.card_data == first.card_data and first.rendering.get_node("CostLabel").text == str(first.card_data.cost), "Real battle visuals and cost")
	for icon in first.rendering.get_node("ResourceIcon").get_children(): check(icon.visible == (icon.name.to_lower() == first.card_data.family), "Correct family icon")
	await click(first)
	await settle()
	check(host.card_management.selected_card == first.card_data and host.state.acquired_cards.is_empty(), "Preview does not acquire")
	host.card_management.select_card(host.card_gallery.visible_cards[1])
	check(host.state.pending_choice == "card" and host.state.acquired_cards.is_empty(), "Changing selection preserves reward")
	first.pressed.emit()
	host.card_management.confirm_button.pressed.emit()
	host.card_management.confirm_button.pressed.emit()
	check(host.state.acquired_cards.size() == 1 and host.state.pending_choice.is_empty(), "Confirm is single-use")
	host.state.start_upgrade_event(1)
	host.show_outcome()
	await settle()
	check(host.card_gallery.cards == host.state.upgrade_candidates(), "Only eligible identities")
	var card: Resource = Cards.CARDS[6]
	host._preview_card(card)
	await settle()
	check(host.card_management.selected_card == card and host.card_management.details.get_children().any(func(c): return c.get_script() == preload("res://scripts/ui/card_portrait.gd") and c.card_data.effects == card.with_upgrade(1).effects), "Inline next upgrade uses actual effects")
	check(Text.comparison(Cards.CARDS[3].with_upgrade(1), Cards.CARDS[3]).begins_with("+1 Synthesizer\n[color="), "Unchanged production neutral, added resources green")
	check(Text.comparison(Cards.CARDS[41].with_upgrade(1), Cards.CARDS[41]).contains("[color=91e6ad]Take 3 direct Hull dmg"), "Reduced self damage highlighted as improvement")
	await screenshot("comparison")
	host._preview_card(host.card_gallery.cards[0])
	check(host.state.upgraded_cards.is_empty(), "Selection does not upgrade")
	host._preview_card(card)
	host.card_management.confirm_button.pressed.emit()
	host.card_management.confirm_button.pressed.emit()
	check(host.state.upgraded_cards[card.identity_key()].upgrade_level == 1, "Upgrade confirmation single-use")
	host.state.upgraded_cards = host.state.upgraded_cards.merged({card.identity_key(): card.with_upgrade(2)}, true)
	host.state.start_upgrade_event(1)
	host.show_outcome()
	for eligible in host.card_gallery.cards: check(eligible.identity_key() != card.identity_key(), "Maximum upgrades excluded")
	host._upgrade(host.state.upgrade_candidates()[0].identity_key())
	host.show_system()
	var setup = load("res://scenes/battle_setup.tscn").instantiate()
	root.add_child(setup)
	setup.showcase._stop_tween()
	setup.showcase._finish_intro()
	setup.showcase.logo.modulate.a = 0.0
	setup.showcase.phase = setup.showcase.Phase.SHIP_SELECTION
	setup._selection_ready()
	await process_frame
	for dimensions in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(1920,1080),Vector2i(960,540),Vector2i(800,450)]:
		root.size = dimensions
		await settle()
		check(not setup.has_node("Ships"), "Superseded preview grid removed")
		for index in range(Ships.PLAYERS.size()):
			setup._select(index)
			await settle()
			var panel: Control = setup.get_node("Selection/Information")
			check(root.get_visible_rect().encloses(panel.get_global_rect()), "Ship information inside viewport " + str(dimensions))
			check(setup.get_node("Selection/Information/Margin/Scroll/Column/Identity/Stats").get_global_rect().end.y <= setup.deck_button.get_global_rect().position.y, "Statistics above actions")
		setup.deck_button.pressed.emit()
		await settle()
		for index in range(Ships.PLAYERS.size()):
			setup._select(index)
			await settle()
			check(setup.deck_viewer.gallery.cards == Ships.PLAYERS[index].starting_cards, "Deck follows selected ship")
		var viewer = setup.deck_viewer
		viewer.gallery.set_category("Attack")
		for attack in viewer.gallery.visible_cards: check(Gallery.matches(attack,"Attack"), "Effect-derived filter")
		viewer.gallery.set_category("All")
		viewer.gallery.sorting.select(1)
		viewer.gallery.sorting.item_selected.emit(1)
		for index in range(1,viewer.gallery.visible_cards.size()):
			check(viewer.gallery.visible_cards[index - 1].cost <= viewer.gallery.visible_cards[index].cost, "Cost sorting follows actual resource cost")
		viewer.gallery.sorting.select(0)
		viewer.gallery.sorting.item_selected.emit(0)
		viewer.gallery.grid.get_child(0).pressed.emit()
		await settle()
		check(viewer.inspector.read_only and not viewer.inspector.confirm_button.visible, "Read-only deck inspection")
		check(not viewer.gallery.scroll.is_processing_input(), "Modal blocks background touch dragging")
		viewer.inspector._confirm()
		check(definition_snapshot() == original, "Deck cannot mutate definitions")
		for portrait in viewer.inspector.portraits: check(root.get_visible_rect().encloses(portrait.get_global_rect()), "Enlarged preview fits landscape")
		viewer.inspector.dismiss()
		if dimensions == Vector2i(1280,720):
			var tap = InputEventScreenTouch.new()
			tap.index = 4
			tap.position = viewer.gallery.grid.get_child(0).get_global_rect().get_center()
			tap.pressed = true
			Input.parse_input_event(tap)
			# A short tap has no frame delay; waiting here now intentionally means hold-to-inspect.
			tap = tap.duplicate()
			tap.pressed = false
			Input.parse_input_event(tap)
			await settle()
			check(viewer.inspector.shade.visible, "Touch tap opens read-only card inspector")
			viewer.inspector.dismiss()
		# A touch drag must not activate a card on release.
		var scroll = viewer.gallery.scroll
		var press = InputEventScreenTouch.new()
		press.index = 0
		press.position = scroll.get_global_rect().get_center()
		press.pressed = true
		scroll._input(press)
		var drag = InputEventScreenDrag.new()
		drag.index = 0
		drag.position = press.position + Vector2(0,-80)
		scroll._input(drag)
		press.pressed = false
		scroll._input(press)
		viewer.gallery.grid.get_child(0).pressed.emit()
		check(not viewer.inspector.shade.visible, "Android drag release cannot select card")
		check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "Large deck scrolls")
		scroll.blocked_until = 0
		scroll.scroll_vertical = 0
		var wheel = InputEventMouseButton.new()
		wheel.position = scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
		wheel.pressed = true
		root.push_input(wheel, true)
		await settle()
		check(scroll.scroll_vertical > 0, "Mouse wheel moves card gallery")
		var touch = InputEventScreenTouch.new()
		touch.index = 1
		touch.position = scroll.get_global_rect().get_center()
		touch.pressed = true
		root.push_input(touch, true)
		await process_frame
		var native_drag = InputEventScreenDrag.new()
		native_drag.index = 1
		native_drag.position = touch.position + Vector2(0,-100)
		native_drag.relative = Vector2(0,-100)
		var before_drag: int = scroll.scroll_vertical
		root.push_input(native_drag, true)
		touch.pressed = false
		root.push_input(touch, true)
		await settle()
		check(scroll.scroll_vertical > before_drag, "Native touch drag moves gallery")
		scroll.blocked_until = 0
		scroll.scroll_vertical = 0
		await settle()
		await screenshot("deck-" + str(dimensions.x))
		viewer.dismiss()
		await screenshot("ships-" + str(dimensions.x))
	setup.free()
	for dimensions in [Vector2i(1280,720),Vector2i(1680,720),Vector2i(960,540),Vector2i(800,450)]:
		root.size = dimensions
		host.state.encounters[0] = {"kind":"poi","poi":host.rules.pois[0],"title":"Test","completed":false}
		host.show_poi(0)
		await settle()
		check(host.view.alignment == BoxContainer.ALIGNMENT_END, "PoI approach group bottom aligned")
		await screenshot("poi-" + str(dimensions.x))
		if host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1:
			check(absf(host.grid.get_global_rect().end.y - host.scroll.get_global_rect().end.y) < 4, "Options anchored to bottom")
		var expanded: Resource = host.rules.pois[0].duplicate(true)
		while expanded.approaches.size() < 8: expanded.approaches.append(expanded.approaches[0])
		host.state.encounters[0].poi = expanded
		host.show_poi(0)
		await settle()
		check(host.scroll.get_v_scroll_bar().max_value > host.scroll.get_v_scroll_bar().page, "Overflowing PoI still scrolls")
		host.state.encounters[0] = {"kind":"battle","enemy":0,"enemy_data":Ships.ENEMIES[0],"modifier":0,"title":"Test","completed":false}
		host.start_battle(0)
		var board = host.battle
		board.battle_effects.enabled = false
		board.enemy_timer.stop()
		await settle()
		for path in board.card_slots:
			var held: Control = board.get_node(path)
			check(root.get_visible_rect().encloses(held.get_global_rect()), "Hand inside screen " + str(dimensions))
			check(absf(held.get_global_rect().end.y - (root.get_visible_rect().end.y - 12)) < 2, "Combat card bottom anchored")
			check(held.get_node("DiscardButton").get_global_rect().size.y >= 43.9, "Discard touch target remains 44 pixels")
		check(is_equal_approx(board.get_node("FTLPanel/Progress").size.x,154), "FTL bar 33% narrower")
		board.ftl.charge = board.ftl.charge_target
		board._record_result()
		board.refresh_display()
		check(root.get_visible_rect().encloses(board.get_node("FTLPanel/WarpButton").get_global_rect()), "Jump action fits")
		await screenshot("combat-" + str(dimensions.x))
		host._remove_battle()
		host.state.active_battle = -1
	host.start_battle(0)
	var defeated = host.battle
	defeated.battle_effects.enabled = false
	defeated.winner = "enemy"
	defeated._record_result()
	defeated.refresh_display()
	check(not defeated.get_node("MatchResult/Panel/PlayAgain").visible, "No New Expedition on defeat")
	check(defeated.get_node("MatchResult/Panel/Configure").text == "Main Menu", "Single defeat destination")
	defeated.get_node("MatchResult/Panel/Configure").pressed.emit()
	await settle()
	check(current_scene.scene_file_path.ends_with("battle_setup.tscn"), "Defeat goes to ship selection")
	current_scene.showcase.skip_cinematics = true
	current_scene.showcase._stop_tween()
	current_scene.showcase._finish_intro()
	current_scene.showcase.logo.modulate.a = 0.0
	current_scene.showcase.phase = current_scene.showcase.Phase.SHIP_SELECTION
	current_scene._selection_ready()
	current_scene.white_fade_duration = 0.001
	current_scene.map_reveal_duration = 0.001
	current_scene._select(1)
	current_scene._start()
	await settle()
	check(current_scene.state.player_ship == 1 and current_scene.state.acquired_cards.is_empty() and current_scene.state.upgraded_cards.is_empty(), "Only confirmation starts fresh selected expedition")
	check(definition_snapshot() == original, "UI never changes card data or balance")
	current_scene.free()
	await process_frame
	print("UI overhaul: %d checks, %d failures" % [assertions,failures])
	quit(1 if failures else 0)
