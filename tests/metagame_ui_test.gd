extends SceneTree
# Read-only UI integration across shipping landscape sizes. No reward simulation.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	await create_timer(0.3).timeout
	for i in range(4): await process_frame

func run() -> void:
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.rules = host.rules.duplicate()
	host.rules.debug_seed = 1042
	host.rules.log_rolls = false
	root.add_child(host)
	var battle := -1
	var poi := -1
	for i in range(host.state.encounters.size()):
		if host.state.encounters[i].kind == "battle": battle = i
		elif host.state.encounters[i].get("objective_role", "").is_empty(): poi = i
	check(battle >= 0 and poi >= 0, "Generated system has both preview categories")
	var hud = host.screen.overview_hud
	var rng: int = host.state.rng.state
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1680,720), Vector2i(1560,720)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		host.state.pressure = 10
		host.show_system()
		await settle()
		check(hud.metagame.text.contains("PRESSURE 10 / 12") and hud.metagame.text.contains(host.state.profile_name()), "Profile and pressure show authoritative facts")
		check(hud.metagame.text.contains(host.state.ftl_status()), "FTL state persists in ship status")
		check(host.jump_button.get_node_or_null("Charge") == null, "Retired interstellar charge bar absent")
		check(hud.panels[0].size.y < 65, "Economy remains horizontal")
		check(root.get_visible_rect().encloses(hud.panels[2].get_global_rect()), "Pressure and ship status fit viewport")
		host.state.ftl_access = true
		host.show_system()
		await settle()
		check(host.jump_button.text == "FTL READY" and not host.jump_button.disabled, "FTL objective completion enables Jump")
		host.map_destination = poi
		host.show_poi(poi)
		await settle()
		check(hud.focused and hud.metagame.is_visible_in_tree(), "Pressure remains visible in PoI focus")
		check(not hud.panels[3].is_visible_in_tree() and not hud.panels[4].is_visible_in_tree(), "Focus hides exploration controls")
		check(not hud.panels[2].get_global_rect().intersects(host.screen.sidebar.get_global_rect()), "Persistent ship panel clears PoI choices")
		host.map_destination = battle
		host.show_battle_preview(battle)
		await settle()
		var notice = host.view.find_child("PressureModifier", true, false)
		check(notice != null and notice.visible and notice.text.contains("20%"), "Tactical briefing discloses actual high-pressure scaling")
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Pressure tactical panel fits without scrolling")
		check(not hud.panels[2].get_global_rect().intersects(host.screen.sidebar.get_global_rect()), "Persistent ship panel clears combat briefing")
	# The four response choices share the same fixed-height tactical panel.
	for dimensions in [Vector2i(960,540), Vector2i(1280,720), Vector2i(1680,720)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		host.show_system()
		host.state.pending_bonuses = {"materials":3,"energy":5,"crew":2,"shields":4,"emp_pulse_charge":3}
		host.state.pending_penalties = {"energy":-3,"shields":-4,"emp_pulse_offline":2}
		var interception: Dictionary = host.state.encounters[battle].duplicate()
		interception.chasedown = true
		interception.response = -1
		interception.completed = false
		host.state.chasedown_index = host.state.encounters.size()
		host.state.encounters.append(interception)
		host._show_chasedown()
		await settle()
		check(host.scroll.get_v_scroll_bar().max_value <= host.scroll.get_v_scroll_bar().page + 1, "Pursuit pressure and full entry effects fit without scrolling")
		check(host.grid.get_child_count() == 4, "All four Chasedown responses stay available")
		check(not host.star_map.focus_orbit_enabled, "Pursuit keeps fixed cinematic camera")
		host.state.encounters.pop_back()
		host.state.chasedown_index = -1
		host.state.pending_destination = -1
	check(host.state.rng.state == rng, "UI changes consume no gameplay RNG")
	host.free()
	print("Metagame UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
