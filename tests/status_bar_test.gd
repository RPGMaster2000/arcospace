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
		for label in button.get_node("Values").get_children():
			if not label.text.is_empty(): check(button.get_global_rect().encloses(label.get_global_rect()), "Colored value fits button: " + label.text)
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
	host.use_star_map = false # Preserve grid input coverage.
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
	check(host.resource_bar.entries.energy.text == "⚡ +2/t · 10 Energy +5", "Base reserve plus green bonus")
	check(host.resource_bar.entries.crew.text.ends_with("10 Crew -3"), "Base reserve plus red penalty")
	check(not host.resource_bar.entries.has("travel") and not host.resource_bar.entries.has("hazard"), "Removed duplicate FTL and effects entries")
	check(host.resource_bar.entries.keys().slice(0,3) == ["hull", "shields", "salvage"], "Hull, Shields, Salvage order")
	check(host.resource_bar.entries.jump.text.ends_with("Nominal"), "Unmodified EMP Pulse nominal")
	check(Presentation.meaning("synthesizer").begins_with("Synthesizer") and Presentation.meaning("quarters").begins_with("Quarters"), "Production names consistent")
	check(host.resource_bar.entries.energy.get_node("Values/Adjustment").get_theme_color("font_color") == host.resource_bar.POSITIVE, "Positive color")
	check(host.resource_bar.entries.crew.get_node("Values/Adjustment").get_theme_color("font_color") == host.resource_bar.NEGATIVE, "Negative color")
	host.state.add_modifiers({"energy":-100, "emp_pulse_charge":2, "emp_pulse_offline":3})
	host.show_system()
	check(host.resource_bar.entries.energy.text == "⚡ +2/t · 10 Energy", "Effective capped net zero omits adjustment")
	check(host.resource_bar.entries.jump.text.ends_with("Disabled -3 · Boost +2"), "Offline and boost coexist without hiding either")
	host.state.pending_penalties.erase("energy")
	host.show_system()
	var saved_bonuses: Dictionary = host.state.pending_bonuses.duplicate()
	var saved_penalties: Dictionary = host.state.pending_penalties.duplicate()
	host.state.pending_bonuses.energy = 2
	host.state.pending_penalties.energy = -5
	host.state.pending_bonuses.erase("emp_pulse_offline")
	host.state.production_upgrades.synthesizer = 1
	host.show_system()
	check(host.resource_bar.entries.energy.text == "⚡ +2/t · 10 Energy -3", "Mixed effects display net negative")
	check(host.resource_bar.entries.energy.get_node("Values/Adjustment").get_theme_color("font_color") == host.resource_bar.NEGATIVE, "Mixed net negative is red")
	check(host.resource_bar.entries.jump.text.ends_with("Boost +2"), "Boost-only status")
	check(host.resource_bar.entries.materials.text.contains("+3/t") and not host.resource_bar.entries.has("synthesizer"), "Production combined with resource")
	host.state.pending_bonuses = saved_bonuses
	host.state.pending_penalties = saved_penalties
	host.state.production_upgrades.clear()
	host.show_system()
	var before: int = host.state.ftl_charge
	await settle()
	Input.emulate_touch_from_mouse = true
	click_at(host.legend.get_global_rect().get_center())
	await settle()
	check(host.resource_bar.overlay.shade.visible, "Legend opens")
	check(host.resource_bar.overlay.body.text.contains("EMP Pulse"), "Legend has icon explanations")
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
		check(board.get_node("PlayerResource2").visible and board.get_node("PlayerHullLabel").visible, "Original battle resource and Hull UI restored")
		check(board.get_node("SalvageLabel").visible and board.get_node("FTLPanel/Charge").visible, "Original Salvage and EMP Pulse UI restored")
		check(board.get_node("PlayerResource2/energy").text == "37", "Original resource values update")
		for child in board.get_children(): check(not child is HFlowContainer, "No exploration bar in combat")
		if kind == 2:
			for viewport_size in [Vector2i(1280,720), Vector2i(1680,720), Vector2i(686,384)]:
				root.size = viewport_size
				await shot("battle-%d" % viewport_size.x)
		host._battle_finished()
		check(host.state.encounters[enemy_index].modifier == kind, "Returning from battle preserves condition")
		await process_frame
	host.free()
	await process_frame
	print("Status and modifier checks: %d assertions, %d failures" % [assertions, failures])
	quit(1 if failures else 0)
