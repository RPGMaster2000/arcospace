extends SceneTree
const Save = preload("res://scripts/persistence/expedition_save.gd")
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func settle() -> void:
	for frame in range(6): await process_frame
func activate(control: Control, touch: bool) -> void:
	for pressed in [true,false]:
		var event: InputEvent = InputEventScreenTouch.new() if touch else InputEventMouseButton.new()
		if event is InputEventMouseButton: event.button_index = MOUSE_BUTTON_LEFT
		else: event.index = 0
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://.godot/testlogs/status-layout")
	root.get_texture().get_image().save_webp("res://.godot/testlogs/status-layout/%s-%s.webp" % [RenderingServer.get_current_rendering_method(),label])
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var host = load("res://scenes/expedition.tscn").instantiate()
	host.persistence_enabled = false
	host.play_system_intro = false
	host.rules = host.rules.duplicate(true)
	host.rules.game_mode = "defense"
	host.rules.debug_seed = 42
	root.add_child(host)
	await settle()
	var hud = host.screen.overview_hud
	check(hud.details_button.text.is_empty() and hud.details_button.icon != null and hud.details_button.tooltip_text == "System Status","Compact native globe retains its identifying tooltip")
	check(hud.panels[1].get_theme_stylebox("panel") is StyleBoxEmpty,"Counter group has no panel background")
	for dimensions in [Vector2i(1920,1080),Vector2i(1280,720),Vector2i(960,540),Vector2i(1280,573),Vector2i(686,384)]:
		root.size = dimensions
		await settle()
		var button: Rect2 = hud.details_button.get_global_rect()
		var counter: Rect2 = hud.turret_count.get_global_rect()
		var utilities: Rect2 = hud.panels[4].get_global_rect()
		check(button.size.x >= 44 and button.size.y >= 44,"Globe retains comfortable touch target")
		check(is_equal_approx(button.end.x,counter.end.x) and is_equal_approx(button.end.x,utilities.end.x),"Status group shares the lower-right safe margin")
		check(counter.end.y < button.position.y and button.end.y + 8 <= utilities.position.y,"Counter above globe; utility buttons remain clear")
		check(root.get_visible_rect().encloses(hud.panels[1].get_global_rect()),"Status controls fit viewport")
		check(not hud.panels[1].get_global_rect().intersects(hud.panels[2].get_global_rect()),"Left and right HUD groups do not overlap")
		check(hud.pressure_bar.custom_minimum_size == Vector2(210,6),"Pressure geometry preserved")
		var hull: Control = host.resource_bar.entries.hull
		check(hull.get_global_rect().position.y - hud.pressure_bar.get_global_rect().end.y >= 18,"Noticeable empty space below Pressure")
		check(host.star_map.point_is_reserved(button.get_center()),"Map markers and gestures respect the moved status control")
		for ratio in [.25,.65,.9]:
			host.state.defense.pressure = ratio * host.state.defense.tuning.pressure_maximum
			host.screen.set_defense_status(host.state)
			check(is_equal_approx(hud.pressure_bar.value,ratio*100) and hud.pressure_fill.bg_color == (Color("77e596") if ratio < .5 else (Color("ffaf58") if ratio < .8 else Color("ff646e"))),"Pressure values and existing color thresholds unchanged")
		host.state.defense.pressure = 0
		host.screen.set_defense_status(host.state)
		await settle()
		await capture("overview-%d-%d" % [dimensions.x,dimensions.y])
		var before := Save.encode(host.state)
		await activate(hud.details_button,dimensions.x == 960)
		var overlay = host.screen.system_details_overlay
		check(overlay.shade.visible and overlay.body.text.contains("SYSTEM DETAILS"),"Mouse/touch globe opens the unchanged panel")
		if dimensions.x == 960: await capture("open-960-540")
		await activate(overlay.close,dimensions.x == 960)
		check(not overlay.shade.visible and Save.encode(host.state) == before,"Closing panel leaves strategic time, RNG and save state unchanged")
	var sites: Array = host.state.defense.construction_sites.keys()
	check(not sites.is_empty(),"Valid construction site available")
	if not sites.is_empty():
		host.state.salvage = host.state.defense.tuning.turret_salvage_cost
		check(host._deploy_turret(sites[0]) and hud.turret_count.text.begins_with("Turrets: 1"),"Moved counter updates after actual deployment")
	hud.set_mode(hud.Mode.FOCUS)
	check(not hud.panels[1].visible and not hud.pressure_gap.visible,"Strategic controls and spacing stay out of tactical focus")
	host.free()
	await process_frame
	print("Defense HUD layout: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
