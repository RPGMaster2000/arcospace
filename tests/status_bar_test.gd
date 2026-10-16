extends SceneTree
const Modifiers = preload("res://scripts/combat_modifier.gd")
const State = preload("res://scripts/expedition_state.gd")
const Rules = preload("res://encounters/expedition_rules.tres")
const Presentation = preload("res://scripts/ui/encounter_presentation.gd")
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
	for n in range(12): await process_frame
func shot(name: String) -> void:
	await settle()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/testlogs/status-" + name + ".png")
func click_at(position: Vector2) -> void:
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func geometry(bar: Control) -> void:
	for button in bar.entries.values():
		check(button.size.y >= 48, "Touch-sized resource entry")
		check(bar.get_global_rect().encloses(button.get_global_rect()), "Resource entry fits flow bar")
		check(root.get_visible_rect().encloses(button.get_global_rect()), "Resource entry fits viewport")
func run() -> void:
	var old_rng = RandomNumberGenerator.new()
	var new_rng = RandomNumberGenerator.new()
	old_rng.seed = 123456
	new_rng.seed = 123456
	for n in range(10000):
		check(old_rng.randi_range(0, 5) == Modifiers.roll_encounter(new_rng), "Exact original distribution and RNG sequence")
	for key in Presentation.ICONS:
		for character in str(Presentation.ICONS[key][0]):
			if character.unicode_at(0) != 0xfe0f: check(Presentation.EMOJI_FONT.has_char(character.unicode_at(0)), "Bundled glyph " + key)
		check(Presentation.icon(key, ThemeDB.fallback_font, true).begins_with("["), "Readable forced fallback")
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.rules = Rules.duplicate(true)
	host.rules.log_rolls = false
	host.rules.debug_seed = 789
	root.add_child(host)
	current_scene = host
	var enemy_index: int = -1
	var poi_index: int = -1
	for index in range(host.state.encounters.size()):
		if host.state.encounters[index].kind == "battle": enemy_index = index
		else: poi_index = index
	var assigned: int = host.state.encounters[enemy_index].modifier
	for n in range(5):
		host.visit(enemy_index)
		check(host.view_kind == "preview" and not is_instance_valid(host.battle), "Enemy selection previews before combat")
		check(host.view.get_child(1).text == Modifiers.description(assigned), "Preview matches actual definition")
		host.show_system()
		host.show_poi(poi_index)
		host.show_system()
		check(host.state.encounters[enemy_index].modifier == assigned, "Revisiting never rerolls")
	host.state.resolve_approach(poi_index, 0, 0)
	host.show_system()
	check(host.state.encounters[enemy_index].modifier == assigned, "PoI completion preserves modifier")
	host.state.add_modifiers({"energy":5, "crew":-3})
	host.show_system()
	check(host.resource_bar.entries.energy.text.contains("Next %d" % host.state.starting_value(host.state.ship(), "energy")), "Exploration values marked Next")
	check(host.resource_bar.entries.hazard.tooltip_text.contains("+5 Energy"), "Pending modifiers available")
	var before: int = host.state.ftl_charge
	await settle()
	Input.emulate_touch_from_mouse = true
	click_at(host.legend.get_global_rect().get_center())
	await settle()
	check(host.resource_bar.overlay.shade.visible, "Legend opens")
	check(host.resource_bar.overlay.body.text.contains("Emergency Jump"), "Legend has icon explanations")
	await shot("legend")
	click_at(host.grid.get_child(enemy_index).get_global_rect().get_center())
	check(host.view_kind == "system", "Modal blocks underlying encounter activation")
	click_at(host.resource_bar.overlay.close.get_global_rect().get_center())
	await settle()
	check(not host.resource_bar.overlay.shade.visible, "Touch-emulated Close dismisses legend")
	Input.emulate_touch_from_mouse = false
	check(host.state.ftl_charge == before and host.state.active_battle == -1, "Legend has no gameplay effects")
	for viewport_size in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(2400,1080), Vector2i(686,384)]:
		root.size = viewport_size
		host.show_system()
		await shot("system-%d" % viewport_size.x)
		geometry(host.resource_bar)
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "System fits without scroll")
		host.show_poi(poi_index)
		await shot("poi-%d" % viewport_size.x)
		geometry(host.resource_bar)
		if viewport_size.x == 1680: check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Ordinary ultrawide PoI fits")
	root.size = Vector2i(1680,720)
	for poi in Rules.pois:
		if poi.hazardous: continue
		host.state.encounters[poi_index] = {"kind":"poi", "poi":poi, "title":poi.title, "completed":false}
		host.show_poi(poi_index)
		await settle()
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Ordinary PoI fits ultrawide: " + poi.title)
	# Actual board applies all six stored kinds and returns without changing assignment.
	for kind in range(6):
		host.state.encounters[enemy_index].modifier = kind
		host.start_battle(enemy_index)
		var board = host.battle
		board.battle_effects.enabled = false
		if board.battle_effects.busy: await board.battle_effects.finished
		check(board.modifier.kind == kind, "Stored modifier applied to board")
		check(board.hand.drop_multiplier == (Modifiers.TEMPORAL_DROP_MULTIPLIER if kind == 5 else 1.0), "Stored Rift applies existing draw effect")
		board.player_energy = 37
		board.salvage = 12
		board.refresh_display()
		check(board.resource_bar.entries.energy.text.contains("37"), "Live Energy updates")
		check(not board.resource_bar.entries.energy.text.contains("Next"), "Live values distinct from preview")
		check(board.resource_bar.entries.salvage.text.contains("12"), "Live Salvage updates")
		if kind == 2:
			for viewport_size in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(686,384)]:
				root.size = viewport_size
				await shot("battle-%d" % viewport_size.x)
				geometry(board.resource_bar)
			board.resource_bar.entries.hazard.pressed.emit()
			await shot("description")
			check(board.turn_number == 1, "Inspecting resources consumes no turn")
			board.resource_bar.overlay.dismiss()
		if kind == 5:
			board.enemy_hull = 0
			board._check_winner()
			board.refresh_display()
			await shot("victory")
			var charge: int = host.state.ftl_charge
			board.get_node("MatchResult/Panel/Legend").pressed.emit()
			check(board.resource_bar.overlay.shade.visible and host.state.ftl_charge == charge, "Victory legend does not repeat rewards")
			board.resource_bar.overlay.dismiss()
		host._battle_finished()
		check(host.state.encounters[enemy_index].modifier == kind, "Returning from battle preserves condition")
		await process_frame
	host.free()
	await process_frame
	print("Status and modifier checks: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
